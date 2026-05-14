#!/usr/bin/env python3
"""
Generate macOS menu-bar template icons from the full mascot PNG.

Output:
  tray_icon.png     – 18×18 px  (@1x, used on non-retina)
  tray_icon@2x.png  – 36×36 px  (@2x, used on retina — typical today)

Template images must be black pixels on a transparent background so macOS
can auto-color them for light / dark menu bars.
"""

import os
from PIL import Image
import numpy as np

SRC = os.path.join(os.path.dirname(__file__), "icon.png")
OUT = os.path.dirname(__file__)

def make_template(size: int) -> Image.Image:
    src = Image.open(SRC).convert("RGBA")

    # ── 1. Remove white / near-white background ────────────────────────────────
    data = np.array(src, dtype=np.float32)   # shape (H, W, 4)
    r, g, b, a = data[..., 0], data[..., 1], data[..., 2], data[..., 3]

    # Brightness of each pixel (0–255)
    brightness = 0.299 * r + 0.587 * g + 0.114 * b

    # Original alpha (0–255 float)
    orig_alpha = a

    # New alpha: pixels that are bright AND already opaque → transparent
    # Threshold 240/255 catches white and very-light areas
    is_background = (brightness > 230) & (orig_alpha > 200)
    new_alpha = np.where(is_background, 0.0, orig_alpha)

    # ── 2. Convert remaining pixels to black ───────────────────────────────────
    # Template images are black on transparent; macOS tints them automatically.
    out_data = np.zeros_like(data)
    out_data[..., 3] = new_alpha  # keep computed alpha
    # R G B = 0  (black)

    out = Image.fromarray(out_data.astype(np.uint8), "RGBA")

    # ── 3. Resize to target size with high-quality downscaling ─────────────────
    # Work at 4× first so downscaling anti-aliases well
    work_size = max(size * 4, size)
    out = out.resize((work_size, work_size), Image.LANCZOS)
    if work_size != size:
        out = out.resize((size, size), Image.LANCZOS)

    return out


if __name__ == "__main__":
    for size, name in [(18, "tray_icon.png"), (36, "tray_icon@2x.png")]:
        img = make_template(size)
        path = os.path.join(OUT, name)
        img.save(path)
        non_transparent = sum(1 for px in img.getdata() if px[3] > 0)
        print(f"Saved {name}  ({size}×{size}, {non_transparent} non-transparent pixels)")
