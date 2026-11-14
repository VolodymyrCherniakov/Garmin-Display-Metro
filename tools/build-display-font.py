#!/usr/bin/env python3
"""Generate the small, static BMFont used by the watch face (requires Pillow).

Usage: python tools/build-display-font.py /path/to/FiraSansCondensed-SemiBold.ttf [size] [name]
The generated glyphs retain the source font's SIL Open Font License.
"""
import math
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont


def main():
    size = int(sys.argv[2]) if len(sys.argv) > 2 else 22
    name = sys.argv[3] if len(sys.argv) > 3 else "metro-readable"
    font = ImageFont.truetype(sys.argv[1], size)
    chars = " %,-./:0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZkm°"
    bounds = [font.getbbox(c, anchor="ls") for c in chars]
    top = min(b[1] for b in bounds)
    bottom = max(b[3] for b in bounds)
    line_height = bottom - top + 2
    baseline = 1 - top
    cell = 32
    atlas = Image.new("RGBA", (256, math.ceil(len(chars) / 8) * cell))
    draw = ImageDraw.Draw(atlas)
    lines = [
        f'info face="Metro Readable" size={size} bold=1 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0',
        f'common lineHeight={line_height} base={baseline} scaleW={atlas.width} scaleH={atlas.height} pages=1 packed=0',
        f'page id=0 file="{name}.png"',
        f'chars count={len(chars)}',
    ]
    for i, (char, (left, top, right, bottom)) in enumerate(zip(chars, bounds)):
        x, y = (i % 8) * cell, (i // 8) * cell
        draw.text((x - left, y - top), char, font=font, anchor="ls", fill="white")
        advance = max(round(font.getlength(char)), right)
        lines.append(
            f'char id={ord(char)} x={x} y={y} width={right-left} height={bottom-top} '
            f'xoffset={left} yoffset={baseline+top} xadvance={advance} page=0 chnl=15'
        )
    # A crisp 1-bit mask keeps this font inexpensive on the Fenix MIP screen.
    atlas.putalpha(atlas.getchannel("A").point(lambda a: 255 if a >= 96 else 0))
    out = Path(__file__).resolve().parents[1] / "resources" / "fonts"
    out.mkdir(parents=True, exist_ok=True)
    atlas.save(out / (name + ".png"))
    (out / (name + ".fnt")).write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
