# Phase 1: Multi-Tenant Database Foundation

**Implementation Guide**

---

## Overview

This guide walks you through implementing the multi-tenant database foundation for ChronoWorks. After completing Phase 1, your database will support multiple companies with complete data isolation.

**Estimated Time**: 2-3 hours
**Prerequisites**: Firebase project configured, Firebase CLI installed

---

## What You'll Accomplish

- ✅ Create new collections for companies, registration requests, and subscription plans
- ✅ Add companyId to all existing collections
- ✅ Deploy new Firestore indexes for efficient multi-tenant queries
- ✅ Deploy new security rules for data isolation
- ✅ Seed subscription plan data
- ✅ Migrate existing data (if any)
- ✅ Create your super admin account
- ✅ Test data isolation

---

## Step-by-Step Implementation

### Step 1: Review the Documentation

**Files to review**:
- `MULTI_TENANT_DATABASE_SCHEMA.md` - Complete database schema
- `firestore.rules.new` - Multi-tenant security rules
- `firestore.indexes.json` - Updated indexes

**Action**: Read through these files to understand the architecture.

---

### Step 2: Backup Your Data

**IMPORTANT**: Before making any changes, backup your existing Firestore data.

```bash
# Export all Firestore data
firebase firestore:export gs://your-project-id.appspot.com/backups/$(date +%Y%m%d)
```

If you don't have existing data, skip this step.

---

### Step 3: Create Your Super Admin Account

**Option A: Using Firebase Console**

1. Go to Firebase Console → Authentication
2. Add a new user with your email
3. Copy the UID

**Option B: Using Firebase CLI**

```bash
firebase auth:export users.json
# Review users.json to find your UID
```

---

### Step 4: Create Super Admin Document

Using Firebase Console:

1. Go to Firestore Database
2. Create a new collection: `superAdmins`
3. Add a document with your UID as the document ID
4. Add these fields:

```javascript
{
  uid: "your-firebase-auth-uid",
  email: "your@email.com",
  name: "Your Name",
  role: "super_admin",
  permissions: ["all"],
  createdAt: [Current timestamp],
  lastLoginAt: [Current timestamp],
  isActive: true
}
```

---

### Step 5: Create Your Test Company

Using Firebase Console:

1. Create a new collection: `companies`
2. Add a document (auto-generate ID or use custom ID)
3. Copy the document ID - you'll need this for migration
4. Add these fields:

```javascript
{
  companyId: "[auto-generated or custom]",
  businessName: "Test Company",
  ownerName: "Your Name",
  ownerEmail: "your@email.com",
  phone: "+1-555-123-4567",
  address: {
    street: "123 Main St",
    city: "Your City",
    state: "NC",
    zip: "28403"
  },
  numberOfEmployees: 10,
  timezone: "America/New_York",
  status: "active",
  registeredAt: [Current timestamp],
  approvedAt: [Current timestamp],
  approvedBy: "your-super-admin-uid",
  trialStartDate: [Current timestamp],
  trialEndDate: [30 days from now],
  currentPlan: "trial",
  planStartDate: [Current timestamp],
  maxEmployees: 25,
  createdAt: [Current timestamp],
  createdBy: "your-super-admin-uid",
  isActive: true
}
```

**Save the companyId** - you'll need it for the next step.

---

### Step 6: Install Script Dependencies

```bash
cd scripts
npm install
```

This installs Firebase Admin SDK for the migration and seeding scripts.

---

### Step 7: Configure Migration Script

Edit `scripts/migrate_to_multitenant.js`:

```javascript
// Update this line with your test company ID
const TEST_COMPANY_ID = 'your-company-id-here';
```

---

### Step 8: Run Migration Script (If You Have Existing Data)

**Only run this if you have existing data in your database.**

```bash
cd scripts
node migrate_to_multitenant.js
```

This adds `companyId` to all existing documents.

**Expected output**:
```
✅ Migration completed successfully!

Summary:
  users: Total: 5 | Migrated: 5 | Skipped: 0
  shifts: Total: 20 | Migrated: 20 | Skipped: 0
  ...
```

If you don't have existing data, skip this step.

---

### Step 9: Seed Subscription Plans

```bash
cd scripts
npm run seed:plans
# or: node seed_subscription_plans.js
```

**Expected output**:
```
✅ Successfully seeded all subscription plans!

Summary:
  - Free Plan: $0/mo (5 employees, limited features)
  - Bronze Plan: $19.99/mo (15 employees)
  - Silver Plan: $39.99/mo (50 employees) ⭐ POPULAR
  - Gold Plan: $79.99/mo (150 employees)
  - Platinum Plan: $149.99/mo (500 employees)
```

---

### Step 10: Rename Security Rules File

```bash
# Backup existing rules
copy firestore.rules firestore.rules.backup

# Use new multi-tenant rules
copy firestore.rules.new firestore.rules
```

---

### Step 11: Deploy Firestore Indexes

```bash
firebase deploy --only firestore:indexes
```

**Expected output**:
```
✔  firestore: deployed indexes successfully
```

**Note**: Index creation can take several minutes if you have existing data.

---

### Step 12: Deploy Security Rules

```bash
firebase deploy --only firestore:rules
```

**Expected output**:
```
✔  firestore: released rules firestore.rules successfully
```

---

### Step 13: Verify Super Admin Access

Test that you can access the Firebase Console and see all data:

1. Go to Firestore Database
2. Verify you can see all collections
3. Verify you can read/write documents

---

### Step 14: Test Data Isolation

**Create a test user in a different company:**

1. Using Firebase Console, create a new user in the `users` collection
2. Give it a different `companyId` than your test company
3. Try to query data from your test company while authenticated as this user
4. You should NOT be able to access the other company's data

**Security rule test queries** (using Firebase Console Rules Playground):

```javascript
// Test 1: Super admin can read all companies
// Auth: your-super-admin-uid
// Request: Read /companies/{any-company-id}
// Expected: Allow

// Test 2: Company admin can only read their company
// Auth: company-admin-uid (with companyId = company-A)
// Request: Read /companies/company-B
// Expected: Deny

// Test 3: Employee can only access their company's data
// Auth: employee-uid (with companyId = company-A)
// Request: Read /shifts/{shift-id-from-company-B}
// Expected: Deny
```

---

### Step 15: Verify Indexes Are Built

Check index build status:

```bash
firebase firestore:indexes
```

Or check Firebase Console → Firestore → Indexes

Wait until all indexes show "Enabled" status before proceeding.

---

## Verification Checklist

Before moving to Phase 2, verify:

- [ ] `companies` collection exists with your test company
- [ ] `registrationRequests` collection exists (can be empty)
- [ ] `subscriptionPlans` collection has 5 plans
- [ ] `superAdmins` collection has your admin account
- [ ] All existing collections have `companyId` field (if you had existing data)
- [ ] New Firestore indexes are deployed and enabled
- [ ] New security rules are deployed
- [ ] Super admin can access all data
- [ ] Regular users can only access their company's data
- [ ] You can create/read/update/delete test documents

---

## Troubleshooting

### Migration Script Errors

**Error**: `Company ${TEST_COMPANY_ID} does not exist`
- **Fix**: Create the company document first (Step 5)

**Error**: `Permission denied`
- **Fix**: Make sure you're using Firebase Admin SDK with proper credentials

### Security Rules Errors

**Error**: `Property companyId is undefined`
- **Fix**: Make sure migration script ran successfully and all documents have companyId

**Error**: `get() requires a single DocumentReference argument`
- **Fix**: This usually means a helper function is malformed. Check firestore.rules syntax.

### Index Errors

**Error**: `Index creation failed`
- **Fix**: Delete conflicting indexes in Firebase Console and redeploy

**Error**: `The query requires an index`
- **Fix**: Wait for indexes to finish building, or create the missing index manually

---

## Next Steps

After completing Phase 1:

1. **Phase 2**: Build public registration page and submission system
2. **Phase 3**: Build super admin approval dashboard
3. **Phase 4**: Implement trial management system
4. **Phase 5**: Create subscription plan selection and feature gating
5. **Phase 6**: Add payment integration (Stripe)

---

## Files Created in Phase 1

```
ChronoWorks/
├── MULTI_TENANT_DATABASE_SCHEMA.md
├── PHASE_1_IMPLEMENTATION_GUIDE.md (this file)
├── firestore.rules.new
├── firestore.indexes.json (updated)
└── scripts/
    ├── package.json
    ├── seed_subscription_plans.js
    └── migrate_to_multitenant.js
```

---

## Summary

Phase 1 establishes the multi-tenant database foundation:

- **Data Isolation**: Each company's data is completely isolated by companyId
- **Super Admin Access**: You can access and manage all companies
- **Security**: Firestore rules enforce strict data isolation
- **Scalability**: Indexes optimized for multi-tenant queries
- **Subscription Plans**: 5 tiers ready for customers to choose from

Everything is now ready for Phase 2: building the registration system.

---

**Questions or Issues?**

Review the documentation files or check the Firebase Console for detailed error messages.
