#!/usr/bin/env bash
# The notch's status glyph on the lock screen, as a Material Symbols ligature name.
# Same order as the desktop: charging, then night light. Empty when nothing applies.
b=/sys/class/power_supply/book4-ec-battery/status
if [[ -r $b && $(<"$b") == Charging ]]; then echo bolt; exit; fi
t=$(hyprctl hyprsunset temperature 2>/dev/null | head -1)
[[ -n $t && $t != 6500 ]] && echo bedtime
