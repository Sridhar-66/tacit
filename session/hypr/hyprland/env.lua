local home_dir = os.getenv("HOME")

-- Where Tacit is installed: the shell and its apps, its launchers (first on PATH), this configuration. Scripts and the
-- shell find each other through these.
hl.env("TACIT_SHELL", "/usr/share/tacit/shell")
hl.env("TACIT_BIN", "/usr/lib/tacit/bin")
hl.env("TACIT_HYPR", "/usr/share/tacit/hypr")
-- hyprlock, hypridle and the screen share portal find Tacit's settings here unless the person has their own in
-- ~/.config/hypr (the XDG search order they already follow)
-- `first` leading the list in `var`, once, and every other entry once (login scripts such as flatpak's put their own
-- folders, and the defaults again, in front of what environment.d set)
local function lead(var, first, default)
    local parts, seen = { first }, { [first] = true }
    for d in (os.getenv(var) or default):gmatch("[^:]+") do
        if not seen[d] then seen[d] = true; parts[#parts + 1] = d end
    end
    hl.env(var, table.concat(parts, ":"))
end
lead("XDG_CONFIG_DIRS", "/usr/share/tacit/xdg", "/etc/xdg")
-- Tacit's app entries first (tacit-session: the terminal named Terminal, tools from drivers and printing hidden, the
-- default apps): /usr/share/tacit came after /usr/share in the VM test, so the hidden tools still showed
lead("XDG_DATA_DIRS", "/usr/share/tacit", "/usr/local/share:/usr/share")
hl.env("PATH", "/usr/lib/tacit/bin:" .. (os.getenv("PATH") or "/usr/local/bin:/usr/bin"))

-- Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Applications
local xdg_data_dirs_old = os.getenv("XDG_DATA_DIRS") or ""
hl.env("XDG_DATA_DIRS", home_dir .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share:" .. xdg_data_dirs_old)

-- Themes
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
-- The build staged a MaterialAdw Kvantum theme in ~/.config/Kvantum and selected it,
-- but the Kvantum engine was never installed, so Qt apps silently fell back to Breeze.
-- With the engine present, this is what actually routes Qt widgets through it.
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("XDG_MENU_PREFIX", "plasma-")

-- Virtual environment for the colour, image and thumbnail helpers: the person's own if they made one (the README's),
-- else the one tacit-shell builds; without either no palette is ever made (a new account, the VM test 2026-10-16)
local user_venv = home_dir .. "/.local/state/quickshell/.venv"
local has_user_venv = io.open(user_venv .. "/bin/activate", "r")
if has_user_venv then has_user_venv:close() end
hl.env("ILLOGICAL_IMPULSE_VIRTUAL_ENV", has_user_venv and user_venv or "/usr/lib/tacit/venv")
