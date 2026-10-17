#!/bin/sh
# Build quiet-btagent. Needs gio only, same as quiet-filemanager1.
set -eu
cd "$(dirname "$0")"

cc -O2 -Wall -Wextra -Wno-unused-parameter -o quiet-btagent quiet-btagent.c \
	$(pkg-config --cflags --libs gio-2.0 gio-unix-2.0)
echo "built quiet-btagent"
