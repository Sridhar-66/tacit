#!/usr/bin/env python3
# argparse, os, re and tempfile only: no virtualenv needed, and the shell runs this with
# `python3 <path>` anyway. The old shebang sourced a venv through /bin/sh, which is dash on
# most distros and has no `source`.
import argparse
import os
import re
import tempfile

BOOL_KEYS = {
    "decoration:blur:enabled",
    "decoration:shadow:enabled",
    "animations:enabled",
    "general:allow_tearing",
    "input:numlock_by_default",
    "input:touchpad:natural_scroll",
    "input:touchpad:disable_while_typing",
    "input:touchpad:clickfinger_behavior",
    "input:touchpad:tap_to_click",
}

FALSE_VALUES = {"0", "0.0", "false", "False", "no", ""}



def to_lua_value(key, value):
    if key in BOOL_KEYS:
        # Callers pass 1/0, but a model-driven toggle forwards the bool itself
        # (HyprlandConfigOption.qml), and "false" used to come out as true.
        return "false" if value.strip() in FALSE_VALUES else "true"
    try:
        return str(int(value))
    except ValueError:
        pass
    try:
        return str(float(value))
    except ValueError:
        pass
    return f'"{value}"'


# "device:<name>:<option>": one option of one input device (Hyprland's hl.device), e.g. a touchpad's own speed. The name
# can hold colons itself ("hid-over-i2c-14e5:650e-touchpad"); the option is after the last one.
def device_key(key):
    if not key.startswith("device:"):
        return None
    name, _, option = key[len("device:"):].rpartition(":")
    return name, option


def to_lua_line(key, value):
    dev = device_key(key)
    if dev:
        return f'hl.device({{ name = "{dev[0]}", {dev[1]} = {to_lua_value(dev[1], value)} }})\n'
    parts = key.replace(":", ".").split(".")
    val = to_lua_value(key, value)
    inner = f"{{ {parts[-1]} = {val} }}"
    for part in reversed(parts[:-1]):
        inner = f"{{ {part} = {inner} }}"
    return f"hl.config({inner})\n"


def make_marker(key):
    dev = device_key(key)
    if dev:
        return f'hl.device({{ name = "{dev[0]}", {dev[1]} ='
    parts = key.replace(":", ".").split(".")

    fragment = " = { ".join(parts[:-1])
    if fragment:
        fragment += " = { " + parts[-1] + " ="
    else:
        fragment = parts[-1] + " ="
    return fragment


def write_atomic(path, content):
    dir_name = os.path.dirname(os.path.abspath(path))
    os.makedirs(dir_name, exist_ok=True)
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=dir_name, delete=False) as f:
            f.write(content)
            tmp_path = f.name
        if os.path.exists(path):
            os.chmod(tmp_path, os.stat(path).st_mode)
        os.replace(tmp_path, path)
    except Exception as e:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)
        raise e


def edit_lua(file_path, set_pairs, reset_keys):
    try:
        with open(file_path) as f:
            lines = f.readlines()
    except FileNotFoundError:
        lines = []

    set_dict   = dict(set_pairs)
    reset_set  = set(reset_keys)
    all_keys   = list(set_dict) + list(reset_set)
    markers    = {k: make_marker(k) for k in all_keys}

    new_lines  = []
    found_keys = set()

    for line in lines:
        matched = None
        for k in all_keys:
            if markers[k] in line:
                matched = k
                break
        if matched is None:
            new_lines.append(line)
        elif matched in reset_set:
            print(f"Removed: {matched}")
        else:
            new_lines.append(to_lua_line(matched, set_dict[matched]))
            found_keys.add(matched)
            print(f"Updated: {to_lua_line(matched, set_dict[matched]).strip()}")

    for k, v in set_dict.items():
        if k not in found_keys:
            new_lines.append(to_lua_line(k, v))
            print(f"Added:   {to_lua_line(k, v).strip()}")

    write_atomic(file_path, "".join(new_lines))


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--file", default="~/.config/hypr/hyprland/shellOverrides/main.lua")
    p.add_argument("--set", nargs=2, action="append", metavar=("KEY", "VALUE"))
    p.add_argument("--reset", action="append", metavar="KEY")
    args = p.parse_args()

    raw_sets   = args.set or []
    reset_keys = args.reset or []
    set_pairs  = []
    for k, v in raw_sets:
        if v == "[[EMPTY]]":
            reset_keys.append(k)
        else:
            set_pairs.append((k, v))

    if set_pairs or reset_keys:
        edit_lua(os.path.expanduser(args.file), set_pairs, reset_keys)
    else:
        print("Error: specify --set or --reset")