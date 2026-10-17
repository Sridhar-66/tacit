#!/usr/bin/env bash
# Path of the current album art for hyprlock's image reload; a transparent pixel when none.
cache=$HOME/.config/hypr/hyprlock/cache
mkdir -p "$cache"
blank=$cache/blank.png
url=$(playerctl metadata mpris:artUrl 2>/dev/null)
st=$(playerctl status 2>/dev/null)
if [[ -z $url || $st == Stopped ]]; then echo "$blank"; exit; fi
case $url in
  file://*) echo "${url#file://}";;
  http*) f=$cache/art-$(echo -n "$url" | md5sum | cut -c1-12).png
         [[ -s $f ]] || { curl -fsL --max-time 3 "$url" -o "$f.part" 2>/dev/null && mv -f "$f.part" "$f"; }
         [[ -s $f ]] && echo "$f" || echo "$blank";;
  *) echo "$blank";;
esac
