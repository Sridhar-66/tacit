#!/usr/bin/env bash
stamp=${XDG_RUNTIME_DIR:-/tmp}/hyprlock-shutdown-armed
if [[ -f $stamp && $(( $(date +%s) - $(stat -c %Y "$stamp") )) -lt 6 ]]; then echo "Again to shut down"; else echo "Shut down"; fi
