# Missed Clock-Out Warning System - Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                   ChronoWorks Cloud Functions                   │
│                     Automated Alert System                       │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐      Every 15 Minutes      ┌─────────────────┐
│  Cloud Scheduler │ ────────────────────────────> │ checkMissed     │
│   (Firebase)     │                              │ ClockOuts.js    │
└──────────────────┘                              └────────┬────────┘
                                                           │
                                                           │ Queries
                                                           ▼
                        ┌────────────────────────────────────────────┐
                        │         Firestore Collections              │
                        ├────────────────────────────────────────────┤
                        │  1. activeClockIns    (Read)              │
                        │  2. users             (Read)              │
                        │  3. shifts            (Read)              │
                        │  4. missedClockOutWarnings (Read/Write)   │
                        └────────────────────────────────────────────┘
                                           │
                                           │ Process & Check
                                           ▼
                        ┌────────────────────────────────┐
                        │   Business Logic Processing    │
                        ├────────────────────────────────┤
                        │  • Check shift end + 45 min    │
                        │  • Verify no duplicate warning │
                        │  • Get employee/manager/admins │
                        │  • Format email content        │
                        └────────────┬───────────────────┘
                                     │
                                     │ Send Emails
                                     ▼
                        ┌────────────────────────────────┐
                        │      SendGrid API              │
                        ├────────────────────────────────┤
                        │  • HTML email template         │
                        │  • Multiple recipients         │
                        │  • Delivery tracking           │
                        └────────────┬───────────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                ▼                ▼
            ┌──────────┐      ┌──────────┐    ┌──────────┐
            │ Employee │      │ Manager  │    │  Admins  │
            │  Email   │      │  Email   │    │  Emails  │
            └──────────┘      └──────────┘    └──────────┘
```

## Data Flow

### 1. Trigger Phase (Every 15 minutes)
```
Cloud Scheduler
    └─> Invokes checkMissedClockOuts function
```

### 2. Query Phase
```
Function queries:
    ├─> activeClockIns collection
    │       └─> Get all currently clocked-in employees
    │
    ├─> For each active clock-in:
    │   ├─> Query users collection (get employee details)
    │   ├─> Query shifts collection (get today's shift)
    │   └─> Query missedClockOutWarnings (check if already warned)
    │
    └─> Filter results based on business rules
```

### 3. Processing Phase
```
For each overdue employee:
    ├─> Calculate time overdue
    ├─> Check if > 45 minutes past shift end
    ├─> Verify warning not already sent today
    │
    ├─> Gather recipient emails:
    │   ├─> Employee email
    │   ├─> Manager email (if managerId exists)
    │   └─> All admin emails (role = 'admin', isActive = true)
    │
    └─> Format email content with employee details
```

### 4. Notification Phase
```
Send emails via SendGrid:
    ├─> Professional HTML template
    ├─> Plain text fallback
    └─> Sent to all recipients simultaneously
```

### 5. Recording Phase
```
Record warning in Firestore:
    └─> Add document to missedClockOutWarnings
        ├─> userId
        ├─> employeeName
        ├─> date (YYYY-MM-DD)
        ├─> shiftEndTime
        ├─> clockInTime
        ├─> warningSentAt
        └─> minutesOverdue
```

## Business Rules

### Alert Triggering Conditions

```javascript
Alert is triggered when ALL conditions are met:

1. Employee is in activeClockIns collection
2. Employee has shift scheduled for today
3. Current time > (Shift end time + 45 minutes)
4. No warning sent for this employee today
5. Employee has email address
```

### Grace Period Calculation

```
Shift End Time: 5:00 PM
Grace Period:   + 45 minutes
Alert Time:     5:45 PM
                ↓
Function checks at: 5:45 PM, 6:00 PM, 6:15 PM, etc.
First check after 5:45 PM will trigger alert
```

### Duplicate Prevention

```
Check Pattern:
    Query: missedClockOutWarnings
    Where: userId == employee.id
           AND date == today (YYYY-MM-DD)

    If exists:  Skip (already warned)
    If not:     Send warning + record
```

## File Structure

```
functions/
├── index.js                              # Main exports
├── checkMissedClockOuts.js              # Alert system function
├── package.json                          # Dependencies (with @sendgrid/mail)
├── README.md                             # Full documentation
├── DEPLOYMENT_GUIDE.md                   # Deployment instructions
├── MISSED_CLOCKOUT_ALERTS_QUICKSTART.md # Quick reference
└── SYSTEM_ARCHITECTURE.md               # This file
```

## Key Functions in checkMissedClockOuts.js

### Helper Functions

```javascript
getAdminEmails()
    └─> Returns: Array of {email, name} for all admins

getManagerEmail(managerId)
    └─> Returns: {email, name} for specific manager

getTodayShift(employeeId)
    └─> Returns: {id, startTime, endTime} for today's shift

hasWarningBeenSent(userId, date)
    └─> Returns: boolean (true if already warned)

recordWarningSent(userId, employeeName, shiftEndTime, clockInTime, currentTime)
    └─> Creates document in missedClockOutWarnings

formatTime(date)
    └─> Returns: "5:30 PM" formatted string

formatDuration(minutes)
    └─> Returns: "2 hours and 30 minutes" formatted string

sendMissedClockOutEmail(recipients, employeeName, shiftTime, clockInTime, duration)
    └─> Sends emails via SendGrid
    └─> Returns: {success, count} or {success: false, error}
```

### Main Function

```javascript
exports.checkMissedClockOuts = onSchedule(
    {
        schedule: "every 15 minutes",
        timeZone: "America/New_York",
        region: "us-central1"
    },
    async (event) => {
        // Main processing logic
    }
)
```

## Firestore Schema

### activeClockIns Collection

```javascript
{
    // Document ID: userId
    userId: "abc123",
    timeEntryId: "entry456",
    clockInTime: Timestamp
}
```

### shifts Collection

```javascript
{
    // Document ID: auto-generated
    id: "shift789",
    employeeId: "abc123",
    startTime: Timestamp,
    endTime: Timestamp,
    isDayOff: false,
    isPublished: true,
    // ... other fields
}
```

### users Collection

```javascript
{
    // Document ID: userId
    email: "employee@example.com",
    firstName: "John",
    lastName: "Doe",
    role: "employee",  // or "manager" or "admin"
    managerId: "manager123",  // Optional
    isActive: true,
    // ... other fields
}
```

### missedClockOutWarnings Collection (Created by Function)

```javascript
{
    // Document ID: auto-generated
    userId: "abc123",
    employeeName: "John Doe",
    date: "2025-10-27",  // YYYY-MM-DD format
    shiftEndTime: Timestamp,
    clockInTime: Timestamp,
    warningSentAt: Timestamp,
    minutesOverdue: 50
}
```

## Email Template Structure

### HTML Email Components

```html
<!DOCTYPE html>
<html>
  <head>
    <style>
      /* Professional styling */
      - Container with max-width
      - Header with brand colors
      - Content area with padding
      - Alert box with warning colors
      - Info table with employee details
      - CTA button for action
      - Footer with disclaimer
    </style>
  </head>
  <body>
    <div class="container">
      <div class="header">⚠️ Missed Clock-Out Alert</div>
      <div class="content">
        <div class="alert-box">Action Required message</div>
        <h2>Employee Details</h2>
        <table class="info-table">
          <!-- Employee Name -->
          <!-- Scheduled Shift -->
          <!-- Clock In Time -->
          <!-- Time Clocked In -->
        </table>
        <ul>Action items list</ul>
        <a href="..." class="cta-button">Open ChronoWorks</a>
      </div>
      <div class="footer">Automated alert disclaimer</div>
    </div>
  </body>
</html>
```

## Configuration Options

### Environment Variables

```bash
# Required for function to work
SENDGRID_API_KEY=SG.xxxxxxxxxxxxx
SENDGRID_FROM_EMAIL=noreply@yourdomain.com

# Set via Firebase CLI:
firebase functions:config:set sendgrid.api_key="..."
firebase functions:config:set sendgrid.from_email="..."
```

### Customizable Parameters

| Parameter | Location | Default | Description |
|-----------|----------|---------|-------------|
| Grace Period | Line ~305 | 45 minutes | Time after shift end before alert |
| Check Frequency | Line ~310 | Every 15 minutes | How often to check |
| Timezone | Line ~311 | America/New_York | Timezone for scheduling |
| Region | Line ~312 | us-central1 | Firebase region |

## Performance Metrics

### Function Invocations

```
Base invocations:  96/day (every 15 minutes)
Monthly base:      ~2,880/month
Per employee:      +1 additional invocation per check
Per warning:       +5-10 additional operations (queries + writes)
```

### Execution Time

```
Typical execution:     2-5 seconds
With 10 employees:     5-10 seconds
With 50 employees:     15-30 seconds
Timeout limit:         60 seconds (default)
```

### Email Quota

```
SendGrid Free Tier:    100 emails/day
Per warning:           1-3 emails (employee + manager + admins)
Example:               5 missed clock-outs = 15 emails
```

## Error Handling

### Function-Level

```javascript
try {
    // Main processing
} catch (error) {
    logger.error("Error in checkMissedClockOuts:", error);
    throw error;  // Re-throw for Cloud Functions retry
}
```

### Per-Employee Level

```javascript
for (const activeDoc of activeClockInsSnapshot.docs) {
    try {
        // Process this employee
    } catch (error) {
        logger.error(`Error processing ${activeDoc.id}:`, error);
        continue;  // Skip to next employee
    }
}
```

### Email Sending

```javascript
if (!sendgridApiKey) {
    logger.error("SendGrid API key not configured");
    return {success: false, error: "API key missing"};
}

try {
    await sgMail.send(messages);
    return {success: true, count: messages.length};
} catch (error) {
    logger.error("Error sending email:", error);
    return {success: false, error: error.message};
}
```

## Logging Strategy

### Log Levels

```javascript
logger.info()   // Normal operations
    - "Starting missed clock-out check..."
    - "Found 5 active clock-ins to check"
    - "Warning sent to John Doe"

logger.warn()   // Potential issues
    - "No shift found for employee"
    - "No recipients found for email"
    - "User not found in database"

logger.error()  // Actual errors
    - "Error fetching admin emails"
    - "Failed to send email: [reason]"
    - "Error in checkMissedClockOuts"
```

### Log Viewing

```bash
# Real-time logs
firebase functions:log --only checkMissedClockOuts

# Last 100 entries
firebase functions:log --only checkMissedClockOuts --limit 100

# All functions
firebase functions:log
```

## Security Considerations

### API Key Protection

```
✅ Stored in Firebase Functions config (encrypted)
✅ Not committed to version control
✅ Not exposed in logs
✅ Not accessible from client-side code
```

### Email Address Privacy

```
✅ SendGrid batches hide recipient lists
✅ Each recipient only sees their own email
✅ BCC not used (cleaner for recipients)
```

### Data Access

```
✅ Function runs with admin privileges
✅ Queries only necessary collections
✅ Reads employee data for legitimate purpose
✅ Creates audit trail in missedClockOutWarnings
```

## Monitoring Dashboard (Recommended)

### Key Metrics to Track

1. **Function Executions**: How often function runs
2. **Warnings Sent**: Number of alerts per day/week
3. **Email Delivery Rate**: Success rate of SendGrid
4. **Top Offenders**: Employees with most warnings
5. **Pattern Analysis**: Time of day with most missed clock-outs

### Where to Monitor

```
Firebase Console:
    Functions > checkMissedClockOuts > Logs & Usage

SendGrid Dashboard:
    Activity Feed > Recent Deliveries

Firestore Console:
    missedClockOutWarnings collection > Document count
```

## Future Enhancements (Optional)

### Possible Improvements

1. **Escalation**: Second alert after additional time
2. **SMS Integration**: Add SMS for critical cases
3. **Auto Clock-Out**: Automatically clock out after X hours
4. **Dashboard Widget**: Show missed clock-outs on admin dashboard
5. **Report Generation**: Weekly summary of missed clock-outs
6. **Machine Learning**: Predict employees likely to forget
7. **Custom Messages**: Personalized email content per employee
8. **Multi-language**: Support for different languages

## Summary

The automated missed clock-out warning system provides:

✅ **Reliability**: Runs every 15 minutes automatically
✅ **Accuracy**: Checks against actual shift schedules
✅ **Efficiency**: Prevents duplicate warnings
✅ **Communication**: Multi-recipient email notifications
✅ **Tracking**: Full audit trail in Firestore
✅ **Scalability**: Handles multiple employees efficiently
✅ **Maintainability**: Well-documented and logged
✅ **Security**: Protected API keys and secure data access

This architecture ensures ChronoWorks maintains accurate time tracking and helps prevent payroll discrepancies.
