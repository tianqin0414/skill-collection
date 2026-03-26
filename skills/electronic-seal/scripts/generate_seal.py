#!/usr/bin/env python3
"""
Generate a Chinese company electronic seal (电子公章).

Usage:
    python3 generate_seal.py "公司名称" --output /path/to/seal.png [--size 400] [--star-text ""]

Options:
    --output, -o    Output PNG path (default: ./company_seal.png)
    --size, -s      Image size in pixels (default: 400)
    --star-text     Text below the star, e.g. "合同专用章" (default: empty)
    --color         Hex color (default: #C81E1E)

Requires: Pillow (pip install Pillow)
"""

import argparse
import math
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Error: Pillow is required. Install with: pip install Pillow", file=sys.stderr)
    sys.exit(1)


def find_chinese_font(size=28):
    """Find a suitable Chinese font on the system."""
    font_paths = [
        # macOS
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/Supplemental/Songti.ttc",
        "/System/Library/Fonts/Supplemental/STFangsong.ttf",
        "/Library/Fonts/Arial Unicode.ttf",
        # Linux
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
        # Windows
        "C:/Windows/Fonts/simsun.ttc",
        "C:/Windows/Fonts/msyh.ttc",
    ]
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                return ImageFont.truetype(fp, size)
            except Exception:
                continue
    return ImageFont.load_default()


def hex_to_rgba(hex_color, alpha=255):
    """Convert hex color string to RGBA tuple."""
    hex_color = hex_color.lstrip('#')
    r, g, b = int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)
    return (r, g, b, alpha)


def draw_star(draw, cx, cy, r, color):
    """Draw a five-pointed star."""
    points = []
    for i in range(5):
        angle = math.radians(-90 + i * 72)
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
        angle = math.radians(-90 + i * 72 + 36)
        points.append((cx + r * 0.4 * math.cos(angle), cy + r * 0.4 * math.sin(angle)))
    draw.polygon(points, fill=color, outline=color)


def generate_seal(company_name, output_path, size=400, star_text="", color_hex="#C81E1E"):
    """Generate an electronic company seal PNG."""
    color = hex_to_rgba(color_hex)
    center = size // 2
    radius = int(size * 0.4)
    star_radius = int(size * 0.1125)
    line_width = max(2, size // 100)

    img = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)

    # Outer circle
    draw.ellipse(
        [center - radius, center - radius, center + radius, center + radius],
        outline=color, width=line_width
    )

    # Inner circle
    inner_r = radius - max(4, size // 50)
    draw.ellipse(
        [center - inner_r, center - inner_r, center + inner_r, center + inner_r],
        outline=color, width=max(1, line_width // 2)
    )

    # Five-pointed star
    draw_star(draw, center, center, star_radius, color)

    # Star text (e.g. "合同专用章")
    if star_text:
        small_font = find_chinese_font(int(size * 0.045))
        bbox = draw.textbbox((0, 0), star_text, font=small_font)
        tw = bbox[2] - bbox[0]
        draw.text((center - tw // 2, center + star_radius + 5), star_text, font=small_font, fill=color)

    # Company name in circular arc
    font_size = int(size * 0.07)
    font = find_chinese_font(font_size)
    text_radius = radius - int(size * 0.0875)
    char_size = int(size * 0.15)
    n = len(company_name)
    total_angle = min(240, 20 * n + 40)
    start_angle = -90 - total_angle / 2

    for i, char in enumerate(company_name):
        angle_deg = start_angle + (i + 0.5) * total_angle / n
        angle_rad = math.radians(angle_deg)

        x = center + text_radius * math.cos(angle_rad)
        y = center + text_radius * math.sin(angle_rad)

        char_img = Image.new('RGBA', (char_size, char_size), (0, 0, 0, 0))
        char_draw = ImageDraw.Draw(char_img)

        bbox = char_draw.textbbox((0, 0), char, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        cx, cy = char_size // 2, char_size // 2
        char_draw.text((cx - tw // 2, cy - th // 2), char, font=font, fill=color)

        rotation = -(angle_deg + 90)
        char_img = char_img.rotate(rotation, resample=Image.BICUBIC, expand=False)

        paste_x = int(x - char_size // 2)
        paste_y = int(y - char_size // 2)
        img.paste(char_img, (paste_x, paste_y), char_img)

    img.save(output_path, 'PNG')
    print(f"Seal saved: {output_path}")
    return output_path


def main():
    parser = argparse.ArgumentParser(description="Generate a Chinese company electronic seal (电子公章)")
    parser.add_argument("company_name", help="Company name (e.g. '上海则落科技有限公司')")
    parser.add_argument("-o", "--output", default="./company_seal.png", help="Output PNG path")
    parser.add_argument("-s", "--size", type=int, default=400, help="Image size in pixels")
    parser.add_argument("--star-text", default="", help="Text below star (e.g. '合同专用章')")
    parser.add_argument("--color", default="#C81E1E", help="Seal color in hex (default: #C81E1E)")
    args = parser.parse_args()

    generate_seal(args.company_name, args.output, args.size, args.star_text, args.color)


if __name__ == "__main__":
    main()
