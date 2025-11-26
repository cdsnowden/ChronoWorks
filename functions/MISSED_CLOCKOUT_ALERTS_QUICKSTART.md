# Missed Clock-Out Alerts - Quick Start Guide

## Overview

ChronoWorks now includes an automated warning system that sends email alerts when employees fail to clock out 45 minutes after their shift ends.

## How It Works

1. **Automatic Monitoring**: System checks every 15 minutes for employees still clocked in
2. **Grace Period**: Alerts sent 45 minutes after scheduled shift end time
3. **Email Notifications**: Sent to employee, their manager, and all admins
4. **Duplicate Prevention**: Only one alert per employee per day

## Setup (One-Time)

### 1. Install Dependencies
```bash
cd functions
npm install
```

### 2. Configure SendGrid
```bash
firebase functions:config:set sendgrid.api_key="YOUR_API_KEY"
firebase functions:config:set sendgrid.from_email="noreply@yourdomain.com"
```

### 3. Deploy Function
```bash
firebase deploy --only functions:checkMissedClockOuts
```

## Email Alert Contains

- Employee name
- Scheduled shift time (start - end)
- Clock in time
- Total time clocked in
- Call to action button

## Who Receives Alerts

✅ **Employee** - Reminder to clock out
✅ **Manager** - Employee's direct manager (if assigned)
✅ **Admins** - All users with admin role

## Requirements

### For System to Work:
- Employee must have email address in profile
- Employee must have shift scheduled in `shifts` collection
- Employee must be in `activeClockIns` collection

### For Recipients to Get Emails:
- Users must have email addresses in Firestore
- Admins must have `role: "admin"` and `isActive: true`
- Managers must be assigned to employees via `managerId` field

## Monitoring

### View Function Logs
```bash
firebase functions:log --only checkMissedClockOuts
```

### Check Function Status
1. Go to Firebase Console
2. Navigate to Functions
3. Find `checkMissedClockOuts`
4. Should show "Active" status

## Configuration

All settings in `checkMissedClockOuts.js`:

- **Grace Period**: `const graceMinutes = 45;` (line ~305)
- **Check Frequency**: `schedule: "every 15 minutes"` (line ~310)
- **Timezone**: `timeZone: "America/New_York"` (line ~311)

After changing any setting, redeploy:
```bash
firebase deploy --only functions:checkMissedClockOuts
```

## Troubleshooting

### No emails being sent?
1. ✅ Check SendGrid API key: `firebase functions:config:get`
2. ✅ Verify sender email in SendGrid dashboard
3. ✅ Check function logs for errors
4. ✅ Verify user email addresses in Firestore

### Duplicate alerts?
- Check `missedClockOutWarnings` collection for multiple entries
- Review function logs for errors

### Function not running?
- Verify deployment: Look for function in Firebase Console
- Check Cloud Scheduler is enabled in Google Cloud Console

## Cost Estimates

**Firebase Cloud Functions:**
- ~96 invocations/day (every 15 minutes)
- ~2,880 invocations/month
- Well within free tier (2M/month)

**SendGrid:**
- Variable based on missed clock-outs
- Free tier: 100 emails/day
- Upgrade if needed: https://sendgrid.com/pricing/

## Testing

### Create Test Scenario:
1. Clock in an employee
2. Create/modify shift to end 50 minutes ago
3. Wait for next 15-minute interval
4. Check inbox for email alert

### Expected Timeline:
- Shift ends at 5:00 PM
- Grace period: 45 minutes
- Alert triggered at 5:45 PM
- Email sent within 15 minutes (next scheduled check)

## Data Storage

Alerts tracked in `missedClockOutWarnings` collection:

```
{
  userId: "employee_id",
  employeeName: "John Doe",
  date: "2025-10-27",
  shiftEndTime: Timestamp,
  clockInTime: Timestamp,
  warningSentAt: Timestamp,
  minutesOverdue: 50
}
```

## Email Template Preview

**Subject:** ChronoWorks Alert: Missed Clock-Out - [Employee Name]

**Content:**
- Alert header with warning icon
- Employee details table
- Action items list
- "Open ChronoWorks Dashboard" button
- Footer with system info

## Quick Commands

```bash
# Deploy function
firebase deploy --only functions:checkMissedClockOuts

# View logs
firebase functions:log --only checkMissedClockOuts

# Check config
firebase functions:config:get

# Delete function (if needed)
firebase functions:delete checkMissedClockOuts
```

## Support

For detailed information, see:
- `README.md` - Full function documentation
- `DEPLOYMENT_GUIDE.md` - Complete deployment instructions
- Firebase Console - Real-time logs and monitoring

## Summary

✅ **Automated**: Runs every 15 minutes automatically
✅ **Smart**: 45-minute grace period before alerting
✅ **Comprehensive**: Notifies employee, manager, and admins
✅ **Efficient**: Prevents duplicate alerts
✅ **Professional**: Well-designed HTML email template
✅ **Tracked**: Records all warnings in Firestore

The system helps ensure accurate time tracking and prevents payroll discrepancies from missed clock-outs.
