# Quick Screenshot Guide - ChronoWorks

## ✅ App Icon Created!

**Location:** `C:\Users\chris\ChronoWorks\play_store_icon_512x512.png`
**Size:** 512x512 pixels
**Ready to upload to Google Play Console!**

---

## 📱 How to Take Screenshots (Choose One Method)

### Method 1: Install APK on Your Phone (RECOMMENDED - 20 minutes)

#### Step 1: Install the App
1. **Transfer APK to your phone:**
   - APK Location: `C:\Users\chris\ChronoWorks\flutter_app\build\app\outputs\flutter-apk\app-release.apk`
   - Options to transfer:
     - Email it to yourself
     - Upload to Google Drive and download on phone
     - Connect phone via USB and copy file
     - Use ADB: `adb install app-release.apk`

2. **Install on phone:**
   - Tap the APK file
   - Allow "Install from unknown sources" if prompted
   - Install ChronoWorks

#### Step 2: Set Up Demo Data
Log in as admin and create sample data:

**Demo Employees:**
- John Smith (Manager, $25/hour)
- Jane Doe (Employee, $20/hour)
- Mike Johnson (Employee, $18/hour)
- Sarah Williams (Employee, $22/hour)

**Demo Schedule:**
- Create shifts for the current week
- Vary the times: 8am-4pm, 12pm-8pm, etc.
- Assign different employees to different days

**Demo Time Entries:**
- Have 2-3 employees "clocked in" currently
- Create some historical entries

#### Step 3: Take Screenshots (Priority Order)

**PRIORITY 1 (Required - 2 screenshots minimum):**

**Screenshot 1: Clock In/Out Screen**
- Log in as an employee
- Go to main clock-in screen
- Make sure it shows "Ready to Clock In" or clock-out button
- **Take screenshot:** Press Power + Volume Down simultaneously
- Save as: `01_clock_in_screen.png`

**Screenshot 2: Dashboard / Who's Working**
- Log in as admin/manager
- Go to main dashboard
- Ensure 2-3 employees show as "Working Now"
- **Take screenshot:** Press Power + Volume Down
- Save as: `02_dashboard_working_now.png`

---

**PRIORITY 2 (Recommended - adds 4 more screenshots):**

**Screenshot 3: Weekly Schedule**
- Go to Schedule screen
- Show full week with multiple shifts
- **Take screenshot**
- Save as: `03_weekly_schedule.png`

**Screenshot 4: Time Entries List**
- Go to Time Entries
- Show list of multiple entries
- **Take screenshot**
- Save as: `04_time_entries_list.png`

**Screenshot 5: Payroll Export**
- Go to Admin → Payroll Export
- Generate a report
- Show the summary and data table
- **Take screenshot**
- Save as: `05_payroll_export.png`

**Screenshot 6: Employee Profile**
- Go to Team → Select an employee
- Show their profile with details
- **Take screenshot**
- Save as: `06_employee_profile.png`

---

**PRIORITY 3 (Optional - nice to have):**

**Screenshot 7: PTO Request**
- Go to Time Off section
- Show PTO request form or list
- **Take screenshot**
- Save as: `07_pto_management.png`

**Screenshot 8: Employee Schedule View**
- Log in as employee
- View "My Schedule"
- **Take screenshot**
- Save as: `08_employee_schedule.png`

#### Step 4: Transfer Screenshots to Computer
- Connect phone via USB
- Copy screenshots from phone's Pictures/Screenshots folder
- Or email screenshots to yourself
- Save to: `C:\Users\chris\ChronoWorks\Screenshots\`

---

### Method 2: Use Android Emulator (SLOWER - 45 minutes)

1. **Open Android Studio**
2. **Create/Start Emulator:**
   - Tools → Device Manager
   - Create a Pixel 5 or similar device
   - Start the emulator
3. **Install APK:**
   - Drag and drop APK file onto emulator
   - Or use: `adb install app-release.apk`
4. **Take Screenshots:**
   - Click camera icon in emulator toolbar
   - Or use: `adb shell screencap -p /sdcard/screenshot.png`
5. **Pull screenshots:**
   - `adb pull /sdcard/screenshot.png`

---

### Method 3: Run in Chrome (FOR WEB VERSION ONLY)

**Note:** This will show the web version, not the mobile app. Only use if you need quick placeholder screenshots.

1. **Run web version:**
   ```bash
   cd C:\Users\chris\ChronoWorks\flutter_app
   flutter run -d chrome
   ```

2. **Resize browser window to phone size:**
   - F12 to open DevTools
   - Toggle device toolbar (Ctrl+Shift+M)
   - Select "Pixel 5" or similar
   - Set to 1080 x 1920 pixels

3. **Take screenshots:**
   - Use browser screenshot tool
   - Or use Snipping Tool (Win+Shift+S)

---

## 📏 Screenshot Requirements

After taking screenshots, make sure they meet these requirements:

**Dimensions:** 1080 x 1920 pixels (recommended)
- Minimum: 320px x 320px
- Maximum: 3840px x 3840px
- Aspect ratio: 9:16 (phone portrait)

**Format:** PNG or JPG
**File Size:** Under 8MB each
**Quantity:** Minimum 2, Recommended 8

---

## ✂️ Edit Screenshots (Optional but Recommended)

### Tools:
- **Paint 3D** (Windows built-in) - Basic cropping
- **Canva** (free online) - Add text, frames
- **Photoshop/GIMP** - Professional editing

### What to edit:
1. **Crop to exact 1080x1920** if needed
2. **Remove any real data** (blur real names, emails)
3. **Use sample data only** (John Smith, Jane Doe, etc.)

---

## 📤 Upload to Google Play Console

Once screenshots are ready:

1. Go to: https://play.google.com/console
2. Select ChronoWorks app
3. Go to: **Store presence → Main store listing**
4. Scroll to **"Phone screenshots"** section
5. Click **"Upload"** or drag and drop
6. Upload in priority order (1, 2, 3, 4, 5, 6, 7, 8)
7. Add captions for each (optional, see `STORE_COPY.md`)
8. Click **"Save"**

---

## 📋 Quick Checklist

- [x] Play Store icon created (512x512) ✓
- [ ] APK built (building now...)
- [ ] APK installed on phone
- [ ] Demo data created (employees, schedule, time entries)
- [ ] Screenshot 1: Clock In/Out (REQUIRED)
- [ ] Screenshot 2: Dashboard (REQUIRED)
- [ ] Screenshot 3: Schedule (recommended)
- [ ] Screenshot 4: Time Entries (recommended)
- [ ] Screenshot 5: Payroll (recommended)
- [ ] Screenshot 6: Employee Profile (recommended)
- [ ] Screenshot 7: PTO (optional)
- [ ] Screenshot 8: Employee Schedule (optional)
- [ ] Screenshots edited/cropped to 1080x1920
- [ ] Screenshots uploaded to Play Console

---

## 🎯 Minimum to Submit TODAY

If you want to submit to Play Store in the next hour, you only need:

1. ✓ Play Store icon (done!)
2. □ 2 screenshots (clock-in + dashboard)
3. □ Copy descriptions from `GOOGLE_PLAY_LISTING.md`
4. □ Host privacy policy somewhere

**That's it!** You can improve screenshots later.

---

## 💡 Pro Tips

1. **Use landscape/tablet screenshots** if you also want tablet users
2. **Add text overlays** to highlight features (use Canva)
3. **Show realistic data** but not real employee names
4. **Keep it simple** - don't overthink it
5. **You can update screenshots anytime** after submission

---

## ❓ Troubleshooting

### APK won't install on phone
- Enable "Install from unknown sources" in Settings
- Make sure you have enough storage space
- Try uninstalling any previous version

### Can't take screenshots
- Some phones use different key combinations
- Try Power + Home button
- Or use a screenshot app from Play Store

### Screenshots are wrong size
- Use an image editor to resize to 1080x1920
- Or use online tool: https://www.iloveimg.com/resize-image

---

**Need help?** See `SCREENSHOT_GUIDE.md` for more detailed instructions!

**APK Status:** Building now... Check in a few minutes at:
`C:\Users\chris\ChronoWorks\flutter_app\build\app\outputs\flutter-apk\app-release.apk`
