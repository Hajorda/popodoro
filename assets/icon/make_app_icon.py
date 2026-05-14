#!/usr/bin/env python3
"""
Generate Popodoro macOS app icon at all required sizes.

Source: assets/icon/icon.png  (1082×1064, white background)
Output: macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png
"""

import os, math
from collections import deque
import numpy as np
from PIL import Image, ImageFilter

SRC   = os.path.join(os.path.dirname(__file__), "icon.png")
DEST  = os.path.join(
    os.path.dirname(__file__),
    "../../macos/Runner/Assets.xcassets/AppIcon.appiconset",
)

# ── App colours ────────────────────────────────────────────────────────────────
BG_INNER = (195, 232, 210)   # soft sage-mint (centre)
BG_OUTER = (158, 208, 178)   # deeper sage (edge)

SIZES = [16, 32, 64, 128, 256, 512, 1024]


def _bfs(data: np.ndarray, seeds: list, threshold: float) -> np.ndarray:
    """BFS flood fill; returns boolean mask of all pixels reached."""
    H, W = data.shape[:2]
    brightness = (
        0.299 * data[..., 0].astype(float) +
        0.587 * data[..., 1].astype(float) +
        0.114 * data[..., 2].astype(float)
    )
    candidate = brightness > threshold
    visited = np.zeros((H, W), dtype=bool)
    queue = deque()
    for (y, x) in seeds:
        if 0 <= y < H and 0 <= x < W and candidate[y, x] and not visited[y, x]:
            visited[y, x] = True
            queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and not visited[ny, nx] and candidate[ny, nx]:
                visited[ny, nx] = True
                queue.append((ny, nx))
    return visited


def remove_white_bg(img: Image.Image) -> Image.Image:
    """
    Two-pass flood fill to remove background while keeping the cream hat:

    Pass 1 (threshold=252, all 4 borders): removes pure-white (#fff) background.
      The hat (cream, brightness ~244) is below this threshold → preserved.

    Pass 2 (threshold=246, bottom + left/right borders only): removes the
      soft drop-shadow below the mascot. The top border is excluded so the
      fill cannot propagate upward through the white area above the hat.
      The mascot's golden body (brightness ~190-210) blocks lateral spread.
    """
    img = img.convert("RGBA")
    data = np.array(img, dtype=np.uint8)
    H, W = data.shape[:2]

    all_borders = (
        [(y, 0) for y in range(H)] +
        [(y, W - 1) for y in range(H)] +
        [(0, x) for x in range(W)] +
        [(H - 1, x) for x in range(W)]
    )
    bottom_sides = (
        [(y, 0) for y in range(H)] +
        [(y, W - 1) for y in range(H)] +
        [(H - 1, x) for x in range(W)]
    )

    mask = _bfs(data, all_borders, threshold=252) | _bfs(data, bottom_sides, threshold=228)
    data[mask, 3] = 0
    return Image.fromarray(data, "RGBA")


def radial_gradient(size: int) -> Image.Image:
    """Radial gradient background (inner → outer colour)."""
    arr = np.zeros((size, size, 4), dtype=np.uint8)
    cx = cy = size / 2
    max_r = math.sqrt(2) * size / 2

    ys, xs = np.mgrid[0:size, 0:size]
    dist = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
    t = np.clip(dist / max_r, 0, 1)

    for ch, (vi, vo) in enumerate(zip(BG_INNER, BG_OUTER)):
        arr[..., ch] = (vi + (vo - vi) * t).astype(np.uint8)
    arr[..., 3] = 255
    return Image.fromarray(arr, "RGBA")


def make_icon(size: int) -> Image.Image:
    mascot_raw = Image.open(SRC).convert("RGBA")
    mascot = remove_white_bg(mascot_raw)

    # Soften any remaining fringe on the alpha edges
    alpha = mascot.split()[3]
    alpha = alpha.filter(ImageFilter.MinFilter(3))
    mascot.putalpha(alpha)

    # Crop to content bounding box with small padding
    bbox = mascot.getbbox()
    if bbox:
        pad = 6
        bbox = (
            max(0, bbox[0] - pad),
            max(0, bbox[1] - pad),
            min(mascot.width,  bbox[2] + pad),
            min(mascot.height, bbox[3] + pad),
        )
        mascot = mascot.crop(bbox)

    canvas = radial_gradient(size)

    target = int(size * 0.82)
    mw, mh = mascot.size
    scale = target / max(mw, mh)
    nw, nh = int(mw * scale), int(mh * scale)
    mascot = mascot.resize((nw, nh), Image.LANCZOS)

    ox = (size - nw) // 2
    oy = (size - nh) // 2
    canvas.paste(mascot, (ox, oy), mascot)

    return canvas.convert("RGB")


if __name__ == "__main__":
    dest = os.path.realpath(DEST)
    os.makedirs(dest, exist_ok=True)

    for sz in SIZES:
        img = make_icon(sz)
        name = f"app_icon_{sz}.png"
        img.save(os.path.join(dest, name), optimize=True)
        print(f"  {name}  ({sz}×{sz})")

    print(f"\nAll icons written to:\n  {dest}")
