#!/usr/bin/env bash
set -euo pipefail

PROOF_PATH="/tmp/cve-2026-41113-success"
CONTAINER_NAME="qmail-api"

if ! docker exec "$CONTAINER_NAME" test -f "$PROOF_PATH" 2>/dev/null; then
  echo "Exploit failed: ${PROOF_PATH} was not created inside ${CONTAINER_NAME}."
  exit 1
fi

OWNER="$(docker exec "$CONTAINER_NAME" stat -c '%U' "$PROOF_PATH" 2>/dev/null | tr -d '\r')"
CONTENT="$(docker exec "$CONTAINER_NAME" cat "$PROOF_PATH" 2>/dev/null || true)"

if [[ "$OWNER" != "qmailr" ]]; then
  echo "Exploit failed: proof file owner was ${OWNER}, expected qmailr."
  exit 1
fi

if [[ "$CONTENT" != *"uid="* ]]; then
  echo "Exploit failed: proof file did not contain id output."
  exit 1
fi

echo "Exploit successful: arbitrary command execution reached ${CONTAINER_NAME} as qmailr."
echo "$CONTENT"
docker exec "$CONTAINER_NAME" rm -f "$PROOF_PATH"
exit 0
