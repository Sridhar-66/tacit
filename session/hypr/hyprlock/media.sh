#!/usr/bin/env bash
# "Title · Artist · playing" from the active MPRIS player; empty when there is none.
out=$(playerctl metadata --format '{{status}}|{{title}}|{{artist}}' 2>/dev/null) || exit 0
IFS='|' read -r st title artist <<<"$out"
[[ -z $title || $st == Stopped ]] && exit 0
line=$title
[[ -n $artist ]] && line+=" · $artist"
[[ $st == Playing ]] && line+=" · playing" || line+=" · paused"
echo "$line"
