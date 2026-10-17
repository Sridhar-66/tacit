#!/usr/bin/env bash
# Battery for the lock screen, read from the EC battery (the only real one on this machine;
# the qcom-battmgr devices are dead and report 0%). Prints "42%" or "42% charging".
bat=/sys/class/power_supply/book4-ec-battery
[[ -r $bat/capacity ]] || exit 0
cap=$(<"$bat/capacity")
if [[ $(<"$bat/status") == Charging ]]; then
  echo "${cap}% charging"
else
  echo "${cap}%"
fi
