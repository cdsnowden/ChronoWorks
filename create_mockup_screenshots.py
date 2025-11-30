#!/usr/bin/env python3
"""
Create mockup screenshots for Google Play Store (1080x1920 - phone portrait)
"""

from PIL import Image, ImageDraw, ImageFont

def create_screenshot_1():
    """Clock In/Out screen mockup"""
    width, height = 1080, 1920
    img = Image.new('RGB', (width, height), color='#F5F5F5')
    draw = ImageDraw.Draw(img)

    # Try to load fonts
    try:
        title_font = ImageFont.truetype("arialbd.ttf", 80)
        header_font = ImageFont.truetype("arialbd.ttf", 60)
        button_font = ImageFont.truetype("arialbd.ttf", 70)
        text_font = ImageFont.truetype("arial.ttf", 50)
        small_font = ImageFont.truetype("arial.ttf", 40)
    except:
        title_font = header_font = button_font = text_font = small_font = ImageFont.load_default()

    # Top bar
    draw.rectangle([0, 0, width, 150], fill='#1a237e')
    draw.text((width//2, 75), "ChronoWorks", fill='#FFFFFF', font=header_font, anchor="mm")

    # Welcome message
    draw.text((width//2, 300), "Welcome, John Smith", fill='#333333', font=title_font, anchor="mm")
    draw.text((width//2, 400), "Employee", fill='#666666', font=text_font, anchor="mm")

    # Time display
    draw.text((width//2, 600), "10:24 AM", fill='#1a237e', font=title_font, anchor="mm")
    draw.text((width//2, 700), "Tuesday, March 15, 2024", fill='#666666', font=text_font, anchor="mm")

    # Clock In button (large, centered)
    button_y = 950
    button_height = 200
    button_width = 700
    button_x = (width - button_width) // 2

    # Button shadow
    draw.rounded_rectangle([button_x+10, button_y+10, button_x+button_width+10, button_y+button_height+10],
                          radius=30, fill='#CCCCCC')
    # Button
    draw.rounded_rectangle([button_x, button_y, button_x+button_width, button_y+button_height],
                          radius=30, fill='#4CAF50')
    draw.text((width//2, button_y + button_height//2), "CLOCK IN",
             fill='#FFFFFF', font=button_font, anchor="mm")

    # Status text
    draw.text((width//2, 1250), "Status: Not Clocked In", fill='#999999', font=text_font, anchor="mm")
    draw.text((width//2, 1350), "Location: GPS Ready", fill='#999999', font=small_font, anchor="mm")

    # Bottom info
    draw.text((width//2, 1750), "Scheduled: 8:00 AM - 4:00 PM", fill='#666666', font=small_font, anchor="mm")

    return img

def create_screenshot_2():
    """Dashboard screen mockup"""
    width, height = 1080, 1920
    img = Image.new('RGB', (width, height), color='#F5F5F5')
    draw = ImageDraw.Draw(img)

    # Try to load fonts
    try:
        header_font = ImageFont.truetype("arialbd.ttf", 60)
        title_font = ImageFont.truetype("arialbd.ttf", 50)
        text_font = ImageFont.truetype("arial.ttf", 45)
        small_font = ImageFont.truetype("arial.ttf", 38)
    except:
        header_font = title_font = text_font = small_font = ImageFont.load_default()

    # Top bar
    draw.rectangle([0, 0, width, 150], fill='#1a237e')
    draw.text((width//2, 75), "Dashboard", fill='#FFFFFF', font=header_font, anchor="mm")

    # Who's Working Now section
    y_pos = 200
    draw.text((80, y_pos), "Who's Working Now", fill='#333333', font=title_font)

    y_pos += 100
    # Employee cards
    employees = [
        ("John Smith", "8:00 AM - Now (2h 24m)"),
        ("Jane Doe", "9:00 AM - Now (1h 24m)"),
        ("Mike Johnson", "7:30 AM - Now (2h 54m)")
    ]

    for name, time in employees:
        # Card background
        draw.rounded_rectangle([60, y_pos, width-60, y_pos+150], radius=15, fill='#FFFFFF')
        # Green status indicator
        draw.ellipse([90, y_pos+60, 130, y_pos+100], fill='#4CAF50')
        # Employee info
        draw.text((160, y_pos+50), name, fill='#333333', font=text_font)
        draw.text((160, y_pos+105), time, fill='#666666', font=small_font)
        y_pos += 180

    # Schedule section
    y_pos += 50
    draw.text((80, y_pos), "Today's Schedule", fill='#333333', font=title_font)

    y_pos += 100
    # Schedule card
    draw.rounded_rectangle([60, y_pos, width-60, y_pos+150], radius=15, fill='#FFFFFF')
    draw.text((90, y_pos+40), "Morning Shift", fill='#333333', font=text_font)
    draw.text((90, y_pos+95), "5 employees • 7:00 AM - 3:00 PM", fill='#666666', font=small_font)

    y_pos += 180
    draw.rounded_rectangle([60, y_pos, width-60, y_pos+150], radius=15, fill='#FFFFFF')
    draw.text((90, y_pos+40), "Evening Shift", fill='#333333', font=text_font)
    draw.text((90, y_pos+95), "3 employees • 3:00 PM - 11:00 PM", fill='#666666', font=small_font)

    # Bottom stats
    y_pos = 1650
    draw.rectangle([0, y_pos, width, y_pos+270], fill='#FFFFFF')

    stats_y = y_pos + 50
    draw.text((width//2, stats_y), "Today's Stats", fill='#333333', font=title_font, anchor="mm")

    stats_y += 80
    # Three columns of stats
    col_width = width // 3
    draw.text((col_width//2, stats_y), "8", fill='#1a237e', font=header_font, anchor="mm")
    draw.text((col_width//2, stats_y+70), "Clocked In", fill='#666666', font=small_font, anchor="mm")

    draw.text((width//2, stats_y), "156", fill='#1a237e', font=header_font, anchor="mm")
    draw.text((width//2, stats_y+70), "Total Hours", fill='#666666', font=small_font, anchor="mm")

    draw.text((width - col_width//2, stats_y), "2", fill='#1a237e', font=header_font, anchor="mm")
    draw.text((width - col_width//2, stats_y+70), "Late", fill='#666666', font=small_font, anchor="mm")

    return img

# Create both screenshots
print("Creating mockup screenshots...")

screenshot1 = create_screenshot_1()
screenshot1.save(r"C:\Users\chris\ChronoWorks\screenshot_1_clock_in.png", "PNG")
print("Created: screenshot_1_clock_in.png (Clock In screen)")

screenshot2 = create_screenshot_2()
screenshot2.save(r"C:\Users\chris\ChronoWorks\screenshot_2_dashboard.png", "PNG")
print("Created: screenshot_2_dashboard.png (Dashboard)")

print("\nSuccessfully created 2 mockup screenshots!")
print("Size: 1080x1920 pixels (portrait)")
print("You can now upload these to Google Play Console")
