# Proactive Overtime Prediction & Prevention System

## Overview

This system monitors actual time worked versus scheduled time and predicts potential overtime based on employee behavior patterns (early clock-ins, late clock-outs, missed breaks). It provides automated warnings and actionable remediation strategies to prevent overtime violations.

## Key Features

1. **Real-Time Monitoring**: Tracks actual vs scheduled hours continuously
2. **Behavior Analysis**: Detects early clock-ins, late clock-outs, and short breaks
3. **Overtime Prediction**: Projects total weekly hours based on current patterns
4. **Intelligent Remediation**: Suggests specific actions to avoid overtime:
   - Clock in/out at scheduled times
   - Take full breaks
   - Shift swap recommendations with available employees
5. **Automated Notifications**: Email alerts to employees, managers, and admins
6. **Visual Warnings**: In-app UI components showing risk status

## System Components

### 1. Flutter App Components

#### **ActualOvertimeService** (`lib/services/actual_overtime_service.dart`)
- Calculates actual hours worked from time entries
- Projects remaining hours for the week
- Analyzes behavior violations
- Generates remediation strategies
- Finds shift swap candidates

#### **OvertimeRiskWarningCard** (`lib/widgets/overtime_risk_warning_card.dart`)
- Employee-facing UI component
- Shows risk level (Low, Medium, High, Critical)
- Displays hours breakdown
- Lists violations and remediation strategies
- Expandable card design

#### **Constants** (To be added to `lib/utils/constants.dart`)
```dart
class FirebaseCollections {
  static const String timeEntries = 'timeEntries';
  static const String activeClockIns = 'activeClockIns';
  static const String shifts = 'shifts';
  static const String users = 'users';
  static const String breakEntries = 'breakEntries';
  static const String overtimeRiskNotifications = 'overtimeRiskNotifications';
}
```

### 2. Firebase Cloud Functions

#### **monitorOvertimeRisk** (`functions/monitorOvertimeRisk.js`)
- **Schedule**: Runs every 2 hours during business hours
- **Purpose**: Checks all employees for overtime risk
- **Actions**: Sends email notifications if risk level is medium or higher
- **Duplicate Prevention**: Only one notification per employee per day

#### **checkOvertimeOnClockEvent** (`functions/monitorOvertimeRisk.js`)
- **Trigger**: Fires when employee clocks in or out
- **Purpose**: Immediate risk assessment
- **Actions**: Sends instant notification for high/critical risk

## Deployment Instructions

### Step 1: Add Flutter Widget to Employee Dashboard

Edit your employee dashboard/home screen to include the warning card:

```dart
import '../widgets/overtime_risk_warning_card.dart';

// In your build method:
Column(
  children: [
    // Existing dashboard widgets

    // Add overtime warning card
    OvertimeRiskWarningCard(
      employeeId: currentUser.uid,
    ),

    // Rest of dashboard
  ],
)
```

### Step 2: Configure Firebase Functions

1. **Navigate to functions directory**:
   ```bash
   cd C:\Users\chris\ChronoWorks\functions
   ```

2. **Configure SendGrid** (if not already done):
   ```bash
   firebase functions:config:set sendgrid.api_key="YOUR_SENDGRID_API_KEY"
   firebase functions:config:set sendgrid.from_email="noreply@chronoworks.com"
   ```

3. **Deploy the functions**:
   ```bash
   firebase deploy --only functions:monitorOvertimeRisk,functions:checkOvertimeOnClockEvent
   ```

### Step 3: Verify Deployment

1. **Check function logs**:
   ```bash
   firebase functions:log --limit 20
   ```

2. **Test manually** (optional):
   - Clock in an employee
   - Check if `checkOvertimeOnClockEvent` triggers
   - Wait 2 hours for `monitorOvertimeRisk` to run

3. **Verify email delivery**:
   - Check SendGrid dashboard for sent emails
   - Verify email recipients receive notifications

## Configuration Options

### Thresholds (in `actual_overtime_service.dart`)

```dart
static const double overtimeThreshold = 40.0;  // Hours per week
static const int earlyClockInThresholdMinutes = 10;  // Minutes
static const int lateClockOutThresholdMinutes = 10;  // Minutes
static const int fullBreakMinutes = 30;  // Expected break duration
```

### Cloud Function Schedule

Edit in `functions/monitorOvertimeRisk.js`:

```javascript
.pubsub.schedule('0 */2 * * *') // Every 2 hours
```

Common schedules:
- Every hour: `'0 * * * *'`
- Every 4 hours: `'0 */4 * * *'`
- Business hours only: `'0 8-17 * * 1-5'` (8am-5pm, Mon-Fri)

## How It Works

### Scenario 1: Employee Clocking In Early

1. **Employee**: Clocks in 15 minutes early (scheduled 9:00 AM, clocks in 8:45 AM)
2. **System**: Detects early clock-in violation
3. **Analysis**: Calculates this adds 0.25 hours to weekly total
4. **Projection**: If employee continues pattern, projects potential overtime
5. **Warning**: Shows warning card with "Clock on time" strategy
6. **Notification**: If high risk, emails employee, manager, and admins

### Scenario 2: Employee Missing Breaks

1. **Employee**: Works 8-hour shift with only 10-minute break (30 minutes expected)
2. **System**: Detects short break violation (20 minutes short)
3. **Analysis**: Adds 0.33 hours to weekly total
4. **Projection**: Projects total weekly hours
5. **Warning**: Shows "Take full breaks" strategy
6. **Notification**: If approaching overtime, sends email

### Scenario 3: Shift Swap Recommendation

1. **Employee A**: Projected to hit 42 hours (2 hours overtime)
2. **Employee B**: Only scheduled for 32 hours this week
3. **System**: Identifies Employee A has remaining shift on Friday (8 hours)
4. **Analysis**: Employee B could take Friday shift and stay under 40 hours
5. **Warning**: Suggests shift swap between Employee A and Employee B
6. **Notification**: Includes swap suggestion in email to both managers

## Email Notification Format

**Subject**: ⚠️ Overtime Risk Alert: [Employee Name] - [RISK LEVEL] Risk

**Content**:
- Risk level summary (Medium, High, Critical)
- Hours breakdown (actual, projected, overtime)
- List of violations (early clock-ins, late clock-outs, short breaks)
- Prioritized remediation strategies
- Action items for employee, manager, and admin

## Firestore Collections

### New Collection: `overtimeRiskNotifications`

**Purpose**: Track which employees have been notified to prevent duplicate emails

**Schema**:
```javascript
{
  employeeId: string,
  date: timestamp (midnight of notification day),
  sentAt: timestamp (actual time notification sent)
}
```

**Indexes Required**: None (queries use simple where clause)

## Cost Analysis

### Firebase Functions
- **monitorOvertimeRisk**: ~2,920 invocations/month (every 2 hours)
- **checkOvertimeOnClockEvent**: Varies by clock-in frequency (~4,000/month for 50 employees)
- **Cost**: Free tier covers up to 2M invocations/month

### SendGrid
- **Emails**: ~60-90 emails/month (assuming 10-15 at-risk employees/week)
- **Cost**: Free tier covers 100 emails/day

### Firestore
- **Reads**: ~50,000/month (checking shifts, time entries, users)
- **Writes**: ~1,000/month (notification records)
- **Cost**: Free tier covers 50,000 reads + 20,000 writes/day

**Total Monthly Cost**: $0 (fits within free tiers)

## Monitoring & Maintenance

### Check Function Health

```bash
# View recent logs
firebase functions:log --limit 50

# Filter for errors
firebase functions:log --only monitorOvertimeRisk

# Check specific employee
firebase functions:log | grep "employeeId"
```

### Query Notifications

```javascript
// In Firebase Console > Firestore
db.collection('overtimeRiskNotifications')
  .where('date', '>=', startOfWeek)
  .get()
```

### Adjust Thresholds

If getting too many/few warnings, adjust in:
- `actual_overtime_service.dart`: Flutter-side calculations
- `monitorOvertimeRisk.js`: Server-side calculations (keep in sync!)

## Troubleshooting

### Issue: No Warnings Showing

**Check**:
1. Employee has shifts scheduled this week
2. Employee has clocked in/out recently
3. Projected hours > 35 (minimum for medium risk)
4. Widget is added to employee screen

### Issue: No Emails Sent

**Check**:
1. SendGrid API key configured: `firebase functions:config:get`
2. Functions deployed: `firebase functions:list`
3. Check SendGrid dashboard for blocked/bounced emails
4. Verify email addresses in user records

### Issue: Duplicate Emails

**Check**:
1. `overtimeRiskNotifications` collection exists
2. Notifications are being recorded after sending
3. Check for multiple function deployments

### Issue: Wrong Hour Calculations

**Check**:
1. Break entries are being recorded correctly
2. Time zone settings match (America/New_York default)
3. Week boundaries are Sunday-Saturday
4. Shifts have correct start/end times

## Future Enhancements

1. **Admin Dashboard Widget**: Summary of all at-risk employees
2. **SMS Notifications**: For critical overtime risks
3. **Shift Swap Approval Workflow**: Automated shift exchange system
4. **Historical Analytics**: Track overtime trends over time
5. **Predictive ML Model**: Learn from past patterns to improve predictions
6. **Mobile Push Notifications**: Real-time alerts on mobile devices

## Support

For issues or questions:
1. Check Firebase Functions logs
2. Verify SendGrid email delivery
3. Test with a single employee first
4. Review Firestore security rules for access

---

**Version**: 1.0
**Last Updated**: 2025-01-27
**Author**: ChronoWorks Development Team
