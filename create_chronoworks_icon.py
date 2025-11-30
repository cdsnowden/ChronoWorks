#!/usr/bin/env python3
"""
Create ChronoWorks app icon with cog/gear design (512x512)
"""

from PIL import Image, ImageDraw, ImageFont
import math

# Create a 512x512 image
size = 512
img = Image.new('RGBA', (size, size), color=(0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Background gradient circle
center_x, center_y = size // 2, size // 2
radius = size // 2 - 20

# Draw background circle with gradient effect
for r in range(radius, 0, -1):
    # Blue gradient
    alpha = int(255 * (r / radius))
    color_r = int(26 + (63 - 26) * (1 - r / radius))
    color_g = int(35 + (81 - 35) * (1 - r / radius))
    color_b = int(126 + (181 - 126) * (1 - r / radius))
    draw.ellipse([center_x - r, center_y - r, center_x + r, center_y + r],
                 fill=(color_r, color_g, color_b, alpha))

# Draw cog/gear
def draw_gear(draw, center_x, center_y, inner_radius, outer_radius, teeth):
    """Draw a gear with specified parameters"""
    points = []
    angle_step = 2 * math.pi / (teeth * 2)

    for i in range(teeth * 2):
        angle = i * angle_step
        if i % 2 == 0:
            # Outer point (tooth)
            r = outer_radius
        else:
            # Inner point (gap)
            r = inner_radius

        x = center_x + r * math.cos(angle)
        y = center_y + r * math.sin(angle)
        points.append((x, y))

    # Draw gear shape
    draw.polygon(points, fill='#FFFFFF', outline='#FFFFFF')

    # Draw center hole
    hole_radius = inner_radius * 0.4
    draw.ellipse([center_x - hole_radius, center_y - hole_radius,
                  center_x + hole_radius, center_y + hole_radius],
                 fill=(color_r, color_g, color_b), outline='#FFFFFF', width=3)

# Draw main gear
draw_gear(draw, center_x, center_y,
          inner_radius=radius * 0.5,
          outer_radius=radius * 0.7,
          teeth=12)

# Draw clock hands overlay
hand_color = '#FFA726'  # Orange color
hand_width = 8

# Hour hand (short, pointing to ~10 o'clock)
hour_angle = math.radians(-60)  # -60 degrees from vertical
hour_length = radius * 0.4
hour_end_x = center_x + hour_length * math.sin(hour_angle)
hour_end_y = center_y - hour_length * math.cos(hour_angle)
draw.line([(center_x, center_y), (hour_end_x, hour_end_y)],
          fill=hand_color, width=hand_width)

# Minute hand (long, pointing to ~2 o'clock)
minute_angle = math.radians(60)  # 60 degrees from vertical
minute_length = radius * 0.55
minute_end_x = center_x + minute_length * math.sin(minute_angle)
minute_end_y = center_y - minute_length * math.cos(minute_angle)
draw.line([(center_x, center_y), (minute_end_x, minute_end_y)],
          fill=hand_color, width=hand_width)

# Draw center dot for clock hands
center_dot_radius = 12
draw.ellipse([center_x - center_dot_radius, center_y - center_dot_radius,
              center_x + center_dot_radius, center_y + center_dot_radius],
             fill=hand_color, outline='#FFFFFF', width=2)

# Save the image
output_path = r"C:\Users\chris\ChronoWorks\chronoworks_app_icon_512.png"
img.save(output_path, "PNG")

print("Successfully created ChronoWorks app icon!")
print(f"Location: {output_path}")
print(f"Size: 512x512 pixels")
print("Features: Cog/gear with clock hands representing time tracking")
