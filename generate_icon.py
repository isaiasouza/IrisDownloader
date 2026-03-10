#!/usr/bin/env python3
"""Generate Iris Downloader app icon with warm palette and Neue Montreal font."""

from PIL import Image, ImageDraw, ImageFont
import math
import os

SIZE = 1024
CENTER = SIZE // 2

def create_icon():
    # Colors from the warm palette
    bg_color = (22, 19, 22)          # #161316
    orange = (255, 109, 41)          # #FF6D29
    orange_dark = (204, 86, 32)      # #CC5620
    orange_light = (255, 138, 80)    # #FF8A50
    brown_dark = (69, 48, 39)        # #453027
    white = (255, 255, 255)

    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # --- Rounded square background ---
    corner_radius = 220
    # Draw rounded rect manually
    draw.rounded_rectangle(
        [(0, 0), (SIZE - 1, SIZE - 1)],
        radius=corner_radius,
        fill=bg_color
    )

    # --- Subtle inner border ---
    draw.rounded_rectangle(
        [(3, 3), (SIZE - 4, SIZE - 4)],
        radius=corner_radius - 3,
        outline=(50, 40, 45, 80),
        width=2
    )

    # --- Arrow (download arrow) ---
    # Arrow shaft
    arrow_cx = CENTER
    arrow_top = 180
    arrow_bottom = 580
    shaft_width = 90

    # Gradient-like effect: draw multiple rectangles
    for i in range(shaft_width):
        t = i / shaft_width
        # Interpolate orange_dark -> orange -> orange_light
        if t < 0.5:
            t2 = t * 2
            r = int(orange_dark[0] + (orange[0] - orange_dark[0]) * t2)
            g = int(orange_dark[1] + (orange[1] - orange_dark[1]) * t2)
            b = int(orange_dark[2] + (orange[2] - orange_dark[2]) * t2)
        else:
            t2 = (t - 0.5) * 2
            r = int(orange[0] + (orange_light[0] - orange[0]) * t2)
            g = int(orange[1] + (orange_light[1] - orange[1]) * t2)
            b = int(orange[2] + (orange_light[2] - orange[2]) * t2)
        x = arrow_cx - shaft_width // 2 + i
        draw.line([(x, arrow_top), (x, arrow_bottom)], fill=(r, g, b), width=1)

    # Round the top of the shaft
    draw.ellipse(
        [arrow_cx - shaft_width // 2, arrow_top - shaft_width // 4,
         arrow_cx + shaft_width // 2, arrow_top + shaft_width // 4],
        fill=orange_dark
    )

    # Arrow head (triangle pointing down)
    head_top = 490
    head_bottom = 700
    head_half_width = 200

    # Draw filled triangle with gradient
    for y in range(head_top, head_bottom):
        t = (y - head_top) / (head_bottom - head_top)
        half_w = int(head_half_width * (1 - t))
        # Color gradient top to bottom
        r = int(orange[0] + (orange_light[0] - orange[0]) * t * 0.5)
        g = int(orange[1] + (orange_light[1] - orange[1]) * t * 0.5)
        b = int(orange[2] + (orange_light[2] - orange[2]) * t * 0.5)
        if half_w > 0:
            draw.line([(arrow_cx - half_w, y), (arrow_cx + half_w, y)], fill=(r, g, b), width=1)

    # --- Glow effect behind arrow ---
    glow_img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)
    for r_size in range(150, 0, -2):
        alpha = int(15 * (1 - r_size / 150))
        glow_draw.ellipse(
            [arrow_cx - r_size, 400 - r_size // 2,
             arrow_cx + r_size, 400 + r_size // 2],
            fill=(255, 109, 41, alpha)
        )
    # Composite glow behind the main image
    result = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    # Redraw background on result
    result_draw = ImageDraw.Draw(result)
    result_draw.rounded_rectangle(
        [(0, 0), (SIZE - 1, SIZE - 1)],
        radius=corner_radius,
        fill=bg_color
    )
    result = Image.alpha_composite(result, glow_img)
    result = Image.alpha_composite(result, img)
    draw = ImageDraw.Draw(result)

    # --- Text: "IRIS DOWNLOADER" ---
    font_path = os.path.join(os.path.dirname(__file__), "Resources/Fonts/NeueMontreal-Bold.otf")

    # "IRIS" - larger
    try:
        font_iris = ImageFont.truetype(font_path, 120)
        font_dl = ImageFont.truetype(font_path, 56)
    except Exception:
        font_iris = ImageFont.load_default()
        font_dl = ImageFont.load_default()

    text_y_base = 740

    # Draw "IRIS" centered
    iris_text = "IRIS"
    iris_bbox = draw.textbbox((0, 0), iris_text, font=font_iris)
    iris_w = iris_bbox[2] - iris_bbox[0]
    iris_x = (SIZE - iris_w) // 2
    draw.text((iris_x, text_y_base), iris_text, fill=white, font=font_iris)

    # Draw "DOWNLOADER" centered below
    dl_text = "DOWNLOADER"
    dl_bbox = draw.textbbox((0, 0), dl_text, font=font_dl)
    dl_w = dl_bbox[2] - dl_bbox[0]
    dl_x = (SIZE - dl_w) // 2
    dl_y = text_y_base + 120
    # Letter spacing effect - draw with slight orange tint
    draw.text((dl_x, dl_y), dl_text, fill=orange_light, font=font_dl)

    return result


def create_icns(icon_img, output_dir):
    """Create .icns file from a 1024x1024 image."""
    iconset_dir = os.path.join(output_dir, "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)

    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for name, size in sizes:
        resized = icon_img.resize((size, size), Image.LANCZOS)
        resized.save(os.path.join(iconset_dir, name))

    # Use iconutil to create .icns
    icns_path = os.path.join(output_dir, "AppIcon.icns")
    os.system(f'iconutil -c icns "{iconset_dir}" -o "{icns_path}"')

    # Clean up iconset
    import shutil
    shutil.rmtree(iconset_dir)

    return icns_path


if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    icon = create_icon()

    # Save PNG preview
    png_path = os.path.join(script_dir, "AppIcon.png")
    icon.save(png_path)
    print(f"Saved PNG: {png_path}")

    # Create .icns
    icns_path = create_icns(icon, script_dir)
    print(f"Saved ICNS: {icns_path}")
