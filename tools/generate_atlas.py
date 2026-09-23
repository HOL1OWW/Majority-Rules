import os
import random
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = r"c:\Users\selab\OneDrive\Documents\AI GAMES\The Vote\assets\models\pistol_crate"
os.makedirs(OUTPUT_DIR, exist_ok=True)

ATLAS_SIZE = 2048

def build_crate_texture_atlas():
    atlas = Image.new("RGBA", (ATLAS_SIZE, ATLAS_SIZE), (45, 50, 40, 255))
    
    # -------------------------------------------------------------------------
    # Region A: Top Lid with Stencils
    # U: [0.0, 0.70], V: [0.50, 1.0] -> Pixel X: [0, 1433], Y: [0, 1024]
    # -------------------------------------------------------------------------
    lid_w = int(ATLAS_SIZE * 0.70) # 1433
    lid_h = int(ATLAS_SIZE * 0.50) # 1024
    
    lid_img = Image.new("RGBA", (lid_w, lid_h), (74, 88, 58, 255))
    draw_lid = ImageDraw.Draw(lid_img)
    
    # Plank seams on lid (4 planks)
    random.seed(42)
    plank_h = lid_h // 4
    for y in range(0, lid_h, plank_h):
        draw_lid.rectangle([0, y-3, lid_w, y+3], fill=(32, 38, 25, 255))
        draw_lid.line([0, y+4, lid_w, y+4], fill=(95, 112, 75, 120), width=2)

    # Wood grain on lid
    grain = Image.new("RGBA", (lid_w, lid_h), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(grain)
    for _ in range(3000):
        gx = random.randint(0, lid_w - 1)
        gy = random.randint(0, lid_h - 1)
        glen = random.randint(40, 300)
        alpha = random.randint(15, 60)
        c = (42, 52, 32, alpha) if random.random() < 0.6 else (105, 122, 85, alpha)
        g_draw.line([gx, gy, gx + glen, gy], fill=c, width=random.randint(1, 3))
        
    for _ in range(600):
        sx = random.randint(0, lid_w - 1)
        sy = random.randint(0, lid_h - 1)
        slen = random.randint(8, 45)
        wc = (random.randint(145, 180), random.randint(120, 150), random.randint(85, 110), random.randint(130, 240))
        g_draw.line([sx, sy, sx + slen, sy], fill=wc, width=random.randint(1, 3))
    
    lid_img = Image.alpha_composite(lid_img, grain)
    
    # Stencils on lid
    stencil = Image.new("RGBA", (lid_w, lid_h), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(stencil)
    
    font_large = None
    font_small = None
    try:
        for fname in ["impact.ttf", "arialbd.ttf", "ariblk.ttf"]:
            p = os.path.join(os.environ.get("WINDIR", "C:\\Windows"), "Fonts", fname)
            if os.path.exists(p):
                font_large = ImageFont.truetype(p, 95)
                font_small = ImageFont.truetype(p, 52)
                break
    except Exception:
        pass
    if not font_large:
        font_large = ImageFont.load_default()
        font_small = ImageFont.load_default()

    st_color = (24, 28, 20, 245)
    
    # Text 1: SIDEARM
    t1 = "SIDEARM"
    bb1 = s_draw.textbbox((0, 0), t1, font=font_large)
    w1 = bb1[2] - bb1[0]
    s_draw.text(((lid_w - w1) // 2, 160), t1, fill=st_color, font=font_large)
    
    # Pistol Silhouette in center
    cx, cy = lid_w // 2, 480
    sc = 1.6
    pts = [
        (cx - 220 * sc, cy - 70 * sc),
        (cx + 130 * sc, cy - 70 * sc),
        (cx + 135 * sc, cy - 65 * sc),
        (cx + 120 * sc, cy - 15 * sc),
        (cx + 145 * sc, cy + 120 * sc),
        (cx + 125 * sc, cy + 135 * sc),
        (cx + 55 * sc, cy + 125 * sc),
        (cx + 40 * sc, cy + 15 * sc),
        (cx - 20 * sc, cy + 15 * sc),
        (cx - 45 * sc, cy - 10 * sc),
        (cx - 55 * sc, cy - 30 * sc),
        (cx - 220 * sc, cy - 30 * sc),
    ]
    s_draw.polygon(pts, fill=st_color)
    
    # Trigger guard hole
    cut = [
        (cx + 30 * sc, cy - 8 * sc),
        (cx + 30 * sc, cy + 6 * sc),
        (cx - 18 * sc, cy + 6 * sc),
        (cx - 32 * sc, cy - 8 * sc),
    ]
    s_draw.polygon(cut, fill=(0, 0, 0, 0))
    s_draw.line([(cx + 12 * sc, cy - 6 * sc), (cx + 3 * sc, cy + 4 * sc)], fill=st_color, width=int(6 * sc))
    
    for i in range(5):
        gl = cy + (35 + i * 15) * sc
        s_draw.line([(cx + 58 * sc, gl), (cx + 118 * sc, gl + 8 * sc)], fill=(38, 44, 32, 190), width=int(3 * sc))
    for i in range(7):
        sl = cx + (75 + i * 6) * sc
        s_draw.line([(sl, cy - 65 * sc), (sl - 4 * sc, cy - 35 * sc)], fill=(38, 44, 32, 190), width=int(2 * sc))

    # Text 2: HANDLE WITH CARE
    t2 = "HANDLE WITH CARE"
    bb2 = s_draw.textbbox((0, 0), t2, font=font_small)
    w2 = bb2[2] - bb2[0]
    s_draw.text(((lid_w - w2) // 2, 750), t2, fill=st_color, font=font_small)

    # Weather stencil
    sn = stencil.load()
    for _ in range(5000):
        rx = random.randint(50, lid_w - 50)
        ry = random.randint(120, 850)
        if sn[rx, ry][3] > 0 and random.random() < 0.22:
            sn[rx, ry] = (0, 0, 0, 0)

    lid_img = Image.alpha_composite(lid_img, stencil)
    atlas.paste(lid_img, (0, 0))

    # -------------------------------------------------------------------------
    # Region B: Body Planks (No stencil)
    # U: [0.0, 0.70], V: [0.0, 0.50] -> Pixel X: [0, 1433], Y: [1024, 2048]
    # -------------------------------------------------------------------------
    body_w = lid_w
    body_h = ATLAS_SIZE - lid_h # 1024
    body_img = Image.new("RGBA", (body_w, body_h), (74, 88, 58, 255))
    draw_body = ImageDraw.Draw(body_img)
    
    random.seed(99)
    p_h = body_h // 3
    for y in range(0, body_h, p_h):
        draw_body.rectangle([0, y-3, body_w, y+3], fill=(32, 38, 25, 255))
        draw_body.line([0, y+4, body_w, y+4], fill=(95, 112, 75, 120), width=2)

    grain_b = Image.new("RGBA", (body_w, body_h), (0, 0, 0, 0))
    gb_draw = ImageDraw.Draw(grain_b)
    for _ in range(3500):
        gx = random.randint(0, body_w - 1)
        gy = random.randint(0, body_h - 1)
        glen = random.randint(40, 350)
        alpha = random.randint(15, 60)
        c = (42, 52, 32, alpha) if random.random() < 0.6 else (105, 122, 85, alpha)
        gb_draw.line([gx, gy, gx + glen, gy], fill=c, width=random.randint(1, 3))

    for _ in range(700):
        sx = random.randint(0, body_w - 1)
        sy = random.randint(0, body_h - 1)
        slen = random.randint(8, 50)
        wc = (random.randint(145, 180), random.randint(120, 150), random.randint(85, 110), random.randint(130, 240))
        gb_draw.line([sx, sy, sx + slen, sy], fill=wc, width=random.randint(1, 3))

    body_img = Image.alpha_composite(body_img, grain_b)
    atlas.paste(body_img, (0, 1024))

    # -------------------------------------------------------------------------
    # Region C: Metal Texture (Corner brackets, latch, rivets)
    # U: [0.70, 1.0], V: [0.30, 1.0] -> Pixel X: [1433, 2048], Y: [0, 1433]
    # -------------------------------------------------------------------------
    metal_w = ATLAS_SIZE - lid_w # 615
    metal_h = 1433
    metal_img = Image.new("RGBA", (metal_w, metal_h), (48, 52, 55, 255))
    draw_metal = ImageDraw.Draw(metal_img)
    random.seed(101)
    for _ in range(4000):
        x = random.randint(0, metal_w - 1)
        y = random.randint(0, metal_h - 1)
        rad = random.randint(1, 4)
        if random.random() < 0.45:
            c = (random.randint(95, 135), random.randint(58, 80), random.randint(35, 50), random.randint(70, 190))
        else:
            c = (random.randint(115, 150), random.randint(120, 155), random.randint(125, 160), random.randint(45, 130))
        draw_metal.ellipse([x - rad, y - rad, x + rad, y + rad], fill=c)

    atlas.paste(metal_img, (1433, 0))

    # -------------------------------------------------------------------------
    # Region D: Rope Texture (Handles)
    # U: [0.70, 1.0], V: [0.0, 0.30] -> Pixel X: [1433, 2048], Y: [1433, 2048]
    # -------------------------------------------------------------------------
    rope_w = metal_w # 615
    rope_h = ATLAS_SIZE - metal_h # 615
    rope_img = Image.new("RGBA", (rope_w, rope_h), (162, 136, 100, 255))
    draw_rope = ImageDraw.Draw(rope_img)
    random.seed(202)
    for i in range(-rope_h, rope_w + rope_h, 18):
        draw_rope.line([i, 0, i + rope_h, rope_h], fill=(112, 86, 56, 210), width=5)
        draw_rope.line([i + 5, 0, i + rope_h + 5, rope_h], fill=(198, 172, 132, 210), width=5)
    for _ in range(2500):
        x = random.randint(0, rope_w - 1)
        y = random.randint(0, rope_h - 1)
        draw_rope.point([x, y], fill=(random.randint(90, 215), random.randint(70, 185), random.randint(50, 145), 130))

    atlas.paste(rope_img, (1433, 1433))

    out_path = os.path.join(OUTPUT_DIR, "crate_atlas_albedo.png")
    atlas.save(out_path)
    print("Saved unified texture atlas to:", out_path)
    return out_path

if __name__ == "__main__":
    build_crate_texture_atlas()
