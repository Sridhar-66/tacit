#!/usr/bin/env bash
# Sourced, not run: activates the python environment the colour, image and thumbnail helpers use.
#
# ILLOGICAL_IMPULSE_VIRTUAL_ENV is exported by the Hyprland config, not by this tree, so here it
# is a default rather than a requirement. Without either, `source $VAR/bin/activate` used to
# expand to "/bin/activate", fail, and let the caller carry on with whatever python was on PATH -
# which is how a machine with no venv ended up with no generated palette and no message.
activate_shell_venv() {
    local venv
    venv="$(eval echo "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/.venv}")"
    # the one tacit-shell builds, where the person made none
    [[ -f "$venv/bin/activate" ]] || [[ ! -f /usr/lib/tacit/venv/bin/activate ]] || venv=/usr/lib/tacit/venv
    if [[ ! -f "$venv/bin/activate" ]]; then
        echo "No python environment at $venv/bin/activate - see 'Python environment' in the shell's README." >&2
        return 1
    fi
    # shellcheck disable=SC1091
    source "$venv/bin/activate"
}
