-- Default variables
-- Copy these to ~/.config/hypr/custom/variables.lua to make changes in a dotfiles-update-friendly manner

-- The shell is found through TACIT_SHELL (hyprland/env.lua), not a folder name under ~/.config/quickshell

-- Apps
-- PULL REQUESTS ADDING MORE WILL NOT BE ACCEPTED, CONFIG FOR YOURSELF
terminal = "$TACIT_HYPR/hyprland/scripts/launch_first_available.sh 'foot' 'alacritty' 'wezterm' 'konsole' 'kgx' 'uxterm' 'xterm'"
fileManager = "files-open"   -- the desktop's own Files (modules/ii/files)
-- (sweep D3) the browser links open in (xdg-settings, set in Settings > Apps), not end-4's list
browser = "gtk-launch \"$(xdg-settings get default-web-browser)\""
codeEditor = "code-open"   -- Graphis, this desktop's editor
officeSoftware = "$TACIT_HYPR/hyprland/scripts/launch_first_available.sh 'wps' 'onlyoffice-desktopeditors' 'libreoffice'"
textEditor = "code-open"   -- Graphis; this desktop has one editor, not two
volumeMixer = "$TACIT_HYPR/hyprland/scripts/launch_first_available.sh 'pavucontrol-qt' 'pavucontrol'"
settingsApp = "qs -p $TACIT_SHELL ipc call settings open"   -- the shell's own settings panel
-- btop in foot: neither system monitor in end-4's list is installed
taskManager = "foot btop"

workspaceGroupSize = 10
