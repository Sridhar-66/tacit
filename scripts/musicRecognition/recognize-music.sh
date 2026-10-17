#!/bin/bash

TOTAL_DURATION=30
SOURCE_TYPE="monitor"  # monitor | input

while getopts "t:s:" opt; do
  case $opt in
    t) TOTAL_DURATION=$OPTARG ;;
    s) SOURCE_TYPE=$OPTARG ;;
    *) exit 1 ;;
  esac
done

if ! command -v songrec >/dev/null 2>&1; then
    exit 1
fi

if [ "$SOURCE_TYPE" = "monitor" ]; then
    AUDIO_DEVICE=$(pactl info | grep "Default Sink:" | awk '{print $3}').monitor
elif [ "$SOURCE_TYPE" = "input" ]; then
    AUDIO_DEVICE=$(pactl info | grep "Default Source:" | awk '{print $3}' || true)
else
    echo "Invalid source type"
    exit 1
fi

if [ -z "$AUDIO_DEVICE" ] || ! pactl list short sources | grep -Fq "$AUDIO_DEVICE"; then
    # Fallback to the first available source if default monitor/source check fails
    AUDIO_DEVICE=$(pactl list short sources | head -n 1 | awk '{print $2}')
    if [ -z "$AUDIO_DEVICE" ]; then
        exit 1
    fi
fi

# A private directory, not a reserved name in /tmp: `mktemp -u` only booked the path, and
# another local user could win the race to create it and read the recognised song.
WORK_DIR=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/songrec.XXXXXX") || exit 1
FIFO="$WORK_DIR/out"
mkfifo "$FIFO" || exit 1

cleanup() {
    kill "$SONGREC_PID" 2>/dev/null || true
    wait "$SONGREC_PID" 2>/dev/null
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# `timeout` owns the total duration, so there is no watchdog subshell left behind on an
# early exit.
timeout "$TOTAL_DURATION" songrec listen --audio-device "$AUDIO_DEVICE" --json --disable-mpris > "$FIFO" &
SONGREC_PID=$!

while IFS= read -r line; do
    if echo "$line" | grep -q '"matches" *: *\['; then
        if echo "$line" | grep -q '"matches" *: *\[\]'; then
            continue
        fi
        echo "$line"
        exit 0
    fi
done < "$FIFO"

exit 0
