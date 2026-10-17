#!/usr/bin/env python3
import json, subprocess, time, os

# Per session, not per boot: /tmp survives a logout on any distro that does not put it on tmpfs,
# and there the guard made autostart a one-time event forever.
lockfile = os.path.join(os.environ.get('XDG_RUNTIME_DIR', '/tmp'), 'qs-autostart.lock')
if os.path.exists(lockfile):
    exit(0)
open(lockfile, 'w').close()

with open(f"{os.environ['HOME']}/.config/illogical-impulse/config.json") as f:
    data = json.load(f)

autostart = data.get('hyprland', {}).get('autostartApps', {})
if not autostart.get('enable', False):
    exit(0)

for app in autostart.get('apps', []):
    cmd = app.get('cmd', '').strip()
    workspace = app.get('workspace', 1)
    delay = app.get('delay', 0)
    if not cmd:
        continue

    subprocess.run(['hyprctl', 'dispatch', f'hl.dsp.focus({{workspace = {workspace}}})'])

    expanded_cmd = os.path.expanduser(cmd)
    # The command lands inside a Lua string literal, so a quote in it ended the string and the
    # whole dispatch was rejected - silently, since nothing reads this output.
    lua_cmd = expanded_cmd.replace('\\', '\\\\').replace('"', '\\"')
    subprocess.Popen(
        ['hyprctl', 'dispatch', f'hl.dsp.exec_cmd("{lua_cmd}")'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True
    )

    time.sleep(delay)