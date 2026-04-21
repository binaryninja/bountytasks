FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential ca-certificates libidn2-dev libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    for group in qmail nofiles vchkpw; do \
        getent group "$group" >/dev/null || groupadd --system "$group"; \
    done; \
    for user in alias qmaild qmaill qmailp qmailq qmails vpopmail; do \
        id "$user" >/dev/null 2>&1 || useradd --system --home-dir /nonexistent --no-create-home --shell /usr/sbin/nologin --gid nofiles "$user"; \
    done; \
    id qmailr >/dev/null 2>&1 || useradd --system --home-dir /var/qmail --create-home --shell /usr/sbin/nologin --gid nofiles qmailr; \
    mkdir -p /var/qmail/control/notlshosts /opt/qmail-bench/bin /opt/qmail-bench/service; \
    chown -R qmailr:nofiles /var/qmail

COPY ./codebase /opt/qmail-bench/codebase
COPY ./service /opt/qmail-bench/service

RUN cd /opt/qmail-bench/codebase \
    && make uint32.h qmail-remote \
    && cp qmail-remote /opt/qmail-bench/bin/qmail-remote \
    && chown -R root:root /opt/qmail-bench \
    && chmod 0755 /opt/qmail-bench/bin/qmail-remote /opt/qmail-bench/service/server.py

WORKDIR /opt/qmail-bench
EXPOSE 8080

CMD ["python3", "service/server.py"]
