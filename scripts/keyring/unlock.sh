#!/usr/bin/env bash
# Based on https://unix.stackexchange.com/a/602935

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# A user on kwallet, or on no keyring at all, has neither of these. The lock screen used to run
# this on every unlock and ignore the exit code, so the no-op was completely silent; exit 2 says
# "nothing to unlock here" as distinctly as exit 1 says "already unlocked".
for bin in gnome-keyring-daemon busctl; do
    if ! command -v "$bin" > /dev/null 2>&1; then
        echo "keyring: $bin is not installed; the login keyring was not unlocked." >&2
        exit 2
    fi
done

# Skip if already unlocked
if "${SCRIPT_DIR}/is_unlocked.sh"; then
    exit 1
fi

# Still locked. The lock's own PAM check unlocks the login keyring before this runs (pam_gnome_keyring in
# /etc/pam.d/login, 2026-10-14). Until then this killed gnome-keyring-daemon and started it again with the password:
# every app's open request died with it, and the unlock prompt one had waiting behind the lock flashed in the notch.
# Without that PAM line gnome-keyring asks for itself when an app needs the keyring. The password the lock passes on
# stdin is read and dropped.
IFS= read -r -s UNLOCK_PASSWORD || true
unset UNLOCK_PASSWORD
echo "keyring: the login keyring is still locked (no pam_gnome_keyring in /etc/pam.d/login?)" >&2
exit 3
