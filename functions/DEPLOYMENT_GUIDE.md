# ChronoWorks Cloud Functions - Deployment Guide

This guide provides step-by-step instructions for deploying the automated missed clock-out warning system.

## Prerequisites

1. **Firebase CLI installed**
   ```bash
   npm install -g firebase-tools
   ```

2. **SendGrid Account**
   - Sign up at https://sendgrid.com/
   - Create an API key with "Mail Send" permissions
   - Verify a sender email address in SendGrid

3. **Firebase Project**
   - Have admin access to the ChronoWorks Firebase project

## Installation Steps

### Step 1: Install Dependencies

Navigate to the functions directory and install new dependencies:

```bash
cd C:\Users\chris\ChronoWorks\functions
npm install
```

This will install the newly added `@sendgrid/mail` package along with all other dependencies.

### Step 2: Configure SendGrid Credentials

Set the SendGrid API key and from email address:

```bash
firebase functions:config:set sendgrid.api_key="YOUR_SENDGRID_API_KEY"
firebase functions:config:set sendgrid.from_email="noreply@yourdomain.com"
```

**Important Notes:**
- Replace `YOUR_SENDGRID_API_KEY` with your actual SendGrid API key
- Replace `noreply@yourdomain.com` with your verified sender email
- The sender email MUST be verified in SendGrid before emails can be sent

### Step 3: Verify Configuration

Check that all configurations are set correctly:

```bash
firebase functions:config:get
```

You should see output similar to:

```json
{
  "twilio": {
    "account_sid": "ACxxxxxxxxxxxxxxxxxxxxxxxxx",
    "auth_token": "xxxxxxxxxxxxxxxxxxxxxxxx",
    "phone_number": "+1234567890"
  },
  "sendgrid": {
    "api_key": "SG.xxxxxxxxxxxxxxxxxxxxxxxxx",
    "from_email": "noreply@yourdomain.com"
  }
}
```

### Step 4: Deploy Functions

Deploy all functions:

```bash
firebase deploy --only functions
```

Or deploy only the new missed clock-out function:

```bash
firebase deploy --only functions:checkMissedClockOuts
```

### Step 5: Verify Deployment

After deployment completes:

1. Check Firebase Console:
   - Go to https://console.firebase.google.com/
   - Navigate to your project
   - Click on "Functions" in the left sidebar
   - Verify `checkMissedClockOuts` appears in the list with status "Active"

2. Check the schedule:
   - The function should show "Scheduled" as the trigger type
   - Schedule: "every 15 minutes"

## Testing the Function

### Manual Testing via Firebase Console

1. Go to Firebase Console > Functions
2. Find `checkMissedClockOuts` in the list
3. Click on the function name
4. Go to the "Logs" tab
5. Wait for the next scheduled run (every 15 minutes)
6. Review logs to see if function executed successfully

### Testing with Test Data

To test the function, you can create a test scenario:

1. Have an employee clock in
2. Create a shift for that employee that ends in the past (more than 45 minutes ago)
3. Wait for the function to run (every 15 minutes)
4. Check if email alerts are sent

Example test scenario:
- Employee clocks in at 9:00 AM
- Shift scheduled: 9:00 AM - 5:00 PM
- Current time: 5:50 PM (50 minutes after shift end)
- Expected result: Email sent to employee, manager, and admins

### Viewing Logs

View real-time logs:

```bash
firebase functions:log --only checkMissedClockOuts
```

Or view all function logs:

```bash
firebase functions:log
```

## Configuration Options

### Adjusting the Grace Period

By default, the grace period is 45 minutes after shift end. To change this:

1. Edit `checkMissedClockOuts.js`
2. Find the line: `const graceMinutes = 45;`
3. Change `45` to your desired grace period in minutes
4. Redeploy the function

### Adjusting the Schedule

By default, the function runs every 15 minutes. To change this:

1. Edit `checkMissedClockOuts.js`
2. Find the line: `schedule: "every 15 minutes",`
3. Change to your desired schedule (e.g., "every 30 minutes", "every 1 hours")
4. Redeploy the function

**Note**: More frequent checks will consume more Cloud Function invocations and may increase costs.

### Changing Timezone

By default, the function uses "America/New_York" timezone. To change:

1. Edit `checkMissedClockOuts.js`
2. Find the line: `timeZone: "America/New_York",`
3. Change to your desired timezone (e.g., "America/Los_Angeles", "America/Chicago")
4. Redeploy the function

Valid timezone values: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones

## Firestore Requirements

The function requires these Firestore collections to be properly structured:

### `activeClockIns` Collection

Documents should contain:
- `userId` (string) - Employee user ID
- `clockInTime` (timestamp) - When employee clocked in
- `timeEntryId` (string) - Reference to time entry

### `shifts` Collection

Documents should contain:
- `employeeId` (string) - Employee user ID
- `startTime` (timestamp) - Shift start time
- `endTime` (timestamp) - Shift end time
- `isDayOff` (boolean) - Whether it's a day off

### `users` Collection

Documents should contain:
- `email` (string) - User email address
- `firstName` (string) - User first name
- `lastName` (string) - User last name
- `role` (string) - User role ('admin', 'manager', 'employee')
- `managerId` (string, optional) - Manager's user ID (for employees)
- `isActive` (boolean) - Whether user is active

### `missedClockOutWarnings` Collection

This collection is created automatically by the function. Documents contain:
- `userId` (string) - Employee user ID
- `employeeName` (string) - Employee full name
- `date` (string) - Date in YYYY-MM-DD format
- `shiftEndTime` (timestamp) - When shift was scheduled to end
- `clockInTime` (timestamp) - When employee clocked in
- `warningSentAt` (timestamp) - When warning was sent
- `minutesOverdue` (number) - Minutes overdue when warning sent

## Monitoring and Maintenance

### Regular Monitoring Tasks

1. **Check function logs weekly** for any errors or issues
   ```bash
   firebase functions:log --only checkMissedClockOuts
   ```

2. **Monitor SendGrid usage** to ensure you're within quota limits

3. **Review `missedClockOutWarnings` collection** to track patterns of missed clock-outs

4. **Test email delivery** periodically to ensure SendGrid is working

### Cost Considerations

- Each function invocation counts toward Firebase Cloud Functions free tier (2M invocations/month)
- Running every 15 minutes = 96 invocations/day = ~2,880 invocations/month
- Additional invocations occur when processing active clock-ins
- SendGrid free tier: 100 emails/day

### Scaling Considerations

If you have a large number of employees:
- Consider increasing the check interval (e.g., every 30 minutes instead of 15)
- Monitor function execution time (timeout is 60 seconds by default)
- Consider batching email sends if sending to many recipients

## Troubleshooting

### Function Not Running

**Symptom**: No logs appearing in Firebase Console

**Solution**:
1. Verify function is deployed: `firebase deploy --only functions:checkMissedClockOuts`
2. Check Firebase Console > Functions for any deployment errors
3. Verify Cloud Scheduler is enabled in Google Cloud Console

### Emails Not Being Sent

**Symptom**: Function runs but no emails are received

**Solutions**:
1. Check SendGrid API key is correct:
   ```bash
   firebase functions:config:get sendgrid
   ```

2. Verify sender email is verified in SendGrid dashboard

3. Check function logs for SendGrid errors:
   ```bash
   firebase functions:log --only checkMissedClockOuts
   ```

4. Verify recipient email addresses are valid in Firestore `users` collection

5. Check spam/junk folders for test emails

### Duplicate Warnings

**Symptom**: Same employee receives multiple warnings on the same day

**Solutions**:
1. Check `missedClockOutWarnings` collection for duplicate entries
2. Verify date comparison logic is working correctly
3. Review function logs for any errors during warning recording

### No Warnings for Overdue Clock-Outs

**Symptom**: Employee is overdue but no warning sent

**Solutions**:
1. Verify employee has a shift scheduled in `shifts` collection
2. Check shift end time is correct and in the past
3. Verify employee is in `activeClockIns` collection
4. Check grace period calculation (45 minutes default)
5. Review function logs for any query errors

## Rollback Procedure

If you need to rollback the deployment:

1. Find the previous version number:
   ```bash
   firebase functions:list
   ```

2. Rollback to previous version via Firebase Console:
   - Go to Functions > checkMissedClockOuts
   - Click "..." menu
   - Select "Rollback to previous version"

Or remove the function entirely:
```bash
firebase functions:delete checkMissedClockOuts
```

## Support and Maintenance

For issues or questions:
1. Check function logs first
2. Review this deployment guide
3. Check Firebase documentation: https://firebase.google.com/docs/functions
4. Check SendGrid documentation: https://docs.sendgrid.com/

## Summary

You now have an automated system that:
- ✅ Runs every 15 minutes to check for missed clock-outs
- ✅ Identifies employees who haven't clocked out 45 minutes after their shift ends
- ✅ Sends professional email alerts to employees, managers, and admins
- ✅ Prevents duplicate warnings by tracking sent alerts
- ✅ Provides detailed logging for monitoring and troubleshooting

The system will help ensure timely clock-outs and maintain accurate time tracking records.
