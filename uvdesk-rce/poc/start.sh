#!/bin/bash
# Project Apex - UVdesk victim server bootstrap
# core-framework@3b31910 (pinned, verified == current HEAD, unmodified)
set -euo pipefail
cd "$(dirname "$0")"

BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
CYAN=$'\033[38;2;80;200;255m'; GREEN=$'\033[38;2;110;231;150m'

IMAGE=apex-uvdesk-victim
CONTAINER=apex-uvdesk-victim
PORT=8930

echo "${DIM}# uvdesk/core-framework@3b31910 - unmodified, pinned, verified == current HEAD${RESET}"
echo "${BOLD}\$${RESET} docker build -t $IMAGE . -q"
docker build -t "$IMAGE" . -q

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "${BOLD}\$${RESET} docker run -d --name $CONTAINER -p 127.0.0.1:$PORT:80 $IMAGE"
CID=$(docker run -d --name "$CONTAINER" -p "127.0.0.1:$PORT:80" "$IMAGE")
echo "${GREEN}${CID}${RESET}"

for i in $(seq 1 20); do
    curl -s -o /dev/null "http://127.0.0.1:$PORT/" && break
    sleep 0.5
done

echo
echo "${CYAN}victim helpdesk up${RESET}  →  http://127.0.0.1:${PORT}"
echo "${DIM}(waiting for a support ticket...)${RESET}"
