# Google Play Store Submission Checklist

## Overview
This checklist will guide you through submitting ChronoWorks to the Google Play Store for internal testing and eventual production release.

---

## Phase 1: Pre-Submission (COMPLETED ✓)

### Build & Technical
- [x] App built with release signing
- [x] Package name changed from com.example to com.chronoworks.timetracker
- [x] AAB file created (45.7 MB)
- [x] Firebase configuration updated for new package name
- [x] Code pushed to GitHub repository

### Files Location
- **AAB:** `C:\Users\chris\ChronoWorks\flutter_app\build\app\outputs\bundle\release\app-release.aab`
- **Documentation:** `C:\Users\chris\ChronoWorks\`

---

## Phase 2: Store Listing Preparation (IN PROGRESS)

### Required Assets

#### App Icon (512x512 PNG)
- [ ] Export app icon at 512x512 pixels
- [ ] Format: 32-bit PNG with alpha channel
- [ ] No rounded corners (Google Play adds them)
- [ ] File size under 1MB

**Current Status:** Need to export from Flutter assets

#### Feature Graphic (1024x500 JPG/PNG)
- [ ] Create feature graphic banner
- [ ] Dimensions: 1024 x 500 pixels
- [ ] Can include app name and tagline
- [ ] Recommended: ChronoWorks logo + "Time Tracking Simplified"

**Current Status:** Need to create

#### Screenshots (MINIMUM 2 REQUIRED)
- [ ] Screenshot 1: Clock In/Out screen
- [ ] Screenshot 2: Dashboard / Who's Working
- [ ] Screenshot 3: Weekly Schedule (recommended)
- [ ] Screenshot 4: Time Entries List (recommended)
- [ ] Screenshot 5: Payroll Export (recommended)
- [ ] Screenshot 6: Employee Profile (recommended)
- [ ] Screenshot 7: PTO Management (optional)
- [ ] Screenshot 8: Employee Schedule View (optional)

**Current Status:** See `SCREENSHOT_GUIDE.md` for instructions

**Dimensions:** 1080 x 1920 pixels (recommended)
**Format:** PNG or JPG

---

### Store Listing Text

#### App Name
- [ ] Choose app name (max 50 characters)

**Recommendation:** "ChronoWorks - Employee Time Tracker" (38 chars)

**Alternative Options:**
- ChronoWorks: Time & Attendance
- ChronoWorks Time Tracking
- ChronoWorks - Time Clock & Payroll

#### Short Description (80 characters max)
- [ ] Write short description

**Recommendation (76 chars):**
"Employee time tracking, scheduling, and payroll management for small businesses"

**See `STORE_COPY.md` for more options**

#### Full Description (4000 characters max)
- [ ] Copy full description from `GOOGLE_PLAY_LISTING.md`

**Current Status:** Ready to copy/paste

#### Promotional Text (80 characters) - Optional
- [ ] Add promotional text

**Recommendation:**
"Track time, manage schedules, and simplify payroll - all in one app!"

---

### App Categorization

- [ ] **Primary Category:** Business
- [ ] **Secondary Category:** Productivity (optional)
- [ ] **Tags:** time tracking, employee scheduling, payroll, workforce management

---

### Contact Details

- [ ] **Developer Name:** ChronoWorks (or your business name)
- [ ] **Email:** support@chronoworks.com (or your support email)
- [ ] **Website:** (optional - can add later)
- [ ] **Phone:** (optional - recommended for business apps)
- [ ] **Physical Address:** (optional - required for certain categories)

---

### Legal & Privacy

#### Privacy Policy (REQUIRED)
- [x] Privacy policy document created (`PRIVACY_POLICY.html`)
- [ ] Upload privacy policy to web host
- [ ] Get public URL for privacy policy
- [ ] Enter privacy policy URL in Google Play Console

**Options for hosting:**
1. Your own website (if you have one)
2. Firebase Hosting (free, easy to set up)
3. GitHub Pages (free)
4. Google Sites (free, no coding needed)

**Temporary Solution:** You can use a public Google Doc as temporary privacy policy URL

#### Data Safety Section (REQUIRED)
- [ ] Complete Data Safety questionnaire in Google Play Console

**Key Points to Enter:**
- **Data Collected:** Email, name, location (GPS), photos (optional)
- **Data Usage:** Time tracking, location verification, payroll
- **Data Sharing:** No data shared with third parties
- **Security:** Encrypted in transit and at rest

**See `GOOGLE_PLAY_LISTING.md` for detailed answers**

#### Content Rating (REQUIRED)
- [ ] Complete content rating questionnaire

**Expected Rating:** Everyone

**Answers:**
- Violence: No
- Sexual Content: No
- Profanity: No
- Drugs/Alcohol: No
- Gambling: No
- Location Sharing: Yes (for employee clock-in verification)

---

## Phase 3: Google Play Console Setup

### Create App (if not already created)

1. [ ] Go to https://play.google.com/console
2. [ ] Click "Create app"
3. [ ] Fill in:
   - **App name:** ChronoWorks - Employee Time Tracker
   - **Default language:** English (United States)
   - **App or game:** App
   - **Free or paid:** Free
4. [ ] Accept declarations and click "Create app"

---

### Complete Main Store Listing

**Location:** Store presence → Main store listing

#### Text
- [ ] App name
- [ ] Short description
- [ ] Full description

#### Graphics
- [ ] App icon (512x512)
- [ ] Feature graphic (1024x500)
- [ ] Phone screenshots (minimum 2, recommended 8)
- [ ] Tablet screenshots (optional but recommended)

#### Categorization
- [ ] App category: Business
- [ ] Store listing contact details (email)

#### Save Changes
- [ ] Click "Save" at bottom of page

---

### Set Up Internal Testing Track

**Location:** Release → Testing → Internal testing

1. [ ] Click "Create new release"
2. [ ] Upload AAB file
   - Click "Upload" button
   - Navigate to: `C:\Users\chris\ChronoWorks\flutter_app\build\app\outputs\bundle\release\app-release.aab`
   - Or drag and drop the file
3. [ ] Enter release name (e.g., "1.0.0" or "Initial Release")
4. [ ] Add release notes:
   ```
   Initial release of ChronoWorks employee time tracking app.

   Features:
   • Mobile time clock with GPS verification
   • Employee scheduling
   • Payroll export with overtime calculations
   • PTO tracking and approvals
   • Real-time dashboard
   ```
5. [ ] Click "Save"
6. [ ] Review release
7. [ ] Click "Start rollout to Internal testing"

---

### Create Tester List

**Location:** Release → Testing → Internal testing → Testers tab

1. [ ] Click "Create email list"
2. [ ] Enter list name: "Initial Testers"
3. [ ] Add email addresses (minimum 1, can be your own):
   - your.email@example.com
   - (add more if you have them)
4. [ ] Click "Save changes"

**Note:** Testers will receive an email with a link to opt-in to testing

---

### Complete App Content Declarations

**Location:** Policy → App content

#### Privacy Policy
- [ ] Enter privacy policy URL
- [ ] Click "Save"

#### Ads
- [ ] Select "No, my app does not contain ads"
- [ ] Click "Save"

#### Content Ratings
- [ ] Click "Start questionnaire"
- [ ] Select appropriate category: "Business/Productivity"
- [ ] Answer all questions (see recommendations in Section 2)
- [ ] Submit for rating
- [ ] Wait for rating (usually instant)

#### Target Audience
- [ ] Select target age groups: "18 and over"
- [ ] Click "Save"

#### News App (Declaration)
- [ ] Select "No, my app is not a news app"
- [ ] Click "Save"

#### COVID-19 Contact Tracing/Status Apps
- [ ] Select "No"
- [ ] Click "Save"

#### Data Safety
- [ ] Click "Start" to begin data safety form
- [ ] Follow prompts and answer questions about data collection
- [ ] Use answers from `GOOGLE_PLAY_LISTING.md`
- [ ] Submit

#### Government Apps
- [ ] Select "No, my app is not a government app"
- [ ] Click "Save"

---

### Set Up Countries/Regions

**Location:** Production → Countries/regions

- [ ] Select countries where app will be available
- [ ] Recommendation: Start with "United States"
- [ ] Can expand to more countries later
- [ ] Click "Save"

---

## Phase 4: Review & Submit

### Pre-Launch Checklist

- [ ] All store listing content complete (green checkmarks in dashboard)
- [ ] Privacy policy URL entered and accessible
- [ ] Content rating received
- [ ] Data safety form completed
- [ ] At least 2 screenshots uploaded
- [ ] AAB uploaded to Internal testing track
- [ ] Tester list created with at least 1 email

### Submit for Review

1. [ ] Go to Release → Testing → Internal testing
2. [ ] Verify everything looks correct
3. [ ] Click "Review release"
4. [ ] Click "Start rollout to Internal testing"

**Review Time:** Usually 1-24 hours for internal testing

---

## Phase 5: Testing Period

### After Approval

- [ ] Testers receive email invitation
- [ ] Testers must opt-in via link in email
- [ ] Testers can download app from Play Store
- [ ] Monitor for crashes and feedback
- [ ] Fix any critical bugs

### Getting Feedback

**Create feedback channel:**
- [ ] Set up support email (support@chronoworks.com)
- [ ] Share Google Form for feedback
- [ ] Monitor Firebase Crashlytics for crashes
- [ ] Check Google Play Console for crash reports

### Duration

**Recommendation:** Test for 1-2 weeks minimum before production release

---

## Phase 6: Production Release (After Testing)

### Pre-Production Checklist

- [ ] All critical bugs fixed
- [ ] App tested on multiple devices
- [ ] Positive feedback from testers
- [ ] All store listing materials finalized
- [ ] Updated screenshots (if needed based on feedback)
- [ ] Marketing materials prepared (optional)

### Create Production Release

1. [ ] Go to Release → Production → Production
2. [ ] Click "Create new release"
3. [ ] Select countries for rollout
4. [ ] Choose rollout strategy:
   - **Staged rollout** (recommended): Start with 20%, gradually increase
   - **Full rollout**: Release to 100% immediately
5. [ ] Add release notes for public
6. [ ] Click "Review release"
7. [ ] Click "Start rollout to Production"

**Review Time:** 1-7 days (usually 1-3 days)

---

## Phase 7: Post-Launch

### Monitoring

- [ ] Monitor reviews daily
- [ ] Respond to user reviews within 24-48 hours
- [ ] Track daily active users (DAU)
- [ ] Monitor crash reports
- [ ] Check Google Play Console analytics

### User Engagement

- [ ] Reply to user reviews (use templates in `STORE_COPY.md`)
- [ ] Address bug reports promptly
- [ ] Thank users for positive reviews
- [ ] Collect feature requests for future updates

### Updates

- [ ] Plan feature roadmap based on feedback
- [ ] Release bug fix updates quickly (within days)
- [ ] Plan major feature updates (v1.1, v1.2, etc.)
- [ ] Keep store listing updated with new screenshots

---

## Quick Reference

### Important URLs

- **Google Play Console:** https://play.google.com/console
- **Privacy Policy:** [Your URL after hosting]
- **Support Email:** support@chronoworks.com
- **GitHub Repository:** https://github.com/cdsnowden/ChronoWorks.git

### Important Files

| File | Location | Purpose |
|------|----------|---------|
| AAB | `build/app/outputs/bundle/release/app-release.aab` | Upload to Play Store |
| Keystore | `android/app/upload-keystore.jks` | App signing (DO NOT LOSE) |
| Privacy Policy | `PRIVACY_POLICY.html` | Required legal document |
| Store Listing | `GOOGLE_PLAY_LISTING.md` | Copy for descriptions |
| Store Copy | `STORE_COPY.md` | Alternative copy options |
| Screenshot Guide | `SCREENSHOT_GUIDE.md` | How to create screenshots |

### Support Resources

- **Google Play Console Help:** https://support.google.com/googleplay/android-developer
- **App Review Guidelines:** https://play.google.com/about/developer-content-policy/
- **Data Safety Help:** https://support.google.com/googleplay/android-developer/answer/10787469

---

## Common Issues & Solutions

### Issue: "App not yet available in your country"
**Solution:** Check Production → Countries/regions and ensure country is selected

### Issue: "This app is incompatible with your device"
**Solution:** Check `minSdk` version in build.gradle - may be too high for old devices

### Issue: "Upload failed" when uploading AAB
**Solution:**
1. Check file size (must be under 150MB)
2. Verify AAB is signed with release keystore
3. Try uploading from different browser
4. Clear browser cache

### Issue: Privacy policy link not working
**Solution:**
1. Verify URL is public and accessible
2. Use HTTPS (not HTTP)
3. Test in incognito/private browser window

### Issue: Review taking longer than expected
**Solution:**
1. Check for emails from Google Play team
2. Review may be manual if flagged
3. Contact Google Play support if over 7 days

---

## Next Steps After This Checklist

1. ✅ **Phase 1-2:** Prepare all assets and copy (screenshots, icon, descriptions)
2. 📤 **Phase 3:** Complete Google Play Console setup
3. 🚀 **Phase 4:** Submit for internal testing
4. 🧪 **Phase 5:** Test with real users
5. 🌎 **Phase 6:** Release to production
6. 📊 **Phase 7:** Monitor and iterate

---

## Need Help?

If you get stuck at any point:
1. Check Google Play Console Help Center
2. Review the documentation files in this folder
3. Contact Google Play Developer Support
4. Ask me for clarification or assistance

**Good luck with your launch! 🚀**

---

**Last Updated:** November 26, 2025
**App Version:** 1.0.0
**Package Name:** com.chronoworks.timetracker
