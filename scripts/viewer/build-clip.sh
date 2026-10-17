#!/bin/sh
# build-clip.sh [outdir]  -> outdir/viewer-clip (default: next to this script). Needs wayland-scanner and libwayland.
d=$(dirname "$0"); o=${1:-$d}; t=$(mktemp -d)
x=/usr/share/wayland-protocols/staging/ext-data-control/ext-data-control-v1.xml
wayland-scanner client-header $x $t/ext-data-control-v1-client-protocol.h &&
wayland-scanner private-code $x $t/proto.c &&
cc -O2 -I"$t" -o "$o/viewer-clip" "$d/viewer-clip.c" $t/proto.c $(pkg-config --cflags --libs wayland-client)
r=$?; rm -rf "$t"; exit $r
