#!/bin/sh
# SUPER+SHIFT+ALT+right-click: the selected text goes to Ask in the notch as an attachment
# (IslandController askWith). Nothing is sent until you press send.
f=$(mktemp --tmpdir selection-XXXXXX.txt) || exit 1
wl-paste --primary --no-newline >"$f" 2>/dev/null
if [ ! -s "$f" ]; then
	rm -f "$f"
	exit 0
fi
exec qs -p "${TACIT_SHELL:-$HOME/.config/quickshell/tacit}" ipc call island askWith "$f"
