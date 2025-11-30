#!/usr/bin/env python3
"""
Create 1024x500 feature graphic for Google Play Store
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
    color_value = int(26 + (63 - 26) * alpha)  # Gradient from #1a237e to #3f51b5
    draw.line([(0, i), (width, i)], fill=(26, 35, 126 + int(color_value * 0.5)))

# Try to use a nice font, fall back to default if not available
try:
    # Try Arial Bold
    title_font = ImageFont.truetype("arialbd.ttf", 120)
    subtitle_font = ImageFont.truetype("arial.ttf", 48)
except:
    # Fall back to default font
    try:
        title_font = ImageFont.truetype("arial.ttf", 120)
        subtitle_font = ImageFont.truetype("arial.ttf", 48)
    except:
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()

# Add text
title_text = "ChronoWorks"
subtitle_text = "Time Tracking Simplified"

# Calculate text positions (centered)
draw = ImageDraw.Draw(img)

# Get text bounding boxes for centering
try:
    title_bbox = draw.textbbox((0, 0), title_text, font=title_font)
    title_width = title_bbox[2] - title_bbox[0]
    title_height = title_bbox[3] - title_bbox[1]

    subtitle_bbox = draw.textbbox((0, 0), subtitle_text, font=subtitle_font)
    subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
    subtitle_height = subtitle_bbox[3] - subtitle_bbox[1]
except:
    # Fallback for older Pillow versions
    title_width, title_height = draw.textsize(title_text, font=title_font)
    subtitle_width, subtitle_height = draw.textsize(subtitle_text, font=subtitle_font)

title_x = (width - title_width) // 2
title_y = (height - title_height) // 2 - 40

subtitle_x = (width - subtitle_width) // 2
subtitle_y = title_y + title_height + 20

# Draw text with shadow for better visibility
shadow_offset = 4
# Shadow
draw.text((title_x + shadow_offset, title_y + shadow_offset), title_text, fill='#000000', font=title_font)
draw.text((subtitle_x + shadow_offset, subtitle_y + shadow_offset), subtitle_text, fill='#000000', font=subtitle_font)

# Main text
draw.text((title_x, title_y), title_text, fill='#FFFFFF', font=title_font)
draw.text((subtitle_x, subtitle_y), subtitle_text, fill='#B0BEC5', font=subtitle_font)

# Save the image
output_path = r"C:\Users\chris\ChronoWorks\feature_graphic_1024x500.png"
img.save(output_path, "PNG", optimize=True)

print(f"\nSuccessfully created feature graphic!")
print(f"  Location: {output_path}")
print(f"  Size: 1024x500 pixels")
print(f"\nYou can now upload this to Google Play Console:")
print("  1. Go to Store listing → Feature graphic")
print("  2. Upload feature_graphic_1024x500.png")
