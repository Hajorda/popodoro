#!/usr/bin/env python3
"""Generate DMG background images (1x and 2x) for Popodoro installer."""

from PIL import Image, ImageDraw, ImageFilter
import math, os

W, H = 660, 420  # DMG window size

# App colors
BG        = (251, 248, 242)   # #FBF8F2
POP       = (255, 200, 87)    # #FFC857
POP_DEEP  = (232, 169, 58)    # #E8A93A
SAGE      = (123, 184, 147)   # #7BB893
INK       = (28, 26, 23)      # #1C1A17
INK2      = (92, 84, 75)      # #5C544B
INK3      = (142, 134, 124)   # #8E867C
SURFACE   = (255, 255, 255)
BORDER    = (227, 220, 208)   # subtle border

def make_bg(scale=1):
    w, h = W * scale, H * scale
    img = Image.new("RGBA", (w, h), (*BG, 255))
    draw = ImageDraw.Draw(img)

    # ── Subtle dot grid ────────────────────────────────────────────────────────
    dot_r = max(1, scale)
    spacing = 28 * scale
    for gy in range(0, h + spacing, spacing):
        for gx in range(0, w + spacing, spacing):
            draw.ellipse(
                [gx - dot_r, gy - dot_r, gx + dot_r, gy + dot_r],
                fill=(*BORDER, 120),
            )

    # ── Top accent strip ───────────────────────────────────────────────────────
    strip_h = 4 * scale
    draw.rectangle([0, 0, w, strip_h], fill=(*POP, 255))

    # ── Decorative soft circles (background blobs) ─────────────────────────────
    blob = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blob)
    # large warm blob top-left
    bd.ellipse([-60*scale, -80*scale, 260*scale, 200*scale], fill=(*POP, 18))
    # medium sage blob bottom-right
    bd.ellipse([420*scale, 230*scale, 780*scale, 520*scale], fill=(*SAGE, 14))
    blob = blob.filter(ImageFilter.GaussianBlur(radius=30*scale))
    img = Image.alpha_composite(img, blob)
    draw = ImageDraw.Draw(img)

    # ── App name ───────────────────────────────────────────────────────────────
    try:
        from PIL import ImageFont
        # Try system fonts in order of preference
        font_paths = [
            "/System/Library/Fonts/Supplemental/Georgia.ttf",
            "/System/Library/Fonts/Georgia.ttf",
            "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
            "/System/Library/Fonts/Times New Roman.ttf",
        ]
        title_font = None
        for fp in font_paths:
            if os.path.exists(fp):
                title_font = ImageFont.truetype(fp, size=38 * scale)
                break
        sub_font_paths = [
            "/System/Library/Fonts/Helvetica.ttc",
            "/System/Library/Fonts/HelveticaNeue.ttc",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
        ]
        sub_font = None
        for fp in sub_font_paths:
            if os.path.exists(fp):
                sub_font = ImageFont.truetype(fp, size=13 * scale)
                break
        arrow_font = None
        for fp in sub_font_paths:
            if os.path.exists(fp):
                arrow_font = ImageFont.truetype(fp, size=11 * scale)
                break
    except Exception:
        title_font = sub_font = arrow_font = None

    # Title
    title = "Popodoro"
    tx = w // 2
    ty = (36 if scale == 1 else 34) * scale
    draw.text((tx, ty), title, font=title_font, fill=(*INK, 255), anchor="mm")

    # Subtitle
    sub = "Focus timer for macOS"
    draw.text((tx, ty + 26 * scale), sub, font=sub_font, fill=(*INK3, 255), anchor="mm")

    # ── Divider under header ───────────────────────────────────────────────────
    div_y = 78 * scale
    draw.line([40*scale, div_y, (w - 40*scale), div_y], fill=(*BORDER, 200), width=scale)

    # ── Arrow between app icon and Applications ────────────────────────────────
    # App icon is at x=170, Applications at x=490 (center positions)
    arrow_y = 200 * scale
    ax1 = 240 * scale  # start right of app icon
    ax2 = 420 * scale  # end left of Applications folder
    mid = (ax1 + ax2) // 2

    # Line
    line_y = arrow_y
    draw.line([ax1, line_y, ax2, line_y], fill=(*INK3, 160), width=2 * scale)

    # Arrowhead (right-pointing)
    aw = 8 * scale
    ah = 5 * scale
    draw.polygon(
        [(ax2, line_y), (ax2 - aw, line_y - ah), (ax2 - aw, line_y + ah)],
        fill=(*INK3, 160),
    )

    # "drag to install" label under arrow
    arrow_label = "drag to install"
    draw.text(
        (mid, line_y + 14 * scale),
        arrow_label,
        font=arrow_font,
        fill=(*INK3, 180),
        anchor="mm",
    )

    # ── Icon labels ────────────────────────────────────────────────────────────
    label_y = 270 * scale
    draw.text((170 * scale, label_y), "Popodoro", font=sub_font, fill=(*INK2, 200), anchor="mm")
    draw.text((490 * scale, label_y), "Applications", font=sub_font, fill=(*INK2, 200), anchor="mm")

    # ── Version badge ──────────────────────────────────────────────────────────
    ver = "v1.0.0"
    draw.text(
        (w // 2, (H - 18) * scale),
        ver,
        font=arrow_font,
        fill=(*INK3, 140),
        anchor="mm",
    )

    return img.convert("RGB")


if __name__ == "__main__":
    out_dir = os.path.dirname(os.path.abspath(__file__))

    bg1x = make_bg(scale=1)
    bg1x.save(os.path.join(out_dir, "background.png"))
    print(f"Saved background.png  ({W}×{H})")

    bg2x = make_bg(scale=2)
    bg2x.save(os.path.join(out_dir, "background@2x.png"))
    print(f"Saved background@2x.png  ({W*2}×{H*2})")
