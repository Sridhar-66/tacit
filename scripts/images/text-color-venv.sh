#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../venv.sh"
activate_shell_venv || exit 1
"$SCRIPT_DIR/text_color.py" "$@"
deactivate
