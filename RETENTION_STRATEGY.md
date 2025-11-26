# Customer Retention Strategy - Phase 3B

## Overview
Comprehensive customer retention system that identifies at-risk accounts, escalates critical cases to account managers, and tracks all retention efforts.

## Risk Detection Triggers

### 1. **Free Account Expiration** (Already Built)
- **Day 57**: Warning email sent to customer ✓
- **Day 60**: Critical - Account manager task created
- **Priority**: HIGH
- **Action**: Personal outreach call required

### 2. **Trial Expiration** (Already Built)
- **Day 27**: Warning email sent to customer ✓
- **Day 29**: Critical - Account manager task created
- **Priority**: HIGH
- **Action**: Personal outreach call to convert to paid

### 3. **Payment Failures** (New - Phase 5)
- **First failure**: Automated email + retry
- **Second failure (48 hours)**: Account manager task created
- **Priority**: CRITICAL
- **Action**: Call to update payment method

### 4. **Inactivity Detection** (New)
- **14 days no login**: Warning email
- **21 days no login**: Account manager task created
- **Priority**: MEDIUM
- **Action**: Check-in call to re-engage

### 5. **Low Usage** (New)
- **< 3 clock-ins per week for 2 weeks**: Warning email
- **No clock-ins for 21 days**: Account manager task
- **Priority**: MEDIUM
- **Action**: Training/support offer call

### 6. **Cancellation Requests** (New - Phase 4)
- **Immediate**: Account manager task created
- **Priority**: URGENT
- **Action**: Save call with retention offer

## Escalation Workflow

```
┌─────────────────────┐
│  Risk Detected      │
│  (Automated)        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Customer Email     │
│  (Friendly Reminder)│
└──────────┬──────────┘
           │
        48 hours
           │
           ▼
┌─────────────────────┐
│  Still At-Risk?     │
└──────────┬──────────┘
           │ YES
           ▼
┌─────────────────────┐
│  Create Retention   │
│  Task for Manager   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Manager Notified   │
│  (Email + In-App)   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Manager Makes Call │
│  (Logs Outcome)     │
└──────────┬──────────┘
           │
    ┌──────┴──────┐
    │             │
    ▼             ▼
┌────────┐   ┌────────┐
│ SAVED  │   │  LOST  │
└────────┘   └────────┘
```

## Data Model

### retentionTasks Collection

```javascript
{
  id: "auto-generated",
  companyId: "company123",
  companyName: "Acme Corp",

  // Contact Info (denormalized for quick access)
  ownerName: "John Smith",
  ownerEmail: "john@acme.com",
  ownerPhone: "(555) 123-4567",

  // Risk Details
  riskType: "free_expiring", // free_expiring, trial_expiring, payment_failed, inactive, low_usage, cancellation
  riskLevel: "critical", // warning, high, critical, urgent
  riskReason: "Free account expires in 3 days",
  expirationDate: Timestamp,

  // Current Plan Info
  currentPlan: "free",
  planValue: 0, // monthly value in dollars

  // Task Management
  status: "pending", // pending, assigned, contacted, follow_up, resolved, lost
  priority: 1, // 1-5 (1 = most urgent)
  assignedTo: "userId123", // account manager
  assignedToName: "Sarah Johnson",
  dueDate: Timestamp,

  // Tracking
  contactAttempts: 0,
  lastContactedAt: Timestamp,
  notes: [
    {
      userId: "userId123",
      userName: "Sarah Johnson",
      timestamp: Timestamp,
      note: "Left voicemail, will try again tomorrow",
      callDuration: 0 // seconds, 0 if no answer
    }
  ],

  // Outcomes
  outcome: null, // saved, lost, converted_to_paid, upgraded, extended_trial
  resolvedAt: Timestamp,
  resolvedBy: "userId123",
  resolutionNotes: "Customer agreed to upgrade to Silver plan",

  // Metadata
  createdAt: Timestamp,
  updatedAt: Timestamp,

  // Analytics
  customerLifetimeValue: 0,
  daysAsCustomer: 30,
  previousPlans: ["trial", "free"]
}
```

### managerNotifications Collection

```javascript
{
  id: "auto-generated",
  managerId: "userId123",
  managerEmail: "sarah@chronoworks.com",

  notificationType: "new_retention_task", // new_retention_task, task_overdue, urgent_task
  taskId: "taskId123",
  companyName: "Acme Corp",

  priority: 1,
  read: false,
  actionTaken: false,

  createdAt: Timestamp
}
```

## Account Manager Dashboard

### Overview Section
```
┌─────────────────────────────────────────────────────────────┐
│  Customer Retention Dashboard                               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   URGENT    │  │    TODAY    │  │  OVERDUE    │        │
│  │     5       │  │     12      │  │     2       │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  SAVE RATE  │  │  AVG VALUE  │  │   AT RISK   │        │
│  │    78%      │  │   $249/mo   │  │    $2,988   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Task List
```
┌─────────────────────────────────────────────────────────────┐
│  📞 Retention Tasks                    [Filters ▼] [Sort ▼] │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  🔴 URGENT - Acme Corp                            Due: Today │
│     Trial expires tomorrow • $199/mo potential               │
│     Owner: John Smith • (555) 123-4567                       │
│     [Call Now]  [View Details]  [Add Note]                   │
│                                                              │
│  ─────────────────────────────────────────────────────────  │
│                                                              │
│  🟠 HIGH - TechStart Inc                   Due: Tomorrow     │
│     Free account expires in 3 days • $99/mo potential        │
│     Owner: Jane Doe • (555) 987-6543                         │
│     [Call Now]  [View Details]  [Add Note]                   │
│                                                              │
│  ─────────────────────────────────────────────────────────  │
│                                                              │
│  🟡 MEDIUM - BuildCo LLC                   Due: Oct 15       │
│     No activity for 14 days • $149/mo Silver plan            │
│     Owner: Bob Builder • (555) 456-7890                      │
│     [Call Now]  [View Details]  [Add Note]                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Contact Customer Modal
```
┌─────────────────────────────────────────────────────────────┐
│  Contact Customer - Acme Corp                          [✕]  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Contact Information:                                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Name:  John Smith                                     │  │
│  │ Email: john@acme.com        [Copy] [Email]           │  │
│  │ Phone: (555) 123-4567       [Copy] [Call]            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  Account Details:                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Current Plan:    Trial                                │  │
│  │ Days Active:     27 days                              │  │
│  │ Expires:         Tomorrow (Oct 13, 2025)              │  │
│  │ Risk Reason:     Trial expiring without conversion    │  │
│  │ Suggested Plan:  Silver ($149/mo)                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  Call Outcome:                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ ◯ Customer Answered                                   │  │
│  │ ◯ Left Voicemail                                      │  │
│  │ ◯ No Answer                                           │  │
│  │ ◯ Wrong Number                                        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  Result: (if answered)                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ ◯ Account Saved - Customer will upgrade              │  │
│  │ ◯ Need Follow-Up - Send pricing info                 │  │
│  │ ◯ Lost - Customer decided to cancel                  │  │
│  │ ◯ Extended Trial - Gave 7 more days                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  Notes:                                                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                                                        │  │
│  │ (Enter call notes, objections, follow-up needed...)   │  │
│  │                                                        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  Call Duration: [___] minutes                                │
│                                                              │
│  [Cancel]                            [Save & Close Task]     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Email Templates for Account Managers

### 1. New Urgent Task Alert
```
Subject: 🔴 URGENT: Retention Task - [Company Name] expires in [X] days

Hi [Manager Name],

A high-priority retention task has been assigned to you:

Company: [Company Name]
Contact: [Owner Name] - [Phone]
Risk: [Risk Description]
Plan Value: $[Amount]/month
Expires: [Date] - [Days] away

This customer needs immediate attention. Please contact them today.

View Task: [Dashboard Link]

Quick Actions:
• Call: [Phone Number]
• Email: [Email Address]
• View Account: [Account Link]

Best regards,
ChronoWorks Retention System
```

### 2. Daily Task Summary
```
Subject: 📊 Your Retention Tasks for [Date]

Hi [Manager Name],

Here's your retention dashboard for today:

URGENT (Call Today):
• [Company 1] - Trial expires tomorrow - $199/mo
• [Company 2] - Payment failed twice - $149/mo

HIGH PRIORITY (Call This Week):
• [Company 3] - Free expires in 3 days - $99/mo
• [Company 4] - 21 days inactive - $249/mo

FOLLOW-UPS DUE:
• [Company 5] - Promised to decide by today

OVERDUE:
• [Company 6] - Task created 3 days ago

Total At-Risk Value: $2,988/month

View Dashboard: [Link]

Your save rate this month: 78% (above target!)

Best regards,
ChronoWorks Retention System
```

### 3. Task Overdue Alert
```
Subject: ⚠️ Overdue Retention Task - [Company Name]

Hi [Manager Name],

The following retention task is now overdue:

Company: [Company Name]
Contact: [Owner Name] - [Phone]
Created: [Date] ([Days] days ago)
Risk: [Risk Description]

This customer is at risk of being lost. Please contact them as soon as possible.

View Task: [Dashboard Link]

Best regards,
ChronoWorks Retention System
```

## Backend Implementation

### Cloud Functions

#### 1. detectAtRiskAccounts (Scheduled - Daily 9 AM)
```javascript
// Runs alongside existing checkTrialExpirations and checkFreeAccountExpirations
// Creates retention tasks when accounts reach critical stage
```

#### 2. notifyAccountManagers (Scheduled - Daily 8 AM & 2 PM)
```javascript
// Sends daily digest to account managers
// Sends immediate alerts for urgent tasks
```

#### 3. updateRetentionTask (HTTP)
```javascript
// Called when manager logs contact attempt
// Updates task status and notes
```

#### 4. getRetentionDashboard (HTTP)
```javascript
// Returns aggregated retention metrics
// Returns filtered/sorted task list
```

## Integration Points

### 1. With Existing Trial Management (Phase 3)
- When Day 27 trial warning sent → Check 48 hours later, create task if still not converted
- When Day 57 free warning sent → Create task immediately (high priority)

### 2. With Payment System (Phase 5)
- Payment failure → Create task after second failure
- Cancellation request → Create task immediately (urgent)

### 3. With User Analytics (Future)
- Low login frequency → Create task after threshold
- Low usage → Create task after threshold

## Metrics & Reporting

### Key Metrics
- **Save Rate**: % of at-risk accounts that were retained
- **Average Time to Contact**: Hours from task creation to first contact
- **Conversion Rate**: % of trial/free accounts that convert to paid
- **Revenue Saved**: Monthly recurring revenue retained
- **Manager Performance**: Save rate by account manager

### Dashboard Charts
1. **Save Rate Trend** (Line chart - last 30 days)
2. **At-Risk Value** (Bar chart - by risk type)
3. **Task Pipeline** (Funnel - pending → contacted → resolved)
4. **Manager Leaderboard** (Table - sorted by save rate)

## Phase 3B Implementation Plan

### Step 1: Data Model & Backend (1-2 days)
- [ ] Create retentionTasks collection schema
- [ ] Create managerNotifications collection schema
- [ ] Build detectAtRiskAccounts function
- [ ] Build notifyAccountManagers function
- [ ] Build updateRetentionTask API
- [ ] Build getRetentionDashboard API

### Step 2: Email Templates (1 day)
- [ ] Manager urgent task alert email
- [ ] Manager daily digest email
- [ ] Manager overdue task alert email

### Step 3: Frontend Dashboard (2-3 days)
- [ ] Account Manager Dashboard page
- [ ] Retention metrics widgets
- [ ] Task list with filters/sorting
- [ ] Contact customer modal
- [ ] Call notes interface
- [ ] Task resolution flow

### Step 4: Integration (1 day)
- [ ] Integrate with existing trial management functions
- [ ] Add task creation after warning emails
- [ ] Add manager role/permissions

### Step 5: Testing (1 day)
- [ ] Create test at-risk accounts
- [ ] Verify task creation
- [ ] Test manager notifications
- [ ] Test dashboard functionality
- [ ] Test call logging workflow

## Success Criteria

✅ Automatic task creation for at-risk accounts
✅ Account managers receive timely notifications
✅ Managers can easily contact customers from dashboard
✅ All contact attempts are logged with notes
✅ Clear resolution tracking (saved/lost)
✅ Metrics show retention improvement

## Future Enhancements

- **AI-Powered Insights**: Predict churn risk score based on usage patterns
- **Automated Retention Offers**: System suggests personalized discounts
- **SMS Integration**: Send text reminders to customers
- **Call Recording**: Integrate with VoIP for call recording
- **Customer Health Score**: Overall account health indicator
- **Win-Back Campaigns**: Automated re-engagement for lost customers
