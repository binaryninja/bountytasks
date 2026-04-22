#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEBASE_DIR="$ROOT_DIR/codebase"
BUILD_DIR="$(mktemp -d /tmp/libcap-invariants-build-XXXXXX)"
BUILD_LOG="$(mktemp /tmp/libcap-invariants-build-log-XXXXXX)"
trap 'rm -rf "$BUILD_DIR" "$BUILD_LOG"' EXIT

build_artifacts=0
build_status=0

if BUILD_DIR="$BUILD_DIR" make -C "$CODEBASE_DIR" clean all >"$BUILD_LOG" 2>&1; then
  for artifact in libcap_swap_hook.so manual_toctou_poc swap_loop; do
    if [[ -x "$BUILD_DIR/$artifact" ]]; then
      build_artifacts=$((build_artifacts + 1))
    fi
  done
else
  build_status=$?
  cat "$BUILD_LOG" >&2
fi

cat >"$ROOT_DIR/invariant_scores.json" <<EOF
{
  "invariant_scores": {
    "build_artifacts": $build_artifacts
  }
}
EOF

exit "$build_status"
