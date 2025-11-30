#!/usr/bin/env python3
"""
Create 512x512 app icon for Google Play Store
"""

from PIL import Image
import os

# Paths
input_icon = r"C:\Users\chris\ChronoWorks\flutter_app\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png"
output_icon = r"C:\Users\chris\ChronoWorks\play_store_icon_512x512.png"

try:
    # Open the largest available icon
    img = Image.open(input_icon)
    print(f"Original icon size: {img.size}")

    # Resize to 512x512 with high-quality resampling
    img_resized = img.resize((512, 512), Image.Resampling.LANCZOS)

    # Save as PNG with maximum quality
    img_resized.save(output_icon, "PNG", optimize=True)

    print(f"\n✓ Successfully created Play Store icon!")
    print(f"  Location: {output_icon}")
    print(f"  Size: 512x512 pixels")
    print(f"\nYou can now upload this icon to Google Play Console:")
    print("  1. Go to Store presence → Main store listing")
    print("  2. Scroll to 'App icon'")
    print("  3. Upload play_store_icon_512x512.png")

except FileNotFoundError:
    print("Error: Icon file not found!")
    print(f"Looking for: {input_icon}")
except Exception as e:
    print(f"Error: {e}")
