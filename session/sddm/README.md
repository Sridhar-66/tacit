# session/sddm/

Tacit's login screen (owner's choice 2026-10-08: Tacit's own, not the Thyx theme it had): SDDM on Wayland in a weston
kiosk, the theme `tacit/` drawn with the lock screen's values (BootLockSurface.qml) so signing in looks like unlocking.

| File | Installed as |
|---|---|
| `tacit/` | `/usr/share/sddm/themes/tacit` (`theme.conf.user` links to `/var/lib/tacit-login/theme.conf`) |
| `tacit-login-ground` | `/usr/lib/tacit/tacit-login-ground`: as root before the greeter, copies the newest person's lock ground and colours into `/var/lib/tacit-login` (owned plain files only) |
| `sddm.service.d/tacit-login.conf` | `/usr/lib/systemd/system/sddm.service.d/` (runs the above) |
| `tacit.conf` | `/usr/lib/sddm/sddm.conf.d/tacit.conf` (Wayland, the theme, the cursor) |

This replaces the Thyx theme, its colour template and `book4-sddm-theme-sync` with its sudo rule. Autologin stays a
per-computer choice (/etc/sddm.conf.d/autologin.conf, not packaged).
