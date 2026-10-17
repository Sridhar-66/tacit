#!/bin/sh
# Builds Graphis's one-step edits (Tacit.Edit) and installs it to ~/.local/lib/qml/Tacit/Edit, where code.qml's
# QML_IMPORT_PATH finds it. Rebuild after a Qt update: the plugin is built against this Qt's exact version.
set -e
HERE=$(dirname "$(readlink -f "$0")")
B=${XDG_CACHE_HOME:-$HOME/.cache}/tacit-edit-build
cmake -S "$HERE" -B "$B" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$B"
D=$HOME/.local/lib/qml/Tacit/Edit
mkdir -p "$D"
# by rename: a running Graphis has the old library mapped, and overwriting it in place can crash it
for f in libtacitedit.so qmldir tacitedit.qmltypes; do
    cp "$B/qml/Tacit/Edit/$f" "$D/.$f.new" && mv -f "$D/.$f.new" "$D/$f"
done
echo "installed $D"
