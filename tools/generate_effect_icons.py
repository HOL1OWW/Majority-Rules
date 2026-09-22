# Draws the MR effect icon set: flat line-style, single ink color, transparent background.
# Each effect token from the modifier defs gets a 256px PNG plus a combined contact sheet
# so the map team can eyeball the whole family at once and upload in one sitting.
#
#   py tools/generate_effect_icons.py
#
# Upload procedure lives in docs/17-ICON-ASSETS.md.

import math
import os

from PIL import Image, ImageDraw, ImageFont

SIZE = 256
PAD = 40  # stroke clearance so 2.5x-scaled strokes never clip
INK = (24, 25, 30, 255)  # Theme Ink; the UI tints white so this is just the drawing ink
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
STAGE = os.path.join(os.path.dirname(__file__), "..", "assets", "icons", "staging")

# One entry per Effects token in the modifier registry (must stay in sync with
# VoteUI.EFFECT_ICON, which remains the emoji fallback).
ICONS = {
    "GravityDown": "feather",
    "GravityUp": "uparrow",
    "AirTime": "balloon",
    "AirJump": "doublechevronup",
    "Bouncy": "bubble",
    "Drift": "icecrystal",
    "ZeroFriction": "icecrystal",
    "FastWalk": "boot",
    "SlowWalk": "snail",
    "NoJump": "crosscircle",
    "Collapse": "crack",
    "PistolOnly": "pistol",
    "Cover": "crate",
    "Hazard": "warning",
    "Lava": "lava",
    "Gamble": "dice",
    "InfiniteAmmo": "infinity",
    "Lifesteal": "droplet",
    "LoadoutOverride": "gunswap",
    "NoRanged": "crosshairslash",
    "LowHealth": "heart",
    "Ricochet": "ricochet",
    "Shrink": "shrinkarrow",
    "VisionLimited": "fog",
    "Darkness": "moon",
}


def canvas():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save(img, name):
    img.save(os.path.join(STAGE, f"{name}.png"))
    print(f"  {name}.png")


# ---------------------------------------------------------------- primitives

def stroke(d, pts, w=14):
    d.line(pts, fill=INK, width=w, joint="curve")
    for x, y in (pts[0], pts[-1]):
        r = w / 2 - 1
        d.ellipse([x - r, y - r, x + r, y + r], fill=INK)


def poly(d, pts, w=14, close=True):
    pts = list(pts) + [pts[0]] if close else list(pts)
    stroke(d, pts, w)


def circle(d, cx, cy, r, w=14, fill=False):
    if fill:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=INK)
    else:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=INK, width=w)


def arc(d, cx, cy, r, start, end, w=14):
    d.arc([cx - r, cy - r, cx + r, cy + r], start, end, fill=INK, width=w)


def rounded(d, box, radius, w=14, fill=False):
    d.rounded_rectangle(box, radius=radius, outline=None if fill else INK,
                        fill=INK if fill else None, width=w)


# ---------------------------------------------------------------- glyphs

def g_feather(d):
    stroke(d, [(96, 200), (170, 90)])
    poly(d, [(112, 184), (150, 184), (188, 122), (150, 122), (188, 60), (150, 60)], close=False)
    stroke(d, [(150, 184), (150, 122)])
    stroke(d, [(170, 90), (112, 90)])


def g_uparrow(d):
    stroke(d, [(128, 214), (128, 66)])
    stroke(d, [(128, 66), (72, 128)])
    stroke(d, [(128, 66), (184, 128)])
    stroke(d, [(72, 128), (184, 128)])


def g_balloon(d):
    ellipse = [68, 44, 188, 176]
    d.ellipse(ellipse, outline=INK, width=14)
    stroke(d, [(128, 176), (120, 224)])
    stroke(d, [(120, 224), (142, 232)])


def g_doublechevronup(d):
    for off in (0, 62):
        y = 40 + off
        poly(d, [(64, y + 62), (128, y), (192, y + 62)], close=False)


def g_bubble(d):
    circle(d, 128, 118, 70)
    arc(d, 96, 176, 30, 200, 320)
    circle(d, 186, 62, 16, fill=True)


def g_icecrystal(d):
    stroke(d, [(128, 36), (128, 220)])
    for a in (60, 120):
        rad = math.radians(a)
        dx, dy = math.cos(rad) * 84, math.sin(rad) * 84
        stroke(d, [(128 - dx, 128 - dy), (128 + dx, 128 + dy)])
    circle(d, 128, 128, 26, w=10)


def g_boot(d):
    poly(d, [(96, 48), (96, 132), (176, 132), (196, 168), (196, 190), (76, 190), (76, 132)],
         close=False)
    stroke(d, [(76, 190), (196, 190)])


def g_snail(d):
    circle(d, 148, 130, 58)
    d.arc([80, 90, 216, 200], 90, 270, fill=INK, width=14)
    stroke(d, [(80, 146), (56, 196), (196, 196)], w=12)
    stroke(d, [(196, 196), (216, 176)], w=12)
    stroke(d, [(64, 92), (58, 66)], w=10)
    stroke(d, [(84, 92), (90, 66)], w=10)
    circle(d, 60, 62, 7, fill=True)
    circle(d, 92, 62, 7, fill=True)


def g_crosscircle(d):
    circle(d, 128, 128, 88)
    stroke(d, [(92, 92), (164, 164)])
    stroke(d, [(164, 92), (92, 164)])


def g_crack(d):
    stroke(d, [(36, 128), (104, 120), (128, 74), (152, 150), (176, 118), (220, 128)], w=16)
    stroke(d, [(128, 74), (118, 36)], w=12)
    stroke(d, [(152, 150), (196, 186)], w=12)


def g_pistol(d):
    rounded(d, [52, 88, 176, 132], 10)
    poly(d, [(176, 88), (204, 88), (204, 112)], close=False)
    stroke(d, [(80, 132), (80, 188), (124, 188), (124, 132)])
    circle(d, 196, 100, 6, fill=True)


def g_crate(d):
    rounded(d, [48, 48, 208, 208], 14)
    stroke(d, [(48, 48), (208, 208)], w=12)
    stroke(d, [(208, 48), (48, 208)], w=12)


X = None  # keep linters honest about module-level X usage below


def g_gunswap(d):
    poly(d, [(44, 84), (44, 128), (160, 128)], close=False)
    poly(d, [(160, 128), (160, 112), (192, 120), (160, 144), (160, 128)], close=False, w=12)
    poly(d, [(212, 172), (212, 128), (96, 128)], close=False)
    stroke(d, [(96, 128), (96, 150), (68, 136), (96, 112), (96, 128)], w=12)


def g_crosshairslash(d):
    circle(d, 128, 128, 80)
    stroke(d, [(128, 32), (128, 72)], w=12)
    stroke(d, [(128, 184), (128, 224)], w=12)
    stroke(d, [(32, 128), (72, 128)], w=12)
    stroke(d, [(184, 128), (224, 128)], w=12)
    stroke(d, [(64, 64), (192, 192)], w=16)


def g_heart(d):
    d.polygon([(128, 210), (52, 128), (52, 84), (88, 56), (128, 92), (168, 56), (204, 84),
               (204, 128)], fill=INK)
    stroke(d, [(52, 84), (88, 56)], w=14)
    stroke(d, [(88, 56), (128, 92)], w=14)
    stroke(d, [(128, 92), (168, 56)], w=14)
    stroke(d, [(168, 56), (204, 84)], w=14)


def g_lava(d):
    d.polygon([(44, 200), (212, 200), (184, 96), (152, 96), (128, 56), (104, 96), (72, 96)],
              fill=INK)


def g_warning(d):
    d.polygon([(128, 40), (224, 208), (32, 208)], outline=INK, width=14)
    stroke(d, [(128, 100), (128, 156)], w=14)
    circle(d, 128, 182, 9, fill=True)


def g_dice(d):
    rounded(d, [52, 52, 204, 204], 24)
    for cx, cy in ((88, 88), (168, 88), (128, 128), (88, 168), (168, 168)):
        circle(d, cx, cy, 12, fill=True)


def g_infinity(d):
    r = 44
    for cx in (84, 172):
        d.arc([cx - r, 128 - r, cx + r, 128 + r], 0, 360, fill=INK, width=14)


def g_droplet(d):
    d.polygon([(128, 44), (188, 150), (68, 150)], fill=INK)
    d.ellipse([68, 100, 188, 212], fill=INK)
    circle(d, 100, 160, 16, fill=(0, 0, 0, 0))
    d.ellipse([86, 144, 114, 176], fill=(24, 25, 30, 255))


def g_ricochet(d):
    stroke(d, [(40, 200), (110, 130), (96, 118), (170, 96)], w=14)
    poly(d, [(170, 96), (140, 88), (166, 64)], close=False, w=12)
    stroke(d, [(40, 200), (60, 196)], w=16)


def g_shrinkarrow(d):
    stroke(d, [(64, 64), (128, 128)])
    poly(d, [(128, 128), (92, 128), (128, 92)], close=False)
    stroke(d, [(192, 192), (156, 192)], w=12)
    stroke(d, [(192, 192), (192, 156)], w=12)
    stroke(d, [(192, 192), (160, 160)], w=12)


def g_fog(d):
    for y in (84, 128, 172):
        stroke(d, [(48 + (y - 84) // 3, y), (208 - (172 - y) // 3, y)], w=16)


def g_moon(d):
    d.ellipse([56, 40, 216, 200], fill=INK)
    d.ellipse([96, 20, 256, 180], fill=(0, 0, 0, 0))


def g_crossed_rifle(d):
    stroke(d, [(64, 192), (192, 64)], w=14)
    rounded(d, [60, 92, 150, 124], 8)
    stroke(d, [(150, 108), (188, 108)], w=12)
    stroke(d, [(78, 124), (66, 160)], w=12)


GLYPHS = {
    "feather": g_feather, "uparrow": g_uparrow, "balloon": g_balloon,
    "doublechevronup": g_doublechevronup, "bubble": g_bubble, "icecrystal": g_icecrystal,
    "boot": g_boot, "snail": g_snail, "crosscircle": g_crosscircle, "crack": g_crack,
    "pistol": g_pistol, "crate": g_crate, "gunswap": g_gunswap,
    "crosshairslash": g_crosshairslash, "heart": g_heart, "lava": g_lava,
    "warning": g_warning, "dice": g_dice, "infinity": g_infinity,
    "droplet": g_droplet, "ricochet": g_ricochet, "shrinkarrow": g_shrinkarrow,
    "fog": g_fog, "moon": g_moon,
}


def main():
    os.makedirs(STAGE, exist_ok=True)
    print(f"Drawing {len(ICONS)} icons into {os.path.abspath(STAGE)}")
    for token, glyph in ICONS.items():
        if glyph not in GLYPHS:
            raise SystemExit(f"no glyph for {token} -> {glyph}")
        img, d = canvas()
        GLYPHS[glyph](d)
        save(img, token)

    # contact sheet: 6 columns, labeled rows so the upload session is one pass
    tokens = list(ICONS)
    cols, cell, label_h = 6, SIZE // 2, 22
    rows = (len(tokens) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + label_h)), (32, 35, 42, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arialbd.ttf", 14)
    except OSError:
        font = ImageFont.load_default()
    for i, token in enumerate(tokens):
        cx, cy = (i % cols) * cell, (i // cols) * (cell + label_h)
        tile = Image.open(os.path.join(STAGE, f"{token}.png")).resize((cell - 16, cell - 16))
        sheet.paste(tile, (cx + 8, cy + 4), tile)
        draw.text((cx + 8, cy + cell - 14), token, fill=(240, 236, 226, 255), font=font)
    sheet.save(os.path.join(OUT, "contact_sheet.png"))
    print(f"contact sheet: {os.path.abspath(os.path.join(OUT, 'contact_sheet.png'))}")


if __name__ == "__main__":
    main()
