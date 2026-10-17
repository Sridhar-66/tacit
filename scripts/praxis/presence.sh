#!/bin/bash
# What is open on the desktop, for Praxis's folders (modules/claude/Presence.qml): terminal,
# Graphis and Pinax windows with their folders, and the agents running on this machine.
# Prints one JSON line:
#   {"at":ms,
#    "windows":[{address,kind:"terminal"|"graphis"|"files",class,title,pid,workspace,special,
#                focus:focusHistoryID,cwd,cmd?,docs?:[{rel,dirty}]}],
#    "agents":[{tool,pid,cwd,session,window}]}
# windows are sorted by address, agents by pid. Read only. A missing tool or IPC gives an empty part, never an error.
set -u
shopt -s nullglob

at=${EPOCHREALTIME//[.,]/}; at=${at%???}
code_qml="${TACIT_SHELL:-$HOME/.config/quickshell/tacit}/code.qml"
US=$'\x1f'

# Every process once: parent, name, first (lowest-pid) child; start time for claude and pi.
declare -A ppid=() name=() first=() start=()
{
    for f in /proc/[0-9]*/stat; do
        read -r line < "$f" || continue
        p=${line%% *}
        c=${line#*\(}; c=${c%\)*}
        r=${line##*\) }; r=${r#* }; pp=${r%% *}
        ppid[$p]=$pp; name[$p]=$c
        [[ -z ${first[$pp]:-} || $p -lt ${first[$pp]} ]] && first[$pp]=$p
        if [[ $c == claude || $c == pi ]]; then
            set -f; fields=($r); set +f
            start[$p]=${fields[18]}   # stat field 22 (r starts at field 4)
        fi
    done
} 2>/dev/null

# A process's working folder into REPLY; "" when it is gone, deleted or not readable.
cwd_of() {
    REPLY=
    [[ -n $1 ]] && cd -P "/proc/$1/cwd" 2>/dev/null && [[ $PWD != /proc/* ]] && REPLY=$PWD
}

clients=$(hyprctl -j clients 2>/dev/null)
[[ $clients == \[* ]] || clients='[]'

# Terminals: the foreground program (the shell's first child), else the shell (the terminal's
# first child), as services/Attention.qml cwdFor reads them.
declare -A owner=()
term=; has_graphis=0; has_files=0
while read -r addr pid cls; do
    [[ -z ${owner[$pid]:-} ]] && owner[$pid]=$addr
    case $cls in
    foot|footclient|kitty|Alacritty|org.wezfurlong.wezterm|com.mitchellh.ghostty)
        sh=${first[$pid]:-}; fg=; [[ -n $sh ]] && fg=${first[$sh]:-}
        cwd=; cmd=
        for q in "$fg" "$sh"; do
            cwd_of "$q"
            [[ -n $REPLY ]] && { cwd=$REPLY; break; }
        done
        [[ -n $fg ]] && cmd=${name[$fg]:-}
        term+="$addr$US$cwd$US$cmd"$'\n' ;;
    graphis) has_graphis=1 ;;
    org.quickshell) has_files=1 ;;
    esac
done < <(jq -r '.[] | "\(.address) \(.pid) \(.class)"' <<<"$clients" 2>/dev/null)

# Graphis's open files; an older Graphis (no `docs`) still gives its root.
gdocs=; groot=
if (( has_graphis )); then
    gdocs=$(qs -p "$code_qml" ipc call code docs 2>/dev/null)
    if [[ $gdocs != \{* ]]; then
        gdocs=
        groot=$(qs -p "$code_qml" ipc call code root 2>/dev/null)
        [[ $groot == /* ]] || groot=
    fi
fi
fwin=
(( has_files )) && fwin=$(qs -c tacit ipc call files windows 2>/dev/null)

# pi's session into REPLY. pi appends to its file and closes it, and writes nothing before its
# first reply, and process.title blanks its cmdline (--session and --session-dir are unreadable).
# So this is a guess: the newest file in pi's default folder for $2, ~/.pi/agent/sessions/
# --<cwd without the leading /, with / \ : as ->--/<ts>_<id>.jsonl, written since the process
# started. "" when none, or when more than one pi runs in that folder.
btime=
pi_session() {
    REPLY=
    [[ -n $2 && ${pis[$2]:-0} == 1 && -n ${start[$1]:-} ]] || return 0
    if [[ -z $btime ]]; then
        while read -r k v; do [[ $k == btime ]] && { btime=$v; break; }; done < /proc/stat
    fi
    local safe=${2#/} t f bt= bf=
    safe=${safe//\//-}; safe=${safe//\\/-}; safe=${safe//:/-}
    # start is in USER_HZ (100) ticks since boot
    while IFS=$'\t' read -r t f; do
        [[ $t > $bt ]] && { bt=$t; bf=$f; }
    done < <(find "$HOME/.pi/agent/sessions/--$safe--" -maxdepth 1 -name '*_*.jsonl' \
                 -newermt "@$(( ${btime:-0} + ${start[$1]} / 100 ))" -printf '%T@\t%f\n' 2>/dev/null)
    bf=${bf%.jsonl}
    [[ -n $bf ]] && REPLY=${bf#*_}
    return 0
}

# Agents by process name. claude's session file counts only when its procStart is this
# process's start time (files of dead pids stay behind); codex by the rollout file it holds
# open; pi by pi_session. `window` is the first ancestor that owns a Hyprland client.
re_start='"procStart"[[:space:]]*:[[:space:]]*"?([0-9]+)'
re_id='"sessionId"[[:space:]]*:[[:space:]]*"([^"]+)"'
declare -A acwd=() pis=()
for p in "${!name[@]}"; do
    case ${name[$p]} in claude|codex|pi|opencode) ;; *) continue ;; esac
    cwd_of "$p"; acwd[$p]=$REPLY
    [[ ${name[$p]} == pi && -n $REPLY ]] && pis[$REPLY]=$(( ${pis[$REPLY]:-0} + 1 ))
done
ag=
for p in "${!acwd[@]}"; do
    tool=${name[$p]}
    cwd=${acwd[$p]}
    session=
    case $tool in
    claude)
        j=
        read -r -d '' j 2>/dev/null < "$HOME/.claude/sessions/$p.json"
        if [[ $j =~ $re_start && ${BASH_REMATCH[1]} == "${start[$p]:-}" && $j =~ $re_id ]]; then
            session=${BASH_REMATCH[1]}
        fi ;;
    codex)
        l=$(find "/proc/$p/fd" -maxdepth 1 -lname '*/rollout-*.jsonl' -printf '%l\n' -quit 2>/dev/null)
        l=${l##*/}; l=${l%.jsonl}
        (( ${#l} > 36 )) && session=${l: -36} ;;
    pi)
        pi_session "$p" "$cwd"; session=$REPLY ;;
    esac
    win=; q=$p
    while [[ -n $q && $q != 0 && $q != 1 ]]; do
        [[ -n ${owner[$q]:-} ]] && { win=${owner[$q]}; break; }
        q=${ppid[$q]:-}
    done
    ag+="$tool$US$p$US$cwd$US$session$US$win"$'\n'
done
cd /

jq -c --argjson at "$at" --arg term "$term" --arg ag "$ag" --arg gdocs "$gdocs" --arg groot "$groot" \
    --arg fwin "$fwin" '
def rows($s): $s | split("\n") | map(select(length > 0) | split("\u001f"));
def parsed($s; $t): ($s | try fromjson catch null) as $v | if ($v | type) == $t then $v else null end;
(rows($term) | map({key: .[0], value: {cwd: .[1], cmd: .[2]}}) | from_entries) as $tm
| (parsed($gdocs; "object") // {root: $groot, docs: []}) as $g
| ((parsed($fwin; "array") // []) | map({key: .address, value: .folder}) | from_entries) as $fm
| {at: $at,
   windows: ([.[]
     | (if $tm[.address] then "terminal"
        elif .class == "graphis" then "graphis"
        elif .class == "org.quickshell" and .title == "Files" and $fm[.address] then "files"
        else empty end) as $k
     | {address, kind: $k, class: .class, title, pid, workspace: .workspace.id,
        special: (.workspace.name // "" | startswith("special")), focus: .focusHistoryID}
       + if $k == "terminal" then
             {cwd: $tm[.address].cwd} + (if $tm[.address].cmd != "" then {cmd: $tm[.address].cmd} else {} end)
         elif $k == "graphis" then {cwd: ($g.root // ""), docs: ($g.docs // [])}
         else {cwd: $fm[.address]} end] | sort_by(.address)),
   agents: (rows($ag) | map({tool: .[0], pid: (.[1] | tonumber), cwd: .[2], session: .[3], window: .[4]})
            | sort_by(.pid))}' <<<"$clients"
