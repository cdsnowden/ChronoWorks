# ChronoWorks Cloud Functions

This directory contains Firebase Cloud Functions for ChronoWorks, including SMS notifications for overtime alerts and automated email alerts for missed clock-outs.

## Setup Instructions

### 1. Install Dependencies

```bash
cd functions
npm install
```

### 2. Configure Twilio Credentials

You need a Twilio account to send SMS. Sign up at https://www.twilio.com/

Once you have your credentials, set them using Firebase Functions config:

```bash
firebase functions:config:set twilio.account_sid="YOUR_ACCOUNT_SID"
firebase functions:config:set twilio.auth_token="YOUR_AUTH_TOKEN"
firebase functions:config:set twilio.phone_number="+1234567890"
```

**Important**: The phone number must be in E.164 format (+1234567890)

### 2b. Configure SendGrid for Email Alerts

You need a SendGrid account to send email alerts. Sign up at https://sendgrid.com/

Once you have your API key, set it using Firebase Functions config:

```bash
firebase functions:config:set sendgrid.api_key="YOUR_SENDGRID_API_KEY"
firebase functions:config:set sendgrid.from_email="noreply@yourdomain.com"
```

For local development, add to `.env` file:

```
SENDGRID_API_KEY=your_sendgrid_api_key
SENDGRID_FROM_EMAIL=noreply@yourdomain.com
```

### 3. Deploy Functions

```bash
firebase deploy --only functions
```

Or deploy specific functions:

```bash
firebase deploy --only functions:notifyAdminsOfOvertime
firebase deploy --only functions:checkMissedClockOuts
```

## Functions

### `notifyAdminsOfOvertime`

**Trigger**: Firestore document created in `overtimeRequests` collection

**Purpose**: Sends SMS notifications to all admin users when a manager creates an overtime shift.

**SMS Message Format**:
```
ChronoWorks Overtime Alert!

Employee: John Doe
Manager: Jane Smith
Overtime: 2.5 hrs
Weekly Total: 42.5 hrs

Approval required in ChronoWorks app.
```

**How it works**:
1. Triggers when new document created in `overtimeRequests/{requestId}`
2. Queries all users with role='admin' who have phone numbers
3. Sends SMS to each admin using Twilio
4. Updates the overtime request document with notification status

### `checkMissedClockOuts`

**Trigger**: Scheduled (every 15 minutes)

**Purpose**: Automatically monitors employees who are still clocked in 45 minutes after their shift ends and sends email alerts to the employee, their manager, and all admins.

**Email Recipients**:
- Employee (if email available)
- Employee's manager (if assigned and email available)
- All admin users with email addresses

**How it works**:
1. Runs every 15 minutes on a schedule
2. Queries all documents in `activeClockIns` collection
3. For each active clock-in:
   - Fetches the employee's shift for today from `shifts` collection
   - Checks if current time > (shift end time + 45 minutes)
   - If yes, checks `missedClockOutWarnings` collection to see if warning already sent today
   - If no warning sent, sends emails via SendGrid to employee, manager, and admins
   - Records warning in `missedClockOutWarnings` collection with timestamp
4. Prevents duplicate warnings by tracking sent alerts per user per day

**Email includes**:
- Employee name
- Scheduled shift time
- Clock in time
- Current duration clocked in
- Call to action to clock out immediately

**Grace Period**: 45 minutes after shift end time before warning is sent

## Testing Locally

You can test functions locally using the Firebase emulator:

```bash
npm run serve
```

Then trigger the function by creating a test overtime request in Firestore.

## Viewing Logs

View function logs in real-time:

```bash
npm run logs
```

Or view logs in Firebase Console:
https://console.firebase.google.com/project/YOUR_PROJECT/functions/logs

## Environment Variables

For local development, you can create a `.env` file:

```
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1234567890
SENDGRID_API_KEY=your_sendgrid_api_key
SENDGRID_FROM_EMAIL=noreply@yourdomain.com
```

## Admin User Requirements

For admins to receive SMS notifications, they must have:
1. `role` field set to `"admin"` in Firestore `users` collection
2. `phoneNumber` field populated with valid phone number

Phone numbers must be in E.164 format:
- US: +1234567890
- UK: +441234567890
- etc.

## Troubleshooting

### "Twilio credentials not configured" error
- Make sure you've set all three Twilio config values
- Run `firebase functions:config:get` to verify

### SMS not sending
- Check Twilio account balance
- Verify phone numbers are in E.164 format
- Check function logs for errors: `firebase functions:log`

### No admins receiving notifications
- Verify admin users have `phoneNumber` field in Firestore
- Check that phone numbers are non-empty strings
- Verify users have `role="admin"`

### "SendGrid API key not configured" error
- Make sure you've set the SendGrid API key
- Run `firebase functions:config:get` to verify
- For local testing, check your `.env` file

### Emails not sending
- Verify SendGrid account is active and has sending quota
- Check that the from email is verified in SendGrid
- Verify recipient email addresses are valid
- Check function logs for detailed error messages: `firebase functions:log`

### No missed clock-out warnings being sent
- Verify employees have email addresses in their user profiles
- Check that shifts are properly created in the `shifts` collection with correct dates
- Ensure the scheduled function is deployed: `firebase deploy --only functions:checkMissedClockOuts`
- Check function logs to see if the function is running: `firebase functions:log --only checkMissedClockOuts`
- Verify timezone setting in the function matches your business timezone

## Firestore Collections Used

### For `notifyAdminsOfOvertime`:
- `overtimeRequests` - Triggers the function
- `users` - Queries admin users with phone numbers

### For `checkMissedClockOuts`:
- `activeClockIns` - Queries all currently clocked-in employees
- `shifts` - Fetches employee shift schedules
- `users` - Fetches employee, manager, and admin information
- `missedClockOutWarnings` - Tracks sent warnings to prevent duplicates
