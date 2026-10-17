#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# A lookup while the login keyring is still locked opens gnome-keyring's own password window, at
# every boot behind the login lock. Say 'locked' instead; KeyringStorage looks again later.
if [[ "$(busctl --user get-property org.freedesktop.secrets \
        /org/freedesktop/secrets/collection/login \
        org.freedesktop.Secret.Collection Locked 2> /dev/null)" == "b true" ]]; then
    echo 'locked'
    exit 2
fi

data=$(secret-tool lookup 'application' 'illogical-impulse')
if [[ -z "$data" ]]; then
    if "${SCRIPT_DIR}/is_unlocked.sh"; then
        echo 'not found'
        exit 1
    else 
        echo 'locked'
        exit 2
    fi
fi
echo "$data"
