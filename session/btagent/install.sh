#!/bin/sh
# Install quiet-btagent for this user: the binary and the session unit.
#
# This enables a user unit and starts nothing. Run `systemctl --user start quiet-btagent.service`
# or log in again. While it is not running, pairing a device that asks for a confirmation fails
# with "Refused" instead of waiting for a dialog that cannot appear.
set -eu
cd "$(dirname "$0")"

./build.sh

bin="$HOME/.local/bin/quiet-btagent"
install -Dm755 quiet-btagent "$bin"

install -Dm644 quiet-btagent.service \
	"${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/quiet-btagent.service"
systemctl --user daemon-reload
systemctl --user enable quiet-btagent.service

echo "installed $bin"
echo "enabled quiet-btagent.service, wanted by tacit-session.target"
