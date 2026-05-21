#!/usr/bin/env python3
"""Genera 3 logos profesionales para OCG – Ortodoncia Cuéllar Grimaldi."""

import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# ── Brand colors ──
ESPRESSO = (44, 32, 22)      # #2C2016
BRONZE   = (138, 111, 89)    # #8A6F59
IVORY    = (248, 245, 240)   # #F8F5F0
SAND     = (236, 217, 198)   # #ECD9C6
MIST     = (242, 237, 232)   # #F2EDE8
INK      = (26, 20, 16)      # #1A1410
WHITE    = (255, 255, 255)
SUCCESS  = (22, 101, 52)     # #166534

OUT_DIR = os.path.join(os.path.dirname(__file__), "assets", "logos")
os.makedirs(OUT_DIR, exist_ok=True)

def font(size, bold=False):
    """Return best available font."""
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
        "/usr/share/fonts/truetype/noto/NotoSerif-Regular.ttf",
        "/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF/Roboto-Regular.ttf",
    ]
    for p in candidates:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

def font_bold(size):
    for p in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf",
        "/usr/share/fonts/truetype/noto/NotoSerif-Bold.ttf",
    ]:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return font(size, bold=True)

def font_roboto(size, weight="Regular"):
    weight_map = {
        "Thin": "Roboto-Thin.ttf",
        "Light": "Roboto-Light.ttf",
        "Regular": "Roboto-Regular.ttf",
        "Medium": "Roboto-Medium.ttf",
        "Bold": "Roboto-Bold.ttf",
    }
    fname = weight_map.get(weight, "Roboto-Regular.ttf")
    path = f"/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF/{fname}"
    if os.path.exists(path):
        return ImageFont.truetype(path, size)
    return font(size)

def font_ubuntu(size, bold=False):
    suffix = "Bold" if bold else "Regular"
    path = f"/usr/share/fonts/truetype/ubuntu/Ubuntu-{suffix}.ttf"
    if os.path.exists(path):
        return ImageFont.truetype(path, size)
    return font_bold(size) if bold else font(size)

def draw_rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    """Draw a rounded rectangle."""
    x0, y0, x1, y1 = xy
    r = radius
    if fill:
        draw.rectangle([x0+r, y0, x1-r, y1], fill=fill)
        draw.rectangle([x0, y0+r, x1, y1-r], fill=fill)
        draw.pieslice([x0, y0, x0+2*r, y0+2*r], 180, 270, fill=fill)
        draw.pieslice([x1-2*r, y0, x1, y0+2*r], 270, 360, fill=fill)
        draw.pieslice([x0, y1-2*r, x0+2*r, y1], 90, 180, fill=fill)
        draw.pieslice([x1-2*r, y1-2*r, x1, y1], 0, 90, fill=fill)
    if outline:
        draw.arc([x0, y0, x0+2*r, y0+2*r], 180, 270, fill=outline, width=width)
        draw.arc([x1-2*r, y0, x1, y0+2*r], 270, 360, fill=outline, width=width)
        draw.arc([x0, y1-2*r, x0+2*r, y1], 90, 180, fill=outline, width=width)
        draw.arc([x1-2*r, y1-2*r, x1, y1], 0, 90, fill=outline, width=width)
        draw.line([x0+r, y0, x1-r, y0], fill=outline, width=width)
        draw.line([x0+r, y1, x1-r, y1], fill=outline, width=width)
        draw.line([x0, y0+r, x0, y1-r], fill=outline, width=width)
        draw.line([x1, y0+r, x1, y1-r], fill=outline, width=width)

def draw_tooth_icon(draw, cx, cy, size, fill, outline=None, width=1):
    """Draw a simple stylized tooth/molar icon."""
    # Simplified tooth shape using arcs and lines
    s = size
    # Crown (top semi-circle area)
    draw.pieslice([cx-s//2, cy-s//2, cx+s//2, cy+s//6], 180, 360, fill=fill, outline=outline, width=width)
    # Roots (bottom prongs)
    draw.polygon([
        (cx-s//2, cy+s//6),
        (cx-s//3, cy+s//2),
        (cx-s//5, cy+s//3),
        (cx, cy+s//6),
    ], fill=fill, outline=outline, width=width)
    draw.polygon([
        (cx+s//2, cy+s//6),
        (cx+s//3, cy+s//2),
        (cx+s//5, cy+s//3),
        (cx, cy+s//6),
    ], fill=fill, outline=outline, width=width)

def draw_orthodontic_bracket(draw, cx, cy, size, fill, outline=None, width=1):
    """Draw a simple orthodontic bracket icon."""
    s = size
    half = s // 2
    # Main bracket body
    draw_rounded_rect(draw, [cx-half, cy-half, cx+half, cy+half], 4, fill=fill, outline=outline, width=width)
    # Wire slot
    slot_h = max(2, s // 8)
    draw.rectangle([cx-half+3, cy-slot_h//2, cx+half-3, cy+slot_h//2], fill=IVORY if fill != IVORY else BRONZE)
    # Wings
    wing_w = max(3, s // 6)
    draw.rectangle([cx-half-wing_w, cy-half+3, cx-half, cy+half-3], fill=fill, outline=outline, width=width)
    draw.rectangle([cx+half, cy-half+3, cx+half+wing_w, cy+half-3], fill=fill, outline=outline, width=width)

def draw_dental_arch(draw, cx, cy, size, outline, width=2):
    """Draw a U-shaped dental arch curve."""
    s = size
    points = []
    steps = 40
    for i in range(steps + 1):
        t = i / steps
        angle = math.pi * (1 - t)  # from pi to 0
        x = cx + (s // 2) * math.cos(angle)
        y = cy + (s // 2) * math.sin(angle) * 0.7 - s // 8
        points.append((x, y))
    # Draw the arch curve
    for i in range(len(points) - 1):
        draw.line([points[i], points[i+1]], fill=outline, width=width)
    # Draw small circles for teeth positions
    for i in range(0, len(points), 4):
        px, py = points[i]
        r = max(2, s // 16)
        draw.ellipse([px-r, py-r, px+r, py+r], outline=outline, width=max(1, width//2))

# ═══════════════════════════════════════════════════════════
# OPTION 1: App Icon (512×512) — Badge circular premium
# ═══════════════════════════════════════════════════════════
def generate_option1():
    size = 512
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Circular background
    margin = 16
    cx, cy = size // 2, size // 2
    r = (size - margin) // 2
    draw.ellipse([margin, margin, size - margin, size - margin], fill=IVORY, outline=BRONZE, width=3)

    # Inner ring
    inner_r = r - 18
    draw.ellipse([cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r], outline=BRONZE + (100,), width=1)

    # "OCG" text — large, centered
    font_main = font_bold(96)
    bbox = draw.textbbox((0, 0), "OCG", font=font_main)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = cx - tw // 2 - bbox[0]
    ty = cy - th // 2 - bbox[1] - 20
    draw.text((tx, ty), "OCG", fill=ESPRESSO, font=font_main)

    # "ORTODONCIA" subtitle
    font_sub = font_roboto(18, weight="Light")
    bbox2 = draw.textbbox((0, 0), "ORTODONCIA", font=font_sub)
    tw2 = bbox2[2] - bbox2[0]
    draw.text((cx - tw2 // 2 - bbox2[0], ty + th + 16), "ORTODONCIA", fill=BRONZE, font=font_sub)

    # "CUÉLLAR GRIMALDI" subtitle 2
    font_sub2 = font_roboto(14, weight="Regular")
    bbox3 = draw.textbbox((0, 0), "CUÉLLAR GRIMALDI", font=font_sub2)
    tw3 = bbox3[2] - bbox3[0]
    draw.text((cx - tw3 // 2 - bbox3[0], ty + th + 44), "CUÉLLAR GRIMALDI", fill=BRONZE + (180,), font=font_sub2)

    # Decorative dental arch at bottom
    draw_dental_arch(draw, cx, cy + 130, 160, outline=BRONZE + (80,), width=2)

    # Small bracket icon at very bottom
    draw_orthodontic_bracket(draw, cx, cy + 175, 16, fill=BRONZE, outline=ESPRESSO, width=1)

    path = os.path.join(OUT_DIR, "logo_app_icon.png")
    img.save(path, "PNG")
    print(f"✅ Option 1: {path} ({os.path.getsize(path)} bytes)")

# ═══════════════════════════════════════════════════════════
# OPTION 2: Horizontal / System Header Logo (800×200)
# ═══════════════════════════════════════════════════════════
def generate_option2():
    w, h = 800, 200
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── Icon mark (left side) ──
    mark_cx, mark_cy = 90, h // 2
    mark_r = 58
    draw.ellipse([mark_cx - mark_r, mark_cy - mark_r, mark_cx + mark_r, mark_cy + mark_r], fill=ESPRESSO)
    draw.ellipse([mark_cx - mark_r + 6, mark_cy - mark_r + 6, mark_cx + mark_r - 6, mark_cy + mark_r - 6], outline=BRONZE, width=1)

    # Small "OCG" inside circle
    font_mark = font_bold(42)
    bbox = draw.textbbox((0, 0), "OCG", font=font_mark)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((mark_cx - tw // 2 - bbox[0], mark_cy - th // 2 - bbox[1]), "OCG", fill=IVORY, font=font_mark)

    # Small tooth above the text in the circle
    draw_dental_arch(draw, mark_cx, mark_cy - 50, 30, outline=BRONZE + (150,), width=1)

    # ── Text (right side) ──
    text_start_x = 180

    # "OCG" large
    font_ocg = font_bold(64)
    draw.text((text_start_x, 22), "OCG", fill=ESPRESSO, font=font_ocg)

    # Separator line
    line_y = 92
    draw.line([(text_start_x, line_y), (text_start_x + 380, line_y)], fill=BRONZE, width=1)
    # Decorative dot
    dot_r = 3
    draw.ellipse([text_start_x + 190 - dot_r, line_y - dot_r, text_start_x + 190 + dot_r, line_y + dot_r], fill=BRONZE)

    # "ORTODONCIA CUÉLLAR GRIMALDI"
    font_full = font_roboto(16, weight="Light")
    full_text = "ORTODONCIA CUÉLLAR GRIMALDI"
    bbox2 = draw.textbbox((0, 0), full_text, font=font_full)
    tw2 = bbox2[2] - bbox2[0]
    draw.text((text_start_x + (380 - tw2) // 2 - bbox2[0], line_y + 12), full_text, fill=BRONZE, font=font_full)

    # "CLÍNICA DENTAL" smaller
    font_clinic = font_roboto(11, weight="Regular")
    clinic_text = "CLÍNICA DENTAL"
    bbox3 = draw.textbbox((0, 0), clinic_text, font=font_clinic)
    tw3 = bbox3[2] - bbox3[0]
    draw.text((text_start_x + (380 - tw3) // 2 - bbox3[0], line_y + 36), clinic_text, fill=BRONZE + (140,), font=font_clinic)

    path = os.path.join(OUT_DIR, "logo_horizontal.png")
    img.save(path, "PNG")
    print(f"✅ Option 2: {path} ({os.path.getsize(path)} bytes)")

# ═══════════════════════════════════════════════════════════
# OPTION 3: Splash / Loading Logo (400×500) — Vertical
# ═══════════════════════════════════════════════════════════
def generate_option3():
    w, h = 400, 500
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx = w // 2
    cy = h // 2 - 30

    # ── Large OCG mark ──
    mark_r = 110
    draw.ellipse([cx - mark_r, cy - mark_r - 20, cx + mark_r, cy + mark_r - 20], fill=IVORY, outline=BRONZE, width=2)
    draw.ellipse([cx - mark_r + 8, cy - mark_r + 8 - 20, cx + mark_r - 8, cy + mark_r - 8 - 20], outline=BRONZE + (60,), width=1)

    # "OCG" inside circle
    font_mark = font_bold(72)
    bbox = draw.textbbox((0, 0), "OCG", font=font_mark)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((cx - tw // 2 - bbox[0], cy - th // 2 - bbox[1] - 20), "OCG", fill=ESPRESSO, font=font_mark)

    # Dental arch decoration inside the circle (bottom area)
    draw_dental_arch(draw, cx, cy + 50, 100, outline=BRONZE + (90,), width=2)

    # ── Full name below the circle ──
    name_y = cy + mark_r + 30

    font_ocg = font_bold(48)
    bbox_ocg = draw.textbbox((0, 0), "OCG", font=font_ocg)
    tw_ocg = bbox_ocg[2] - bbox_ocg[0]
    draw.text((cx - tw_ocg // 2 - bbox_ocg[0], name_y), "OCG", fill=ESPRESSO, font=font_ocg)

    # Separator line
    sep_y = name_y + 56
    draw.line([(cx - 100, sep_y), (cx - 10, sep_y)], fill=BRONZE, width=1)
    draw.line([(cx + 10, sep_y), (cx + 100, sep_y)], fill=BRONZE, width=1)
    dot_r = 3
    draw.ellipse([cx - dot_r, sep_y - dot_r, cx + dot_r, sep_y + dot_r], fill=BRONZE)

    # "ORTODONCIA CUÉLLAR GRIMALDI"
    font_full = font_roboto(18, weight="Light")
    full_text = "ORTODONCIA CUÉLLAR GRIMALDI"
    bbox_full = draw.textbbox((0, 0), full_text, font=font_full)
    tw_full = bbox_full[2] - bbox_full[0]
    draw.text((cx - tw_full // 2 - bbox_full[0], sep_y + 14), full_text, fill=BRONZE, font=font_full)

    # "CLÍNICA DENTAL"
    font_clinic = font_roboto(12, weight="Regular")
    clinic_text = "CLÍNICA DENTAL"
    bbox_clinic = draw.textbbox((0, 0), clinic_text, font=font_clinic)
    tw_clinic = bbox_clinic[2] - bbox_clinic[0]
    draw.text((cx - tw_clinic // 2 - bbox_clinic[0], sep_y + 40), clinic_text, fill=BRONZE + (140,), font=font_clinic)

    path = os.path.join(OUT_DIR, "logo_splash.png")
    img.save(path, "PNG")
    print(f"✅ Option 3: {path} ({os.path.getsize(path)} bytes)")

# ── Run ──
if __name__ == "__main__":
    generate_option1()
    generate_option2()
    generate_option3()
    print("\n🎨 3 logos generados en assets/logos/")
