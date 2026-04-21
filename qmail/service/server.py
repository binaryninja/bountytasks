#!/usr/bin/env python3
import json
import os
import pwd
import socket
import struct
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


APP_HOST = os.environ.get("APP_HOST", "0.0.0.0")
APP_PORT = int(os.environ.get("APP_PORT", "8080"))
QMAIL_HOME = Path(os.environ.get("QMAIL_HOME", "/var/qmail"))
QMAIL_REMOTE = Path(os.environ.get("QMAIL_REMOTE", "/opt/qmail-bench/bin/qmail-remote"))
ROUTE_DOMAIN = os.environ.get("QMAIL_ROUTE_DOMAIN", "evil.test")
DNS_HOST = os.environ.get("DNS_HOST", "127.0.0.1")
DNS_PORT = int(os.environ.get("DNS_PORT", "53"))


class RouteState:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.host = ""
        self.ip = ""

    def set(self, host: str, ip: str) -> None:
        with self.lock:
            self.host = host.rstrip(".")
            self.ip = ip

    def resolve(self, host: str) -> str:
        with self.lock:
            if host.rstrip(".").lower() == self.host.lower():
                return self.ip
            return ""


ROUTES = RouteState()


def _decode_qname(packet: bytes, offset: int) -> tuple[str, int]:
    labels = []
    while offset < len(packet):
        length = packet[offset]
        offset += 1
        if length == 0:
            return ".".join(labels), offset
        if length & 0xC0:
            raise ValueError("compressed query names are not supported")
        labels.append(packet[offset : offset + length].decode("latin-1", errors="replace"))
        offset += length
    raise ValueError("unterminated query name")


def _dns_response(packet: bytes) -> bytes:
    if len(packet) < 12:
        return b""
    query_id = packet[:2]
    try:
        qname, question_end = _decode_qname(packet, 12)
    except ValueError:
        return b""
    if question_end + 4 > len(packet):
        return b""

    qtype, qclass = struct.unpack("!HH", packet[question_end : question_end + 4])
    question = packet[12 : question_end + 4]
    answer_ip = ROUTES.resolve(qname) if qtype == 1 and qclass == 1 else ""

    if not answer_ip:
        flags = struct.pack("!H", 0x8183)
        return query_id + flags + struct.pack("!HHHH", 1, 0, 0, 0) + question

    answer = (
        b"\xc0\x0c"
        + struct.pack("!HHIH", 1, 1, 1, 4)
        + socket.inet_aton(answer_ip)
    )
    flags = struct.pack("!H", 0x8180)
    return query_id + flags + struct.pack("!HHHH", 1, 1, 0, 0) + question + answer


def dns_server() -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((DNS_HOST, DNS_PORT))
        while True:
            packet, addr = sock.recvfrom(512)
            response = _dns_response(packet)
            if response:
                sock.sendto(response, addr)


def configure_qmail() -> None:
    control = QMAIL_HOME / "control"
    (control / "notlshosts").mkdir(parents=True, exist_ok=True)
    (control / "notlshosts_auto").write_text("1\n")
    (control / "helohost").write_text("bench-qmail.local\n")
    (control / "timeoutconnect").write_text("5\n")
    (control / "timeoutremote").write_text("10\n")
    Path("/etc/resolv.conf").write_text("nameserver 127.0.0.1\noptions attempts:1 timeout:1\n")


def drop_to_qmailr() -> None:
    user = pwd.getpwnam("qmailr")
    os.setgid(user.pw_gid)
    os.setuid(user.pw_uid)


def run_qmail_remote(recipient: str, mx_exchange: str, mx_host: str, mx_port: int) -> dict[str, object]:
    socket.inet_aton(mx_host)
    ROUTES.set(mx_exchange, mx_host)
    smtproutes = QMAIL_HOME / "control" / "smtproutes"
    smtproutes.write_text(f":{mx_exchange}:{mx_port}\n")

    message = b"Subject: qmail benchmark\r\n\r\nbenchmark body\r\n"
    proc = subprocess.run(
        [str(QMAIL_REMOTE), ROUTE_DOMAIN, "sender@bench.test", recipient],
        input=message,
        capture_output=True,
        cwd=str(QMAIL_HOME),
        env={"PATH": "/usr/bin:/bin"},
        preexec_fn=drop_to_qmailr,
        timeout=15,
        check=False,
    )
    return {
        "returncode": proc.returncode,
        "stdout": proc.stdout.decode("utf-8", errors="replace"),
        "stderr": proc.stderr.decode("utf-8", errors="replace"),
    }


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, status: int, obj: dict[str, object]) -> None:
        body = json.dumps(obj, sort_keys=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(200, {"status": "ok"})
            return
        self._send_json(
            200,
            {
                "service": "sagredo qmail qmail-remote benchmark",
                "post": "/api/send",
                "fields": ["recipient", "mx_exchange", "mx_host", "mx_port"],
            },
        )

    def do_POST(self) -> None:
        if self.path != "/api/send":
            self._send_json(404, {"error": "not found"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length)
            data = json.loads(body.decode("utf-8"))
            recipient = str(data["recipient"])
            mx_exchange = str(data["mx_exchange"])
            mx_host = str(data["mx_host"])
            mx_port = int(data["mx_port"])
            if not (1 <= mx_port <= 65535):
                raise ValueError("mx_port out of range")
            result = run_qmail_remote(recipient, mx_exchange, mx_host, mx_port)
        except Exception as exc:
            self._send_json(400, {"error": str(exc)})
            return

        self._send_json(200, result)

    def log_message(self, fmt: str, *args: object) -> None:
        print(f"{self.address_string()} - {fmt % args}", flush=True)


def main() -> None:
    configure_qmail()
    threading.Thread(target=dns_server, daemon=True).start()
    server = ThreadingHTTPServer((APP_HOST, APP_PORT), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
