#!/bin/sh
# Build quiet-filemanager1. The compile line used to exist only as a comment inside the source,
# so the binary sitting beside it could drift from the source with nothing to notice.
set -eu
cd "$(dirname "$0")"

cc -O2 -Wall -Wextra -o quiet-filemanager1 quiet-filemanager1.c $(pkg-config --cflags --libs gio-2.0)
echo "built quiet-filemanager1"
