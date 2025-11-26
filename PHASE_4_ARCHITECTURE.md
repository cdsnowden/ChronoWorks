# Phase 4: Subscription Management Architecture

## Overview
Self-service subscription management allowing customers to upgrade, downgrade, and switch between billing cycles without contacting support.

## Key Features

### 1. Plan Comparison & Selection
- Side-by-side plan comparison
- Feature highlighting
- Price calculator (monthly vs yearly)
- Recommended plan badges
- Current plan indicator

### 2. Upgrade Flow
- **Immediate Activation**: Upgrades take effect instantly
- **Prorated Billing**: Credit unused time, charge for new plan
- **Feature Unlock**: All new features available immediately
- **Email Confirmation**: Receipt with new plan details

### 3. Downgrade Flow
- **Scheduled Change**: Takes effect at next billing cycle
- **Confirmation Required**: Warn about feature loss
- **Grace Period**: Can cancel downgrade before it takes effect
- **Data Preservation**: Keep data during downgrade period
- **Email Notification**: Confirmation of scheduled downgrade

### 4. Billing Cycle Switch
- Monthly ↔ Yearly switching
- Show savings with yearly billing
- Apply at next renewal
- Keep same feature set

## User Flows

### Upgrade Flow
```
Current Plan: Free ($0/mo)
    ↓
View Plans → Click "Upgrade to Silver"
    ↓
Review Change:
  • Current: Free Plan ($0/mo)
  • New: Silver Plan ($249/mo)
  • Billing: Monthly
  • Effective: Immediately
  • Next Charge: $249 on Dec 1, 2025
    ↓
[Confirm Upgrade] ← Requires payment if not on file
    ↓
✅ Success!
  • Silver features unlocked
  • Email receipt sent
  • Redirect to dashboard
```

### Downgrade Flow
```
Current Plan: Platinum ($499/mo)
    ↓
View Plans → Click "Downgrade to Silver"
    ↓
⚠️ Warning Screen:
  • Features you'll lose:
    - Custom integrations
    - Biometric clock-in
    - Team messaging
    - Compliance reports
  • Your data will be preserved
  • Change takes effect: Jan 1, 2026
  • Can cancel anytime before then
    ↓
[I Understand, Continue]
    ↓
Review Change:
  • Current: Platinum ($499/mo)
  • New: Silver ($249/mo)
  • Savings: $250/mo
  • Effective: Next billing cycle (Jan 1)
  • You keep Platinum until: Dec 31, 2025
    ↓
[Schedule Downgrade]
    ↓
✅ Scheduled!
  • Confirmation email sent
  • Calendar reminder added
  • Show banner: "Downgrade scheduled for Jan 1"
```

### Cancel Scheduled Downgrade
```
Dashboard Banner:
┌────────────────────────────────────────────────────┐
│ ⚠️ Downgrade to Silver scheduled for Jan 1, 2026  │
│                                      [Cancel] [×]  │
└────────────────────────────────────────────────────┘
    ↓ Click [Cancel]
    ↓
Confirm:
  • Keep Platinum Plan ($499/mo)?
  • Scheduled downgrade will be cancelled
    ↓
[Yes, Keep Platinum]
    ↓
✅ Downgrade Cancelled!
  • You'll continue on Platinum
  • No changes to billing
```

## Data Model Updates

### companies Collection
```javascript
{
  // Existing fields...
  currentPlan: "silver",
  billingCycle: "monthly", // or "yearly"

  // Scheduled changes
  scheduledPlanChange: {
    newPlan: "gold",
    newBillingCycle: "yearly",
    effectiveDate: Timestamp,
    scheduledAt: Timestamp,
    scheduledBy: "userId",
    reason: "upgrade" // or "downgrade"
  },

  // Billing
  nextBillingDate: Timestamp,
  lastBillingDate: Timestamp,
  billingStatus: "active", // active, past_due, cancelled

  // Payment
  hasPaymentMethod: true,
  paymentMethodLast4: "4242",
  paymentMethodType: "card", // card, bank_account

  // History
  planHistory: [
    {
      plan: "free",
      startDate: Timestamp,
      endDate: Timestamp,
      billingCycle: null,
      reason: "trial_ended"
    },
    {
      plan: "silver",
      startDate: Timestamp,
      endDate: null, // current
      billingCycle: "monthly",
      reason: "upgrade"
    }
  ]
}
```

### subscriptionChanges Collection (audit log)
```javascript
{
  companyId: "company123",
  userId: "userId123",
  userName: "John Smith",

  changeType: "upgrade", // upgrade, downgrade, billing_cycle_change, cancellation

  fromPlan: "free",
  toPlan: "silver",
  fromBillingCycle: null,
  toBillingCycle: "monthly",

  effectiveDate: Timestamp,
  scheduledDate: Timestamp,
  immediate: true,

  reason: "customer_initiated",
  notes: "Upgraded from pricing page",

  // Financial
  proratedCredit: 0,
  proratedCharge: 249.00,

  // Status
  status: "completed", // pending, completed, cancelled
  completedAt: Timestamp,

  createdAt: Timestamp
}
```

## Business Rules

### Upgrades
1. ✅ Always allowed (even on trial/free)
2. ✅ Take effect immediately
3. ✅ Prorated billing for mid-cycle upgrades
4. ✅ All new features unlocked instantly
5. ✅ Cannot be scheduled for future date

### Downgrades
1. ⏰ Take effect at next billing cycle
2. ⚠️ Must confirm feature loss
3. ✅ Can be cancelled before effective date
4. ✅ Data preserved during notice period
5. ✅ Auto-email 7 days before effective date

### Free → Paid
1. 💳 Payment method required first
2. ✅ Counts as upgrade (immediate)
3. ✅ Trial/free period ends
4. ✅ Billing cycle starts immediately

### Paid → Free
1. ⚠️ Strong confirmation required
2. ⚠️ Show everything they'll lose
3. ⏰ Takes effect at end of paid period
4. ℹ️ Option to request refund (manual)

### Billing Cycle Changes
1. ✅ Same plan, different cycle
2. 💰 Show annual savings (2 months free)
3. ⏰ Apply at next renewal
4. ✅ No feature changes

## Prorated Billing Calculation

### Upgrade Mid-Cycle (Immediate)
```
Current Plan: Silver ($249/mo)
New Plan: Gold ($349/mo)
Days Remaining: 15 days
Days in Month: 30 days

Credit from Silver:
  $249 × (15/30) = $124.50 credit

Charge for Gold:
  $349 - $124.50 = $224.50 due today

Next Full Charge:
  $349 on Jan 1, 2026
```

### Downgrade at Renewal (No Proration)
```
Current Plan: Gold ($349/mo)
New Plan: Silver ($249/mo)
Current Period Ends: Dec 31, 2025

No charge today
Keep Gold through Dec 31
First Silver charge: $249 on Jan 1, 2026
```

## Email Notifications

### 1. Upgrade Confirmation
```
Subject: Welcome to [Plan Name]! 🎉

You've successfully upgraded to the [Plan] plan!

What's New:
✅ [Feature 1]
✅ [Feature 2]
✅ [Feature 3]

Billing Summary:
• Plan: [Plan Name]
• Cycle: [Monthly/Yearly]
• Amount: $[amount]
• Next Charge: [date]

[View Receipt] [Manage Subscription]
```

### 2. Downgrade Scheduled
```
Subject: Subscription Change Scheduled

Your plan change has been scheduled:

Current Plan: [Current Plan] ($[amount]/mo)
New Plan: [New Plan] ($[amount]/mo)
Effective Date: [Date]

You'll keep full access to [Current Plan] until [Date].

Changed your mind? You can cancel this downgrade anytime before [Date].

[Cancel Downgrade] [View Details]
```

### 3. Downgrade Reminder (7 days before)
```
Subject: Reminder: Plan Change in 7 Days

This is a reminder that your subscription will change in 7 days:

On [Date], your plan will change from:
  [Current Plan] ($[amount]/mo)
  ↓
  [New Plan] ($[amount]/mo)

Features you'll lose:
• [Feature 1]
• [Feature 2]

Want to keep your current plan?
[Cancel Downgrade] [Upgrade Instead]
```

### 4. Downgrade Effective
```
Subject: Your Plan Has Changed

Your subscription has been updated:

Previous Plan: [Old Plan]
Current Plan: [New Plan]
Monthly Cost: $[amount]

Your billing has been adjusted and you'll be charged $[amount] on [next billing date].

[View Subscription] [Upgrade Anytime]
```

## UI Components

### Plan Comparison Table
```
┌─────────────────────────────────────────────────────────────┐
│  [Free]  [Starter] [Bronze] [Silver] [Gold] [Platinum]     │
│                             ★ POPULAR                        │
│                                                              │
│  $0      $99/mo    $149/mo  $249/mo  $349/mo  $499/mo      │
│                                                              │
│  Max 10  Max 25    Max 50   Max 100  Max 250  Unlimited    │
│  employees                                                   │
│                                                              │
│  ✓ Basic  ✓ All    ✓ All    ✓ All    ✓ All    ✓ All       │
│  features Free     Starter  Bronze   Silver   Gold         │
│                    features features features features      │
│                                                              │
│  [Current] [Select] [Select] [Select] [Select] [Select]    │
└─────────────────────────────────────────────────────────────┘
```

### Upgrade Confirmation Modal
```
┌─────────────────────────────────────────────────────────────┐
│  Confirm Upgrade                                      [×]   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  You're upgrading to Silver Plan                            │
│                                                              │
│  Current Plan:    Free ($0/mo)                              │
│  New Plan:        Silver ($249/mo)                          │
│  Billing Cycle:   Monthly                                   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Billing Summary                                      │  │
│  │                                                      │  │
│  │ Silver Plan (Monthly)               $249.00         │  │
│  │ Effective immediately                               │  │
│  │                                     ─────────        │  │
│  │ Total Due Today                     $249.00         │  │
│  │                                                      │  │
│  │ Next charge: $249.00 on Jan 1, 2026                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  New Features You'll Get:                                   │
│  ✓ GPS Tracking                                             │
│  ✓ Advanced Reporting                                       │
│  ✓ Export Data                                              │
│  ✓ Shift Swapping                                           │
│  ✓ Up to 100 employees                                      │
│                                                              │
│  Payment Method: •••• 4242 (Visa)    [Change]              │
│                                                              │
│  [Cancel]                          [Confirm Upgrade]        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Downgrade Warning Modal
```
┌─────────────────────────────────────────────────────────────┐
│  ⚠️ Downgrade Confirmation                            [×]   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Are you sure you want to downgrade?                        │
│                                                              │
│  Current Plan:  Gold ($349/mo)                              │
│  New Plan:      Silver ($249/mo)                            │
│  Effective:     Next billing cycle (Jan 1, 2026)           │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ ❌ Features You'll Lose:                             │  │
│  │                                                      │  │
│  │ • Department Management                              │  │
│  │ • Auto Scheduling                                    │  │
│  │ • Labor Cost Tracking                                │  │
│  │ • Paid Time Off                                      │  │
│  │ • Custom Dashboards                                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ✅ What You'll Keep:                                       │
│  • All your data (preserved)                                │
│  • Up to 100 employees                                      │
│  • GPS Tracking                                             │
│  • Advanced Reporting                                       │
│                                                              │
│  💰 New Monthly Cost: $249/mo (Save $100/mo)               │
│                                                              │
│  Your Gold features will remain active until Jan 1, 2026.  │
│  You can cancel this downgrade anytime before then.         │
│                                                              │
│  [Keep Gold Plan]              [Schedule Downgrade]         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## API Endpoints

### 1. changePlan (Callable)
```javascript
{
  newPlan: "silver",
  newBillingCycle: "monthly", // optional
  immediate: true, // false = schedule for next cycle
}

Returns:
{
  success: true,
  effectiveDate: Timestamp,
  immediate: true,
  proratedAmount: 249.00,
  nextBillingDate: Timestamp,
  message: "Upgraded to Silver plan"
}
```

### 2. cancelScheduledChange (Callable)
```javascript
{
  companyId: "company123"
}

Returns:
{
  success: true,
  message: "Scheduled downgrade cancelled"
}
```

### 3. getUpgradePreview (Callable)
```javascript
{
  newPlan: "gold",
  newBillingCycle: "yearly"
}

Returns:
{
  currentPlan: "silver",
  newPlan: "gold",
  proratedCredit: 124.50,
  newPlanCharge: 349.00,
  totalDueToday: 224.50,
  nextBillingDate: Timestamp,
  newFeatures: [...],
  savings: 0 // or annual savings if switching to yearly
}
```

## Implementation Priority

### Phase 4A (Core - Now)
1. ✅ Plan comparison page
2. ✅ Upgrade flow (immediate)
3. ✅ Payment integration required check
4. ✅ changePlan Cloud Function
5. ✅ Confirmation emails

### Phase 4B (Later)
1. ⏰ Downgrade flow (scheduled)
2. ⏰ Cancel scheduled change
3. ⏰ Billing cycle switching
4. ⏰ Prorated billing calculation
5. ⏰ Feature loss warnings

### Phase 4C (Future)
1. 📊 Usage-based plan suggestions
2. 🎁 Promotional discounts
3. 💳 Multiple payment methods
4. 🔄 Auto-upgrade when limits exceeded
5. 📈 Subscription analytics dashboard

## Testing Checklist

- [ ] Free → Starter upgrade
- [ ] Starter → Silver upgrade
- [ ] Silver → Gold upgrade
- [ ] Gold → Silver downgrade (scheduled)
- [ ] Cancel scheduled downgrade
- [ ] Monthly → Yearly switch
- [ ] Yearly → Monthly switch
- [ ] Upgrade without payment method (should fail)
- [ ] Downgrade confirmation works
- [ ] All emails send correctly
- [ ] Firestore audit log created
- [ ] Features unlock/lock appropriately
- [ ] Prorated billing calculates correctly

---

**Let's start with Phase 4A - Core upgrade flow!**
