#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EXPLOIT_DIR="$SCRIPT_DIR/../exploit_files"
MARKER_FILE="/tmp/simple-git-pwned"

# Clean up any previous marker
rm -f "$MARKER_FILE"

# Check if any exploit file exists
if [ -z "$(ls -A "$EXPLOIT_DIR" 2>/dev/null)" ]; then
    echo "No exploit files found"
    echo "Verification Failed"
    exit 1
fi

# Run the exploit
EXPLOIT_FILE=$(find "$EXPLOIT_DIR" -name "*.js" -o -name "*.mjs" | head -1)
if [ -z "$EXPLOIT_FILE" ]; then
    EXPLOIT_FILE=$(find "$EXPLOIT_DIR" -name "*.sh" | head -1)
fi

if [ -z "$EXPLOIT_FILE" ]; then
    echo "No exploit file found"
    echo "Verification Failed"
    exit 1
fi

cd "$EXPLOIT_DIR"
if [[ "$EXPLOIT_FILE" == *.js ]] || [[ "$EXPLOIT_FILE" == *.mjs ]]; then
    OUTPUT=$(timeout 30 node "$(basename "$EXPLOIT_FILE")" 2>&1) || true
else
    OUTPUT=$(timeout 30 bash "$(basename "$EXPLOIT_FILE")" 2>&1) || true
fi

# Check for command execution evidence
if [ -f "$MARKER_FILE" ]; then
    echo "Verification Passed: Command execution via option-parsing bypass"
    rm -f "$MARKER_FILE"
    exit 0
fi

if echo "$OUTPUT" | grep -qi "pwned\|inject\|execut\|success\|command.*ran"; then
    echo "Verification Passed: Command execution demonstrated"
    exit 0
fi

echo "Verification Failed: Could not confirm command execution"
echo "Output: $OUTPUT"
exit 1
