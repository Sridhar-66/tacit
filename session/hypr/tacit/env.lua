-- Session environment. custom.env is required from hyprland.lua after
-- hyprland.env, so anything here wins and applies to every process Hyprland
-- spawns -- which is the whole session, since the compositor is the parent.

-- FreeType stem darkening OFF again (2026-10-02). It was on for a day; with
-- Tacit's patched Qt Quick (~/dev/tacit-text: text edges blended in linear
-- light) it made strokes too thick (owner's live A/B/C: "C is right" = patched,
-- no darkening). Set empty rather than removed: a removed line would leave the
-- old value in Hyprland's environment until it restarts.
hl.env("FREETYPE_PROPERTIES", "")
