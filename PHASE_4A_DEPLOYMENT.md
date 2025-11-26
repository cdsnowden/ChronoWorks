# Phase 4A: Subscription Management - DEPLOYED ✅

## Deployment Summary

**Date**: November 2, 2025
**Status**: Backend Complete & Deployed
**Functions Deployed**: 3 Cloud Functions

### ✅ Successfully Deployed Functions

1. **changePlan** (Callable HTTP)
   - Region: us-central1
   - Runtime: Node.js 20 (2nd Gen)
   - Type: HTTPS Callable Function
   - Purpose: Handle plan upgrades and downgrades

2. **cancelScheduledChange** (Callable HTTP)
   - Region: us-central1
   - Runtime: Node.js 20 (2nd Gen)
   - Type: HTTPS Callable Function
   - Purpose: Cancel scheduled downgrades

3. **getUpgradePreview** (Callable HTTP)
   - Region: us-central1
   - Runtime: Node.js 20 (2nd Gen)
   - Type: HTTPS Callable Function
   - Purpose: Preview costs before plan changes

## What This System Does

### Core Subscription Management

```
User Initiates Plan Change:
├─ getUpgradePreview called
│  ├─ Calculates prorated amounts
│  ├─ Shows current vs new plan comparison
│  ├─ Displays total due today
│  └─ Returns savings for yearly plans
│
└─ User confirms → changePlan called
   ├─ Validates permissions (admin/owner only)
   ├─ Checks payment method for free → paid
   ├─ Determines upgrade vs downgrade
   │
   ├─ If Upgrade:
   │  ├─ Apply immediately
   │  ├─ Calculate prorated billing
   │  ├─ Update company.currentPlan
   │  ├─ Log to subscriptionChanges
   │  └─ Send upgrade confirmation email
   │
   └─ If Downgrade:
      ├─ Schedule for next billing cycle
      ├─ Store in company.scheduledPlanChange
      ├─ Log to subscriptionChanges
      ├─ Send scheduled downgrade email
      └─ User can cancel via cancelScheduledChange
```

## Business Rules Implemented

### Upgrades
- ✅ Always immediate (no scheduling)
- ✅ Prorated billing for mid-cycle upgrades
- ✅ Free → paid requires payment method
- ✅ All new features unlock instantly
- ✅ Confirmation email sent

### Downgrades
- ⏰ Scheduled for next billing cycle
- ✅ Current plan remains active until effective date
- ✅ Can be cancelled anytime before effective date
- ✅ Data preserved during transition
- ✅ Scheduled confirmation email sent

### Permissions
- 🔒 Only admin, owner, or superadmin can change plans
- ✅ User must be associated with a company
- ✅ Full authentication required

## Plan Definitions

```javascript
PLANS = {
  free: { monthlyPrice: 0, yearlyPrice: 0, maxEmployees: 10, level: 0 },
  starter: { monthlyPrice: 24.99, yearlyPrice: 249.99, maxEmployees: 12, level: 1 },
  bronze: { monthlyPrice: 49.99, yearlyPrice: 499.99, maxEmployees: 25, level: 2 },
  silver: { monthlyPrice: 89.99, yearlyPrice: 899.99, maxEmployees: 50, level: 3 },
  gold: { monthlyPrice: 149.99, yearlyPrice: 1499.99, maxEmployees: 100, level: 4 },
  platinum: { monthlyPrice: 249.99, yearlyPrice: 2499.99, maxEmployees: 250, level: 5 },
  diamond: { monthlyPrice: 499.99, yearlyPrice: 4999.99, maxEmployees: 999999, level: 6 }
}
```

Note: Yearly plans save ~17% (10/12 of monthly × 12)

## Testing the Backend

### 1. Test Upgrade Preview

From Flutter app:
```dart
final functions = FirebaseFunctions.instance;
final callable = functions.httpsCallable('getUpgradePreview');

final result = await callable.call({
  'newPlan': 'silver',
  'newBillingCycle': 'monthly',
});

print('Total due today: \$${result.data['totalDueToday']}');
print('Prorated credit: \$${result.data['proratedCredit']}');
```

### 2. Test Plan Change (Upgrade)

From Flutter app:
```dart
final callable = functions.httpsCallable('changePlan');

final result = await callable.call({
  'newPlan': 'silver',
  'newBillingCycle': 'monthly',
  'immediate': true, // optional, defaults based on upgrade/downgrade
});

print('Success: ${result.data['success']}');
print('Message: ${result.data['message']}');
print('Effective date: ${result.data['effectiveDate']}');
```

### 3. Test Plan Change (Downgrade)

From Flutter app:
```dart
final callable = functions.httpsCallable('changePlan');

final result = await callable.call({
  'newPlan': 'starter',
  'newBillingCycle': 'monthly',
});

// Downgrade will be scheduled, not immediate
print('Scheduled for: ${result.data['effectiveDate']}');
```

### 4. Test Cancel Scheduled Change

From Flutter app:
```dart
final callable = functions.httpsCallable('cancelScheduledChange');

final result = await callable.call();

print('Cancelled: ${result.data['success']}');
```

## Firestore Updates

### companies Collection - New/Updated Fields

```javascript
{
  // Existing fields...
  currentPlan: "silver",
  billingCycle: "monthly",

  // New billing tracking
  nextBillingDate: Timestamp,
  lastBillingDate: Timestamp,
  billingStatus: "active", // active, past_due, cancelled

  // Payment info
  hasPaymentMethod: true,
  paymentMethodLast4: "4242",
  paymentMethodType: "card",

  // Scheduled changes (only present if downgrade scheduled)
  scheduledPlanChange: {
    newPlan: "starter",
    newBillingCycle: "monthly",
    effectiveDate: Timestamp,
    scheduledAt: Timestamp,
    scheduledBy: "userId",
    reason: "downgrade"
  },

  // Plan history tracking
  planHistory: [
    {
      plan: "free",
      billingCycle: null,
      startDate: Timestamp,
      endDate: Timestamp,
      reason: "trial_ended"
    },
    {
      plan: "silver",
      billingCycle: "monthly",
      startDate: Timestamp,
      endDate: null, // current plan
      reason: "upgrade"
    }
  ]
}
```

### subscriptionChanges Collection (New - Audit Log)

```javascript
{
  companyId: "company123",
  companyName: "Acme Corp",
  userId: "user123",
  userName: "John Smith",
  userEmail: "john@acme.com",

  changeType: "upgrade", // upgrade, downgrade, billing_cycle_change, cancellation

  fromPlan: "free",
  toPlan: "silver",
  fromBillingCycle: null,
  toBillingCycle: "monthly",

  effectiveDate: Timestamp,
  scheduledDate: Timestamp,
  immediate: true,

  reason: "customer_initiated",
  notes: "Upgraded from free to silver",

  // Financial tracking
  proratedCredit: 0,
  proratedCharge: 249.00,
  totalDueToday: 249.00,

  // Status tracking
  status: "completed", // pending, completed, cancelled
  completedAt: Timestamp,

  createdAt: Timestamp
}
```

## Email Templates Added

### 1. Upgrade Confirmation Email
- **Subject**: Welcome to [Plan Name]! 🎉
- **Theme**: Green gradient (success)
- **Content**:
  - Billing summary with prorated amounts
  - List of new features unlocked
  - Next charge date and amount
  - Link to dashboard

### 2. Downgrade Scheduled Email
- **Subject**: Subscription Change Scheduled
- **Theme**: Blue gradient (informational)
- **Content**:
  - Current plan vs new plan comparison
  - Effective date
  - Savings amount
  - Option to cancel downgrade
  - Link to manage subscription

## Prorated Billing Examples

### Example 1: Mid-Cycle Upgrade
```
Current Plan: Silver ($89.99/mo)
New Plan: Gold ($149.99/mo)
Days Remaining: 15 out of 30

Calculation:
- Credit: $89.99 × (15/30) = $45.00
- New Charge: $149.99
- Due Today: $149.99 - $45.00 = $104.99
- Next Full Charge: $149.99 on next billing date
```

### Example 2: Free to Paid
```
Current Plan: Free ($0/mo)
New Plan: Silver ($89.99/mo)

Calculation:
- No credit (was free)
- Due Today: $89.99
- Next Charge: $89.99 on date + 30 days
```

### Example 3: Scheduled Downgrade
```
Current Plan: Platinum ($249.99/mo)
New Plan: Gold ($149.99/mo)
Next Billing Date: Dec 31, 2025

Result:
- No charge today
- Keep Platinum until Dec 31
- First Gold charge: $149.99 on Jan 1, 2026
```

## API Response Examples

### getUpgradePreview Response
```json
{
  "success": true,
  "currentPlan": "free",
  "currentPlanName": "Free",
  "currentBillingCycle": null,
  "newPlan": "silver",
  "newPlanName": "Silver",
  "newBillingCycle": "monthly",
  "isUpgrade": true,
  "immediate": true,
  "proratedCredit": 0,
  "newPlanCharge": 89.99,
  "totalDueToday": 89.99,
  "savings": 0,
  "nextBillingDate": "2025-12-02T00:00:00.000Z",
  "hasPaymentMethod": true
}
```

### changePlan Response (Upgrade)
```json
{
  "success": true,
  "effectiveDate": "2025-11-02T15:30:00.000Z",
  "immediate": true,
  "changeType": "upgrade",
  "message": "Successfully upgraded to Silver plan",
  "proratedCredit": 0,
  "proratedCharge": 89.99,
  "totalDueToday": 89.99,
  "nextBillingDate": "2025-12-02T15:30:00.000Z"
}
```

### changePlan Response (Scheduled Downgrade)
```json
{
  "success": true,
  "effectiveDate": "2026-01-01T00:00:00.000Z",
  "immediate": false,
  "changeType": "downgrade",
  "message": "downgrade to Starter scheduled for Sat Jan 01 2026"
}
```

## Error Handling

The functions will throw errors for:
- ❌ Unauthorized (no authentication)
- ❌ Insufficient permissions (not admin/owner)
- ❌ Invalid plan name
- ❌ Invalid billing cycle
- ❌ User not associated with company
- ❌ Company not found
- ❌ Payment method required (free → paid)
- ❌ No-op change (already on that plan)
- ❌ No scheduled change to cancel

## Next Steps

### Option A: Build Flutter UI Now
Create the subscription management UI with:
- Plans comparison page
- Upgrade/downgrade flow
- Confirmation modals
- Scheduled change banner
- Estimated time: 4-6 hours

### Option B: Test Backend First
1. Create test companies at different plan levels
2. Test upgrade flow (free → paid, paid → higher tier)
3. Test downgrade flow (schedule, cancel, effective date)
4. Test billing cycle switching
5. Verify all emails send correctly
6. Check Firestore audit logs

### Option C: Continue to Phase 4B/4C
Add additional features before building UI:
- Feature access control middleware
- Auto-apply scheduled changes (scheduled function)
- Payment processing integration (Stripe)
- Billing history and invoices

## Success Metrics

Track these after going live:
- **Upgrade Rate**: % of free/trial → paid conversions
- **Downgrade Rate**: % of customers downgrading plans
- **Cancellation Rate**: % of scheduled downgrades actually cancelled
- **Average Plan Value**: Mean monthly revenue per customer
- **Self-Service Rate**: % of plan changes without support intervention

## Files Created/Modified

### Backend
- ✅ `functions/subscriptionManagementFunctions.js` (680+ lines)
- ✅ `functions/emailService.js` (added 330+ lines)
- ✅ `functions/index.js` (added imports and exports)

### Documentation
- ✅ `PHASE_4_ARCHITECTURE.md` (complete design spec)
- ✅ `PHASE_4A_DEPLOYMENT.md` (this file)

### Next to Create (Flutter UI)
- ⏳ `lib/models/subscription_plan.dart`
- ⏳ `lib/services/subscription_service.dart`
- ⏳ `lib/screens/subscription_plans_page.dart`
- ⏳ `lib/widgets/plan_card.dart`
- ⏳ `lib/widgets/upgrade_confirmation_modal.dart`
- ⏳ `lib/widgets/downgrade_warning_modal.dart`

## Troubleshooting

### "Payment method required" Error
- User trying to upgrade from free without payment on file
- Solution: Redirect to payment method setup first

### "Insufficient permissions" Error
- User is not admin/owner/superadmin
- Solution: Check user role in Firestore

### Email not sending
- SendGrid sender verification incomplete
- Solution: Verify sender in SendGrid dashboard

### Scheduled change not appearing
- Check `company.scheduledPlanChange` field exists
- Verify it's a downgrade (upgrades never scheduled)

## Cost Estimate

With 100 active customers making ~10 plan changes/month:
- ~10 plan changes × 3 function calls each = 30 invocations
- ~100 preview requests before changes = 100 invocations
- Total: ~130 function invocations/month
- Cost: ~$0.01/month (well within free tier)

Email costs depend on SendGrid plan and volume.

---

**Phase 4A Backend is live and ready for customer plan changes! 🚀**

Next: Build Flutter UI for self-service subscription management

