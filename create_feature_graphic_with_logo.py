#!/usr/bin/env python3
"""
Create 1024x500 feature graphic with ChronoWorks logo
"""

from PIL import Image, ImageDraw, ImageFont
import os

# Create a 1024x500 image with a gradient background
width, height = 1024, 500
img = Image.new('RGB', (width, height), color='#1a237e')  # Dark blue background

# Add a lighter blue gradient effect
draw = ImageDraw.Draw(img)
for i in range(height):
    alpha = i / height
    color_value = int(26 + (63 - 26) * alpha)
    draw.line([(0, i), (width, i)], fill=(26, 35, 126 + int(color_value * 0.5)))

# Load and resize the app icon
icon_path = r"C:\Users\chris\ChronoWorks\play_store_icon_512x512.png"
try:
    app_icon = Image.open(icon_path)
    # Resize icon to fit nicely (200x200)
    icon_size = 180
    app_icon = app_icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)

    # Paste icon on the left side
    icon_x = 80
    icon_y = (height - icon_size) // 2

    # If icon has transparency, paste with alpha channel
    if app_icon.mode == 'RGBA':
        img.paste(app_icon, (icon_x, icon_y), app_icon)
    else:
        img.paste(app_icon, (icon_x, icon_y))

    has_icon = True
    text_x_offset = icon_x + icon_size + 60  # Position text after icon
except Exception as e:
    print(f"Warning: Could not load icon: {e}")
    has_icon = False
    text_x_offset = width // 4  # Center-ish if no icon

# Try to use a nice font
try:
    title_font = ImageFont.truetype("arialbd.ttf", 100)
    subtitle_font = ImageFont.truetype("arial.ttf", 42)
except:
    try:
        title_font = ImageFont.truetype("arial.ttf", 100)
        subtitle_font = ImageFont.truetype("arial.ttf", 42)
    except:
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()

# Add text
title_text = "ChronoWorks"
subtitle_text = "Time Tracking Simplified"

# Draw text
draw = ImageDraw.Draw(img)

# Position text to the right of the icon
title_y = (height // 2) - 60
subtitle_y = title_y + 80

# Draw text with shadow
shadow_offset = 3
# Shadow
draw.text((text_x_offset + shadow_offset, title_y + shadow_offset), title_text, fill='#000000', font=title_font)
draw.text((text_x_offset + shadow_offset, subtitle_y + shadow_offset), subtitle_text, fill='#000000', font=subtitle_font)

# Main text
draw.text((text_x_offset, title_y), title_text, fill='#FFFFFF', font=title_font)
draw.text((text_x_offset, subtitle_y), subtitle_text, fill='#B0BEC5', font=subtitle_font)

# Save the image
output_path = r"C:\Users\chris\ChronoWorks\feature_graphic_1024x500.png"
img.save(output_path, "PNG", optimize=True)

print("Successfully created feature graphic with logo!")
print(f"Location: {output_path}")
print(f"Size: 1024x500 pixels")
