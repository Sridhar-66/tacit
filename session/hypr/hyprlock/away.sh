#!/usr/bin/env bash
# Unread notifications from the shell, phrased for the lock screen; empty when none.
n=$(timeout 1 qs -p "${TACIT_SHELL:-$HOME/.config/quickshell/tacit}" ipc call notifications count 2>/dev/null | tr -dc 0-9)
[[ -z $n || $n == 0 ]] && exit 0
[[ $n == 1 ]] && echo "1 notification while you were away" || echo "$n notifications while you were away"
