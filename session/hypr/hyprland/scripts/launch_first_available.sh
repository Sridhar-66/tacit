#!/usr/bin/env bash
for cmd in "$@"; do
    [[ -z "$cmd" ]] && continue
    eval "command -v ${cmd%% *}" >/dev/null 2>&1 || continue
    # each app in its own systemd scope (~/.local/bin/app-scope), not as a child of Hyprland
    scope="${TACIT_BIN:-$HOME/.local/bin}/app-scope"
    if [[ -x "$scope" ]]; then
        eval "\"\$scope\" ${cmd%% *} $cmd" &
    else
        eval "$cmd" &
    fi
    exit
done
