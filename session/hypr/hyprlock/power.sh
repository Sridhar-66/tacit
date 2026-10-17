#!/usr/bin/env bash
# Power actions from the lock screen. Shut down wants a second click within 6 seconds.
case $1 in
  sleep) systemctl suspend;;
  restart) systemctl reboot;;
  shutdown)
    stamp=${XDG_RUNTIME_DIR:-/tmp}/hyprlock-shutdown-armed
    if [[ -f $stamp && $(( $(date +%s) - $(stat -c %Y "$stamp") )) -lt 6 ]]; then
      rm -f "$stamp"; systemctl poweroff
    else
      touch "$stamp"
    fi;;
esac
