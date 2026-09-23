import os
import math
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUTPUT_DIR = r"c:\Users\selab\OneDrive\Documents\AI GAMES\The Vote\assets\models\pistol_crate"
os.makedirs(OUTPUT_DIR, exist_ok=True)

WIDTH, HEIGHT = 2048, 1400  # Matches crate lid aspect ratio (1.6 : 1.1)

def create_base_wood(w, h, plank_count=4):
    img = Image.new("RGBA", (w, h), (74, 88, 58, 255))
    draw = ImageDraw.Draw(img)
    
    random.seed(42)
    plank_h = h // plank_count
    for y in range(0, h, plank_h):
        draw.rectangle([0, y-4, w, y+4], fill=(32, 38, 25, 255))
        draw.line([0, y+5, w, y+5], fill=(95, 112, 75, 120), width=2)

    grain_overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    grain_draw = ImageDraw.Draw(grain_overlay)
    
    for _ in range(4000):
        gx = random.randint(0, w - 1)
        gy = random.randint(0, h - 1)
        glen = random.randint(50, 400)
        alpha = random.randint(18, 65)
        if random.random() < 0.6:
            color = (42, 52, 32, alpha)
        else:
            color = (105, 122, 85, alpha)
        grain_draw.line([gx, gy, gx + glen, gy], fill=color, width=random.randint(1, 3))
    
    for _ in range(900):
        sx = random.randint(0, w - 1)
        sy = random.randint(0, h - 1)
        slen = random.randint(8, 55)
        wood_color = (random.randint(145, 180), random.randint(120, 150), random.randint(85, 110), random.randint(130, 240))
        grain_draw.line([sx, sy, sx + slen, sy + random.randint(-1, 1)], fill=wood_color, width=random.randint(1, 3))

    img = Image.alpha_composite(img, grain_overlay)
    
    # Vignette
    vignette = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    v_draw = ImageDraw.Draw(vignette)
    for i in range(80):
        alpha = int(70 * (1 - i / 80))
        v_draw.rectangle([i, i, w - i, h - i], outline=(20, 24, 16, alpha), width=1)
    
    return Image.alpha_composite(img, vignette)

def create_wood_body_texture():
    # 2048 x 1024 for crate body sides
    img = create_base_wood(2048, 1024, plank_count=3)
    out_path = os.path.join(OUTPUT_DIR, "wood_body_albedo.png")
    img.save(out_path)
    print("Saved body wood to", out_path)
    return out_path

def create_wood_lid_texture():
    img = create_base_wood(WIDTH, HEIGHT, plank_count=4)
    stencil_overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(stencil_overlay)
    
    font_large = None
    font_small = None
    try:
        for font_name in ["impact.ttf", "arialbd.ttf", "ariblk.ttf"]:
            p = os.path.join(os.environ.get("WINDIR", "C:\\Windows"), "Fonts", font_name)
            if os.path.exists(p):
                font_large = ImageFont.truetype(p, 130)
                font_small = ImageFont.truetype(p, 70)
                break
    except Exception:
        pass

    if not font_large:
        font_large = ImageFont.load_default()
        font_small = ImageFont.load_default()

    stencil_color = (24, 28, 20, 245)
    
    # Text: "SIDEARM"
    text1 = "SIDEARM"
    bbox1 = s_draw.textbbox((0, 0), text1, font=font_large)
    w1 = bbox1[2] - bbox1[0]
    s_draw.text(((WIDTH - w1) // 2, 220), text1, fill=stencil_color, font=font_large)
    
    # Pistol Silhouette: centered between text1 and text2
    cx, cy = WIDTH // 2, 650
    scale = 2.1
    
    pistol_points = [
        # Slide top
        (cx - 220 * scale, cy - 70 * scale),
        (cx + 130 * scale, cy - 70 * scale),
        (cx + 135 * scale, cy - 65 * scale),
        (cx + 120 * scale, cy - 15 * scale),
        # Grip
        (cx + 145 * scale, cy + 120 * scale),
        (cx + 125 * scale, cy + 135 * scale),
        (cx + 55 * scale, cy + 125 * scale),
        (cx + 40 * scale, cy + 15 * scale),
        # Trigger guard
        (cx - 20 * scale, cy + 15 * scale),
        (cx - 45 * scale, cy - 10 * scale),
        (cx - 55 * scale, cy - 30 * scale),
        (cx - 220 * scale, cy - 30 * scale),
    ]
    s_draw.polygon(pistol_points, fill=stencil_color)
    
    # Trigger guard hole
    guard_cutout = [
        (cx + 30 * scale, cy - 8 * scale),
        (cx + 30 * scale, cy + 6 * scale),
        (cx - 18 * scale, cy + 6 * scale),
        (cx - 32 * scale, cy - 8 * scale),
    ]
    s_draw.polygon(guard_cutout, fill=(0, 0, 0, 0))
    s_draw.line([(cx + 12 * scale, cy - 6 * scale), (cx + 3 * scale, cy + 4 * scale)], fill=stencil_color, width=int(7 * scale))

    # Grip texture
    for i in range(5):
        gy_l = cy + (35 + i * 16) * scale
        s_draw.line([(cx + 58 * scale, gy_l), (cx + 118 * scale, gy_l + 8 * scale)], fill=(38, 44, 32, 190), width=int(3 * scale))
        
    # Slide serrations
    for i in range(7):
        sx_l = cx + (75 + i * 6.5) * scale
        s_draw.line([(sx_l, cy - 65 * scale), (sx_l - 4 * scale, cy - 35 * scale)], fill=(38, 44, 32, 190), width=int(2 * scale))

    # Text: "HANDLE WITH CARE"
    text2 = "HANDLE WITH CARE"
    bbox2 = s_draw.textbbox((0, 0), text2, font=font_small)
    w2 = bbox2[2] - bbox2[0]
    s_draw.text(((WIDTH - w2) // 2, 1020), text2, fill=stencil_color, font=font_small)

    # Distressed stencil weathering
    stencil_np = stencil_overlay.load()
    for _ in range(7000):
        rx = random.randint(100, WIDTH - 100)
        ry = random.randint(180, 1150)
        if stencil_np[rx, ry][3] > 0 and random.random() < 0.22:
            stencil_np[rx, ry] = (0, 0, 0, 0)

    img = Image.alpha_composite(img, stencil_overlay)
    out_path = os.path.join(OUTPUT_DIR, "wood_lid_albedo.png")
    img.save(out_path)
    print("Saved lid wood to", out_path)
    return out_path

def create_metal_texture():
    img = Image.new("RGBA", (1024, 1024), (50, 53, 56, 255))
    draw = ImageDraw.Draw(img)
    random.seed(101)
    for _ in range(3500):
        x = random.randint(0, 1023)
        y = random.randint(0, 1023)
        rad = random.randint(1, 4)
        if random.random() < 0.45:
            color = (random.randint(95, 135), random.randint(58, 80), random.randint(35, 50), random.randint(70, 190))
        else:
            color = (random.randint(115, 145), random.randint(120, 150), random.randint(125, 155), random.randint(45, 130))
        draw.ellipse([x - rad, y - rad, x + rad, y + rad], fill=color)
        
    out_path = os.path.join(OUTPUT_DIR, "metal_albedo.png")
    img.save(out_path)
    print("Saved metal albedo to", out_path)
    return out_path

def create_rope_texture():
    img = Image.new("RGBA", (512, 512), (162, 136, 100, 255))
    draw = ImageDraw.Draw(img)
    random.seed(202)
    for i in range(-512, 1024, 20):
        draw.line([i, 0, i + 512, 512], fill=(112, 86, 56, 210), width=5)
        draw.line([i + 5, 0, i + 517, 512], fill=(198, 172, 132, 210), width=5)
    for _ in range(2500):
        x = random.randint(0, 511)
        y = random.randint(0, 511)
        draw.point([x, y], fill=(random.randint(90, 215), random.randint(70, 185), random.randint(50, 145), 130))
        
    out_path = os.path.join(OUTPUT_DIR, "rope_albedo.png")
    img.save(out_path)
    print("Saved rope albedo to", out_path)
    return out_path

if __name__ == "__main__":
    create_wood_body_texture()
    create_wood_lid_texture()
    create_metal_texture()
    create_rope_texture()
