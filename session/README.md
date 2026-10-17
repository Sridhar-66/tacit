# session/

The parts of the Tacit session that run beside the shell, as the packages install them (paths are the package's:
/usr/lib/tacit/bin). The running copies on this laptop are still the hand-placed ones in ~/.config/systemd/user,
~/.local/share/applications and ~/.local/share/dbus-1 until the switch.

| Folder | What |
|---|---|
| `systemd/user/` | tacit-session.target and the services under it: focus-priority, the Bluetooth agent, FileManager1, the "gave up" notice; `service.d/50-oomd-avoid.conf` keeps systemd-oomd off the user's services |
| `dbus/` | FileManager1's D-Bus activation ("show in folder" opens Files) |
| `applications/` | the apps' menu entries: Activity, Praxis, Graphis, Files (Pinax), Viewer |
| `btagent/`, `filemanager1/` | the two compiled helpers' sources and build scripts |
