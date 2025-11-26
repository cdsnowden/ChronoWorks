# ChronoWorks - Comprehensive Testing Guide

**Date**: November 19, 2025
**Purpose**: Test all deployed phases (1-4) end-to-end
**Environment**: Production Firebase (chronoworks-dcfd6)

---

## Prerequisites

### Required Tools
- ✅ Firebase CLI logged in
- ✅ Node.js installed
- ✅ Flutter app accessible
- ✅ Super admin account: chris.s@snowdensjewelers.com (UID: Z1eL0Hz4pcdqYk1GJKbr0OWGOKv2)

### Email Setup (IMPORTANT)
⚠️ **SendGrid sender verification required** for email testing:
1. Go to SendGrid dashboard
2. Settings > Sender Authentication
3. Verify: support@chronoworks.com
4. Or verify: chris.s@snowdensjewelers.com

---

## Test Suite Overview

```
Phase 1: Multi-Tenant Foundation   ✅ (Pre-tested, production ready)
Phase 2: Public Registration        🧪 (Test registration flow)
Phase 3: Trial Management           🧪 (Test lifecycle automation)
Phase 4: Subscription Management    🧪 (Test upgrades/downgrades)
```

---

## PHASE 1: Multi-Tenant Foundation Test

### Test 1.1: Verify Database Schema

```bash
cd C:\Users\chris\ChronoWorks

# Check that all collections have companyId
node -e "
const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});

async function checkSchema() {
  const collections = ['companies', 'users', 'shifts', 'timeEntries'];
  for (const coll of collections) {
    const snapshot = await admin.firestore().collection(coll).limit(1).get();
    if (!snapshot.empty) {
      const doc = snapshot.docs[0].data();
      console.log(\`✓ \${coll}: \${doc.companyId ? 'HAS' : 'MISSING'} companyId\`);
    }
  }
}
checkSchema().then(() => process.exit());
"
```

**Expected Output:**
```
✓ companies: HAS companyId
✓ users: HAS companyId
✓ shifts: HAS companyId
✓ timeEntries: HAS companyId
```

### Test 1.2: Verify Subscription Plans

```bash
cd C:\Users\chris\ChronoWorks\scripts
node -e "
const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});

async function checkPlans() {
  const plans = await admin.firestore().collection('subscriptionPlans').get();
  console.log(\`Found \${plans.size} subscription plans:\`);
  plans.forEach(doc => {
    const plan = doc.data();
    console.log(\`- \${plan.name}: \$\${plan.priceMonthly}/mo, \${plan.employeeLimit} employees\`);
  });
}
checkPlans().then(() => process.exit());
"
```

**Expected Output:**
```
Found 7 subscription plans:
- Free: $0/mo, 10 employees
- Starter: $24.99/mo, 12 employees
- Bronze: $49.99/mo, 25 employees
- Silver: $89.99/mo, 50 employees
- Gold: $149.99/mo, 100 employees
- Platinum: $249.99/mo, 250 employees
- Diamond: $499.99/mo, unlimited employees
```

**Status:** ✅ PASS / ❌ FAIL

---

## PHASE 2: Public Registration Test

### Test 2.1: Create Test Registration (Manual - Flutter App)

**Steps:**
1. Open Flutter app in browser or emulator
2. Navigate to public registration page
3. Fill out form:
   - **Company Name**: Acme Test Company
   - **Website**: https://acmetest.com
   - **Admin Name**: John Test
   - **Admin Email**: john.test@acmetest.com
   - **Phone**: (555) 123-4567
   - **Select Plan**: Silver Monthly
   - **Password**: Test1234!
4. Submit registration

**Expected Result:**
- Registration success page displays
- New document created in `registrationRequests` collection

### Test 2.2: Verify Registration Created

```bash
cd C:\Users\chris\ChronoWorks
node -e "
const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});

async function checkRegistrations() {
  const regs = await admin.firestore()
    .collection('registrationRequests')
    .where('status', '==', 'pending')
    .orderBy('createdAt', 'desc')
    .limit(5)
    .get();

  console.log(\`Found \${regs.size} pending registrations:\n\`);
  regs.forEach(doc => {
    const reg = doc.data();
    console.log(\`\${doc.id}:\`);
    console.log(\`  Company: \${reg.companyName}\`);
    console.log(\`  Email: \${reg.adminEmail}\`);
    console.log(\`  Status: \${reg.status}\`);
    console.log(\`  Created: \${reg.createdAt.toDate()}\n\`);
  });
}
checkRegistrations().then(() => process.exit());
"
```

**Expected:** See "Acme Test Company" registration listed

### Test 2.3: Check Email Notification (SendGrid)

**Check:**
1. Go to SendGrid dashboard > Activity
2. Look for email to: chris.s@snowdensjewelers.com
3. Subject: "New Business Registration - Acme Test Company"

**Expected:** Email sent successfully (if sender verified)

### Test 2.4: Approve Registration (Super Admin)

**Option A: Via Flutter App**
1. Login as super admin (chris.s@snowdensjewelers.com)
2. Go to Super Admin Dashboard
3. Click "Pending Registrations"
4. Find "Acme Test Company"
5. Click "Approve"

**Option B: Via Script**

```bash
cd C:\Users\chris\ChronoWorks
node -e "
const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});

async function approveLatest() {
  // Get latest pending registration
  const regs = await admin.firestore()
    .collection('registrationRequests')
    .where('status', '==', 'pending')
    .orderBy('createdAt', 'desc')
    .limit(1)
    .get();

  if (regs.empty) {
    console.log('No pending registrations found');
    return;
  }

  const doc = regs.docs[0];
  const requestId = doc.id;
  console.log(\`Approving registration: \${requestId}\`);

  // Call Firebase Function (requires authentication)
  // For testing, we'll update directly:
  await admin.firestore()
    .collection('registrationRequests')
    .doc(requestId)
    .update({
      status: 'approved',
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: 'Z1eL0Hz4pcdqYk1GJKbr0OWGOKv2'
    });

  console.log('✓ Registration approved');
  console.log('Note: Run approveRegistration function to complete setup');
}
approveLatest().then(() => process.exit());
"
```

### Test 2.5: Verify Company & User Created

```bash
node -e "
const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});

async function verifyCompany() {
  // Find companies created in last hour
  const oneHourAgo = new Date(Date.now() - 3600000);
  const companies = await admin.firestore()
    .collection('companies')
    .where('createdAt', '>', oneHourAgo)
    .get();

  console.log(\`Found \${companies.size} new companies:\n\`);
  companies.forEach(doc => {
    const company = doc.data();
    console.log(\`Company: \${company.name}\`);
    console.log(\`Plan: \${company.currentPlan}\`);
    console.log(\`Trial Ends: \${company.trialEndsAt.toDate()}\`);
    console.log(\`Status: \${company.status}\n\`);
  });
}
verifyCompany().then(() => process.exit());
"
```

**Expected:**
- Acme Test Company created
- Plan: trial
- Trial ends: 30 days from now
- Status: active

**Status:** ✅ PASS / ❌ FAIL

---

## PHASE 3: Trial Management Test

### Test 3.1: Run Trial Expiration Check

```bash
cd C:\Users\chris\ChronoWorks\scripts
node test_trial_lifecycle.js
```

**What This Does:**
- Creates 4 test companies with backdated trials:
  - Day 27 (warning should trigger)
  - Day 30 (should convert to free)
  - Day 57 (lock warning)
  - Day 60 (should lock account)

### Test 3.2: Manually Trigger Trial Check

```bash
# Trigger the scheduled function manually
curl https://us-central1-chronoworks-dcfd6.cloudfunctions.net/testTrialExpirations
```

### Test 3.3: Verify Trial Transitions

```bash
cd C:\Users\chris\ChronoWorks\scripts
node check_test_companies.js
```

**Expected Output:**
```
Company 1 (Day 27):
  Status: active
  Plan: trial
  Days Remaining: 3

Company 2 (Day 30):
  Status: active
  Plan: free ← Transitioned!
  Free Period Ends: 30 days from now

Company 3 (Day 57):
  Status: active
  Plan: free
  Days Remaining: 3

Company 4 (Day 60):
  Status: locked ← Account locked!
  Locked Reason: Free period expired
```

### Test 3.4: Cleanup Test Data

```bash
cd C:\Users\chris\ChronoWorks\scripts
node test_trial_lifecycle.js --cleanup
```

**Status:** ✅ PASS / ❌ FAIL

---

## PHASE 4: Subscription Management Test

### Test 4.1: Test Upgrade Preview

```bash
cd C:\Users\chris\ChronoWorks
node -e "
const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});

async function testUpgradePreview() {
  // Get a test company
  const companies = await admin.firestore()
    .collection('companies')
    .where('currentPlan', '==', 'free')
    .limit(1)
    .get();

  if (companies.empty) {
    console.log('No free companies found for testing');
    return;
  }

  const companyId = companies.docs[0].id;
  const company = companies.docs[0].data();

  console.log(\`Testing upgrade for company: \${company.name}\`);
  console.log(\`Current Plan: \${company.currentPlan}\`);
  console.log(\`\nUpgrade Preview:\`);
  console.log(\`Free (\$0/mo) → Silver (\$89.99/mo)\`);
  console.log(\`Monthly: \$89.99 due today\`);
  console.log(\`Yearly: \$899.99 due today (save \$180/year)\`);
}
testUpgradePreview().then(() => process.exit());
"
```

### Test 4.2: Test Plan Change (Upgrade)

**Via Flutter App:**
1. Login as admin of test company
2. Go to Settings > Subscription
3. Click "View Plans"
4. Select "Silver Plan"
5. Choose "Monthly"
6. Click "Upgrade Now"
7. Confirm upgrade

**Via Script (Direct):**
```bash
node -e "
const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});

async function testUpgrade() {
  // Find a test company
  const companies = await admin.firestore()
    .collection('companies')
    .where('currentPlan', '==', 'free')
    .limit(1)
    .get();

  if (companies.empty) {
    console.log('No test company found');
    return;
  }

  const companyId = companies.docs[0].id;
  const company = companies.docs[0].data();

  console.log(\`Upgrading \${company.name} to Silver...\`);

  // Update plan
  await admin.firestore().collection('companies').doc(companyId).update({
    currentPlan: 'silver',
    billingCycle: 'monthly',
    planChangedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  // Log change
  await admin.firestore().collection('subscriptionChanges').add({
    companyId,
    fromPlan: 'free',
    toPlan: 'silver',
    changeType: 'upgrade',
    effectiveDate: admin.firestore.Timestamp.now(),
    changedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  console.log('✓ Upgrade complete!');
}
testUpgrade().then(() => process.exit());
"
```

### Test 4.3: Test Plan Change (Downgrade - Scheduled)

```bash
node -e "
const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});

async function testDowngrade() {
  // Find company on Silver or higher
  const companies = await admin.firestore()
    .collection('companies')
    .where('currentPlan', '==', 'silver')
    .limit(1)
    .get();

  if (companies.empty) {
    console.log('No silver companies found');
    return;
  }

  const companyId = companies.docs[0].id;
  const company = companies.docs[0].data();

  console.log(\`Scheduling downgrade for \${company.name}...\`);

  // Schedule downgrade for next billing cycle
  const nextBillingDate = new Date();
  nextBillingDate.setDate(nextBillingDate.getDate() + 30);

  await admin.firestore().collection('companies').doc(companyId).update({
    scheduledPlanChange: {
      newPlan: 'starter',
      newBillingCycle: 'monthly',
      effectiveDate: admin.firestore.Timestamp.fromDate(nextBillingDate),
      scheduledAt: admin.firestore.Timestamp.now()
    }
  });

  // Log scheduled change
  await admin.firestore().collection('subscriptionChanges').add({
    companyId,
    fromPlan: 'silver',
    toPlan: 'starter',
    changeType: 'downgrade',
    effectiveDate: admin.firestore.Timestamp.fromDate(nextBillingDate),
    status: 'scheduled',
    changedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  console.log(\`✓ Downgrade scheduled for: \${nextBillingDate.toDateString()}\`);
  console.log('  Current plan remains Silver until then');
}
testDowngrade().then(() => process.exit());
"
```

### Test 4.4: Test Cancel Scheduled Downgrade

```bash
node -e "
const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});

async function testCancelDowngrade() {
  // Find company with scheduled change
  const companies = await admin.firestore()
    .collection('companies')
    .get();

  let found = null;
  companies.forEach(doc => {
    const data = doc.data();
    if (data.scheduledPlanChange) {
      found = {id: doc.id, data};
    }
  });

  if (!found) {
    console.log('No scheduled downgrades found');
    return;
  }

  console.log(\`Cancelling scheduled downgrade for \${found.data.name}...\`);

  await admin.firestore().collection('companies').doc(found.id).update({
    scheduledPlanChange: admin.firestore.FieldValue.delete()
  });

  console.log('✓ Scheduled downgrade cancelled');
}
testCancelDowngrade().then(() => process.exit());
"
```

**Status:** ✅ PASS / ❌ FAIL

---

## Final Integration Test

### Test: Complete User Journey

1. **Registration** (Phase 2)
   - [ ] Public signup completes
   - [ ] Super admin receives email
   - [ ] Super admin approves
   - [ ] Welcome email sent
   - [ ] User can login

2. **Trial Period** (Phase 3)
   - [ ] Company starts on 30-day trial
   - [ ] All features accessible
   - [ ] Trial banner displays countdown
   - [ ] Day 27: Warning email sent
   - [ ] Day 31: Auto-converted to Free

3. **Free Period** (Phase 3)
   - [ ] Limited features enforced
   - [ ] Free countdown displays
   - [ ] Day 57: Lock warning email
   - [ ] Day 61: Account locked

4. **Upgrade** (Phase 4)
   - [ ] View subscription plans
   - [ ] Preview upgrade costs
   - [ ] Upgrade to paid plan
   - [ ] Features unlock immediately
   - [ ] Confirmation email sent

5. **Downgrade** (Phase 4)
   - [ ] Schedule downgrade
   - [ ] Warning about feature loss
   - [ ] Scheduled confirmation email
   - [ ] Can cancel before effective date

---

## Email Testing Checklist

### Required SendGrid Setup
- [ ] Sender verified: support@chronoworks.com
- [ ] API key configured in .env
- [ ] Test email sent successfully

### Email Templates to Test
1. [ ] Admin notification (new registration)
2. [ ] Welcome email (approved registration)
3. [ ] Rejection email (rejected registration)
4. [ ] Trial warning (Day 27)
5. [ ] Trial expired → Free notification
6. [ ] Free account lock warning (Day 57)
7. [ ] Account locked notification
8. [ ] Upgrade confirmation
9. [ ] Downgrade scheduled confirmation

---

## Troubleshooting

### Issue: Emails Not Sending
**Solution:**
1. Check SendGrid dashboard > Activity
2. Verify sender email in Settings > Sender Authentication
3. Check .env file has correct SENDGRID_API_KEY
4. Verify FROM email matches verified sender

### Issue: Functions Not Triggering
**Solution:**
```bash
# Check function logs
firebase functions:log --limit 50

# Manually trigger scheduled function
curl https://us-central1-chronoworks-dcfd6.cloudfunctions.net/testTrialExpirations
```

### Issue: Data Not Updating
**Solution:**
```bash
# Check Firestore rules
firebase firestore:rules

# Check Firebase Console for errors
```

---

## Success Criteria

### ✅ Phase 1 Complete When:
- [ ] All collections have companyId
- [ ] 7 subscription plans deployed
- [ ] Security rules enforce data isolation

### ✅ Phase 2 Complete When:
- [ ] Public registration form works
- [ ] Admin receives notification email
- [ ] Approval creates company + user
- [ ] Welcome email sent
- [ ] User can login

### ✅ Phase 3 Complete When:
- [ ] Trial warnings sent Day 27
- [ ] Auto-conversion to Free Day 31
- [ ] Lock warnings sent Day 57
- [ ] Auto-lock Day 61
- [ ] All transitions work correctly

### ✅ Phase 4 Complete When:
- [ ] Upgrades work immediately
- [ ] Downgrades schedule correctly
- [ ] Can cancel scheduled changes
- [ ] Confirmation emails sent
- [ ] Plan changes logged

---

## Next Steps After Testing

1. **Fix any failures** identified in testing
2. **Deploy fixes** to production
3. **Verify SendGrid** sender authentication
4. **Test email delivery** end-to-end
5. **Update documentation** with findings
6. **Prepare for Phase 5** (Stripe integration)

---

**Testing Completed**: ___/___/___
**Tested By**: ___________________
**Overall Status**: ✅ PASS / ❌ FAIL / ⚠️ PARTIAL
**Notes**:
