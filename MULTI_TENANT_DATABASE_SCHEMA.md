# ChronoWorks Multi-Tenant Database Schema

**Version:** 2.0.0
**Date:** November 2, 2025
**Status:** Implementation Ready

---

## Overview

This document defines the complete database schema for ChronoWorks as a multi-tenant SaaS application. Every company's data is isolated by `companyId`.

---

## New Collections

### 1. `companies`

Stores information about each business using ChronoWorks.

```javascript
{
  companyId: "uuid-auto-generated",

  // Business Information
  businessName: "Acme Corporation",
  ownerName: "John Smith",
  ownerEmail: "john@acmecorp.com",
  phone: "+1-555-123-4567",
  address: {
    street: "123 Main Street",
    city: "Wilmington",
    state: "NC",
    zip: "28403"
  },
  numberOfEmployees: 25,
  industry: "Retail", // Optional
  timezone: "America/New_York",

  // Registration & Approval
  status: "active", // pending, approved, active, suspended, cancelled
  registeredAt: Timestamp,
  approvedAt: Timestamp,
  approvedBy: "super-admin-uid",

  // Trial Management
  trialStartDate: Timestamp, // When they were approved
  trialEndDate: Timestamp,   // +30 days from approval
  freeTrialEndDate: Timestamp, // +60 days from approval (if they chose free)

  // Subscription
  currentPlan: "trial", // trial, free, bronze, silver, gold, platinum
  planStartDate: Timestamp,
  planEndDate: Timestamp, // For annual subscriptions

  // Payment Integration
  stripeCustomerId: "cus_xxxxx",
  subscriptionId: "sub_xxxxx",
  lastPaymentDate: Timestamp,
  nextBillingDate: Timestamp,
  paymentStatus: "active", // active, past_due, canceled

  // Feature Limits (based on plan)
  maxEmployees: 25,

  // Metadata
  createdAt: Timestamp,
  createdBy: "super-admin-uid",
  lastLoginAt: Timestamp,
  isActive: true,

  // Notes (for super admin)
  notes: "Trial extended due to technical issues"
}
```

**Indexes Needed:**
- `status` (ASC)
- `currentPlan` (ASC)
- `trialEndDate` (ASC) - for monitoring
- `ownerEmail` (ASC) - for lookups

---

### 2. `registrationRequests`

Stores pending business registrations awaiting super admin approval.

```javascript
{
  requestId: "uuid-auto-generated",

  // Business Information (from signup form)
  businessName: "Acme Corporation",
  ownerName: "John Smith",
  ownerEmail: "john@acmecorp.com",
  phone: "+1-555-123-4567",
  address: {
    street: "123 Main Street",
    city: "Wilmington",
    state: "NC",
    zip: "28403"
  },
  numberOfEmployees: 25,
  industry: "Retail",
  timezone: "America/New_York",

  // Additional Info
  hearAboutUs: "Google Search", // How they found us
  companyWebsite: "https://acmecorp.com", // Optional

  // Status
  status: "pending", // pending, approved, rejected
  submittedAt: Timestamp,
  reviewedAt: Timestamp,
  reviewedBy: "super-admin-uid",
  rejectionReason: "Duplicate registration", // If rejected

  // Technical Metadata
  ipAddress: "123.456.789.0",
  userAgent: "Mozilla/5.0...",
  referralSource: "google-ads", // UTM tracking

  // Terms Acceptance
  agreedToTerms: true,
  agreedToPrivacy: true,
  termsVersion: "1.0",

  // Converted Company ID (after approval)
  companyId: "uuid-of-created-company" // Set when approved
}
```

**Indexes Needed:**
- `status` (ASC), `submittedAt` (DESC)
- `ownerEmail` (ASC)

---

### 3. `subscriptionPlans`

Defines available subscription tiers and their features.

```javascript
{
  planId: "bronze", // free, bronze, silver, gold, platinum
  name: "Bronze Plan",
  description: "Perfect for small businesses just getting started",
  tagline: "Essential time tracking",

  // Pricing
  priceMonthly: 19.99,
  priceYearly: 199.99, // Save ~17%
  currency: "USD",

  // Features (boolean flags)
  features: {
    // Core Features
    scheduleManagement: true,
    clockInOut: true,
    basicReporting: true,

    // Advanced Features
    overtimeTracking: false,
    missedClockoutAlerts: false,
    gpsTracking: false,
    advancedReporting: false,
    exportData: false,
    apiAccess: false,
    customIntegrations: false,

    // Support
    emailSupport: true,
    prioritySupport: false,
    phoneSupport: false,
    dedicatedManager: false
  },

  // Limits
  maxEmployees: 15,
  maxLocations: 1,
  dataRetention: 90, // days

  // Display
  displayOrder: 1, // Order on pricing page
  isPopular: false, // Show "Most Popular" badge
  isVisible: true, // Show on pricing page

  // Stripe Integration
  stripePriceIdMonthly: "price_xxxxx",
  stripePriceIdYearly: "price_xxxxx",

  // Metadata
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

**Plans to Create:**
1. **Free Plan** (Days 31-60 only)
2. **Bronze Plan** - $19.99/month
3. **Silver Plan** - $39.99/month
4. **Gold Plan** - $79.99/month
5. **Platinum Plan** - $149.99/month

---

## Updated Existing Collections

All existing collections need `companyId` added:

### 4. `users` (Updated)

```javascript
{
  uid: "firebase-auth-uid",
  companyId: "uuid", // ← NEW FIELD

  email: "employee@company.com",
  name: "Employee Name",
  role: "employee", // super_admin, company_admin, manager, employee
  phone: "+1-555-123-4567",

  // Existing fields remain...
  ...existing fields
}
```

**New Indexes Needed:**
- `companyId` (ASC), `role` (ASC)
- `companyId` (ASC), `email` (ASC)

---

### 5. `shifts` (Updated)

```javascript
{
  shiftId: "uuid",
  companyId: "uuid", // ← NEW FIELD

  employeeId: "user-uid",
  // ...existing fields
}
```

**New Index:** `companyId` (ASC), `employeeId` (ASC), `startTime` (ASC)

---

### 6. `timeEntries` (Updated)

```javascript
{
  entryId: "uuid",
  companyId: "uuid", // ← NEW FIELD

  userId: "user-uid",
  // ...existing fields
}
```

**New Index:** `companyId` (ASC), `userId` (ASC), `clockInTime` (ASC)

---

### 7. `activeClockIns` (Updated)

```javascript
{
  clockInId: "uuid",
  companyId: "uuid", // ← NEW FIELD

  userId: "user-uid",
  // ...existing fields
}
```

**New Index:** `companyId` (ASC), `userId` (ASC)

---

### 8. `overtimeRequests` (Updated)

```javascript
{
  requestId: "uuid",
  companyId: "uuid", // ← NEW FIELD

  employeeId: "user-uid",
  // ...existing fields
}
```

**New Index:** `companyId` (ASC), `status` (ASC), `createdAt` (DESC)

---

### 9. `breakEntries` (Updated)

```javascript
{
  breakId: "uuid",
  companyId: "uuid", // ← NEW FIELD

  userId: "user-uid",
  // ...existing fields
}
```

**New Index:** `companyId` (ASC), `userId` (ASC)

---

### 10. `overtimeRiskNotifications` (Updated)

```javascript
{
  notificationId: "uuid",
  companyId: "uuid", // ← NEW FIELD

  employeeId: "user-uid",
  // ...existing fields
}
```

**New Index:** `companyId` (ASC), `employeeId` (ASC), `date` (ASC)

---

### 11. `missedClockOutWarnings` (Updated)

```javascript
{
  warningId: "uuid",
  companyId: "uuid", // ← NEW FIELD

  employeeId: "user-uid",
  // ...existing fields
}
```

**New Index:** `companyId` (ASC), `employeeId` (ASC), `date` (ASC)

---

## Special Collection: Super Admin Users

### 12. `superAdmins`

Separate collection for super admin access control.

```javascript
{
  uid: "firebase-auth-uid",
  email: "chris@chronoworks.com",
  name: "Chris Snowden",
  role: "super_admin",
  permissions: ["all"],
  createdAt: Timestamp,
  lastLoginAt: Timestamp,
  isActive: true
}
```

Only your email should be in this collection.

---

## Data Isolation Strategy

### Security Principles

1. **Company Isolation**: Users can ONLY access data for their `companyId`
2. **Super Admin Override**: Super admins can access ALL companies
3. **No Cross-Company Queries**: Firestore rules enforce isolation
4. **Explicit Company Association**: Every document must have `companyId`

### Query Pattern Example

**Before (Single Tenant):**
```javascript
db.collection('shifts')
  .where('employeeId', '==', userId)
  .get()
```

**After (Multi-Tenant):**
```javascript
db.collection('shifts')
  .where('companyId', '==', userCompanyId)
  .where('employeeId', '==', userId)
  .get()
```

---

## Migration Strategy

### For Existing Data (If Any)

1. **Backup Everything**: Export all Firestore data
2. **Create First Company**: Your test company
3. **Add companyId to Existing Data**: Run migration script
4. **Update App Code**: Add companyId to all queries
5. **Deploy New Security Rules**: Enable multi-tenant isolation
6. **Test Thoroughly**: Verify data isolation

### Migration Script (Pseudo-code)

```javascript
// Run this ONCE to migrate existing data
async function migrateToMultiTenant() {
  const testCompanyId = 'your-test-company-id';

  const collections = [
    'users', 'shifts', 'timeEntries', 'activeClockIns',
    'overtimeRequests', 'breakEntries', 'overtimeRiskNotifications',
    'missedClockOutWarnings'
  ];

  for (const collectionName of collections) {
    const snapshot = await db.collection(collectionName).get();

    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.update(doc.ref, { companyId: testCompanyId });
    });

    await batch.commit();
    console.log(`Migrated ${collectionName}: ${snapshot.size} documents`);
  }
}
```

---

## Implementation Checklist

### Phase 1A: Create New Collections
- [ ] Create `companies` collection structure
- [ ] Create `registrationRequests` collection structure
- [ ] Create `subscriptionPlans` collection structure
- [ ] Create `superAdmins` collection structure
- [ ] Seed subscription plans data

### Phase 1B: Update Existing Collections
- [ ] Add `companyId` field to all existing collections
- [ ] Run migration script for existing data
- [ ] Update Firestore indexes

### Phase 1C: Security Rules
- [ ] Write multi-tenant security rules
- [ ] Test data isolation
- [ ] Deploy rules to Firebase

### Phase 1D: Testing
- [ ] Create test companies
- [ ] Verify data isolation
- [ ] Test super admin access
- [ ] Test company admin access
- [ ] Test employee access

---

## Next Steps

After Phase 1 is complete:
- **Phase 2**: Build registration page and submission system
- **Phase 3**: Build super admin approval dashboard
- **Phase 4**: Implement trial monitoring system
- **Phase 5**: Add feature gating based on subscription plan
- **Phase 6**: Integrate Stripe payment processing

---

**Status:** Ready for implementation
**Priority:** HIGH - Everything depends on this foundation
