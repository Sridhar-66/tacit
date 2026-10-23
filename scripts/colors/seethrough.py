#!/usr/bin/env python3
"""seethrough.py <image> [colors.json]: how much of this wallpaper Tacit's glass lets through, as one scale on every
see-through amount (the apps' windows and foot, windows not in use, the shell's frost, the browsers' rules), written to
generated/seethrough.json as {"scale": s}.

On dusk.jpg, Tacit's own wallpaper, the designed amounts keep every ground dark under readable text. Over a bright
wallpaper the same amounts let its light through: the grounds turned grey and the frost's main text fell from Lc 83 to 75
(Leaf, Glaze, Moss; measured 2026-10-23, "on dusk the readability is good, do that for other backgrounds"). The scale
is the largest, at most 1, that keeps each material's ground no lighter than it is on dusk,
over the brightest tenth of the wallpaper as the blur shows it. Dark wallpapers keep the designed glass."""
import json, os, sys
from PIL import Image, ImageFilter

STATE = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
GENERATED = os.path.join(STATE, "quickshell/user/generated")

# the designed see-through: foot.ini alpha 0.85, inactive_opacity 0.82, the frost (Appearance.colPanelFrost) at 0.76
WINDOW, UNFOCUSED, FROST = 0.15, 0.18, 0.24
# the grounds' lightness (CIE L*) on dusk.jpg at those amounts, from the same model
DUSK = {"window": 18.47, "unfocused": 26.70, "frost": 28.03}
# the blur's own steps (hypr/tacit/general.lua): contrast 0.95, brightness 1.06
BLUR_CONTRAST, BLUR_BRIGHTNESS = 0.95, 1.06


def linear(v):
    v /= 255
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def lightness(c):
    y = 0.2126 * linear(c[0]) + 0.7152 * linear(c[1]) + 0.0722 * linear(c[2])
    return 116 * y ** (1 / 3) - 16 if y > 0.008856 else 903.3 * y


def over(top, under, alpha):   # the compositor blends in sRGB
    return tuple(alpha * a + (1 - alpha) * b for a, b in zip(top, under))


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def behind(image):
    """the blurred wallpaper's brightest tenth, after the blur's contrast and brightness"""
    im = Image.open(image).convert("RGB").resize((192, 108)).filter(ImageFilter.GaussianBlur(6))
    px = sorted(im.getdata(), key=lightness)
    b = px[int(len(px) * 0.9)]
    return tuple(min(255.0, ((v / 255 - 0.5) * BLUR_CONTRAST + 0.5) * BLUR_BRIGHTNESS * 255) for v in b)


def grounds(low, high, b, scale):
    window = over(low, b, 1 - WINDOW * scale)
    return {"window": window, "unfocused": over(window, b, 1 - UNFOCUSED * scale), "frost": over(high, b, 1 - FROST * scale)}


def scale_for(image, colors):
    low, high = hex_rgb(colors["surface_container_low"]), hex_rgb(colors["surface_container_high"])
    b = behind(image)
    fits = lambda s: all(lightness(g) <= DUSK[k] + 0.05 for k, g in grounds(low, high, b, s).items())
    if fits(1.0):
        return 1.0
    lo, hi = 0.0, 1.0
    for _ in range(24):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if fits(mid) else (lo, mid)
    return lo


def main():
    image = sys.argv[1]
    colors = json.load(open(sys.argv[2] if len(sys.argv) > 2 else os.path.join(GENERATED, "colors.json")))
    try:
        scale = round(scale_for(image, colors), 3)
    except (OSError, ValueError, KeyError) as e:
        print(f"seethrough: {e}; the designed glass stays", file=sys.stderr)
        scale = 1.0
    os.makedirs(GENERATED, exist_ok=True)
    tmp = os.path.join(GENERATED, "seethrough.json.tmp")
    with open(tmp, "w") as f:
        json.dump({"scale": scale}, f)
    os.replace(tmp, os.path.join(GENERATED, "seethrough.json"))
    print(scale)


if __name__ == "__main__":
    main()
