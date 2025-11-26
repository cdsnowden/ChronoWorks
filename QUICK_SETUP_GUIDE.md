# ChronoWorks Phase 1 - Quick Setup Guide

## Manual Setup Using Firebase Console

Since we don't have service account credentials set up, we'll create the initial documents manually through the Firebase Console. This is quick and straightforward.

---

## Step 1: Open Firebase Console

1. Go to: https://console.firebase.google.com/
2. Select project: **ChronoWorks** (chronoworks-dcfd6)
3. Click **Firestore Database** in the left menu

---

## Step 2: Create Super Admin Document

1. Click **+ Start collection**
2. Collection ID: `superAdmins`
3. Click **Next**

4. Document ID: `Z1eL0Hz4pcdqYk1GJKbr0OWGOKv2` (your Firebase Auth UID)

5. Add these fields:

| Field | Type | Value |
|-------|------|-------|
| `uid` | string | `Z1eL0Hz4pcdqYk1GJKbr0OWGOKv2` |
| `email` | string | `chris.s@snowdensjewelers.com` |
| `name` | string | `Chris Snowden` |
| `role` | string | `super_admin` |
| `permissions` | array | `["all"]` |
| `createdAt` | timestamp | [Click "Set to current time"] |
| `lastLoginAt` | timestamp | [Click "Set to current time"] |
| `isActive` | boolean | `true` |

6. Click **Save**

---

## Step 3: Create Test Company Document

1. Click **+ Start collection** (or click the + next to Collections if superAdmins already exists)
2. Collection ID: `companies`
3. Click **Next**

4. Document ID: **Auto-ID** (let Firebase generate it)

5. Add these fields:

**Basic Info:**
| Field | Type | Value |
|-------|------|-------|
| `companyId` | string | [Same as the auto-generated document ID] |
| `businessName` | string | `ChronoWorks Test Company` |
| `ownerName` | string | `Chris Snowden` |
| `ownerEmail` | string | `chris.s@snowdensjewelers.com` |
| `phone` | string | `+1-910-555-1234` |
| `numberOfEmployees` | number | `10` |
| `industry` | string | `Technology` |
| `timezone` | string | `America/New_York` |

**Address (map field):**
| Field | Type | Value |
|-------|------|-------|
| `address` | map | ⬇️ Click to expand |
| `address.street` | string | `123 Main Street` |
| `address.city` | string | `Wilmington` |
| `address.state` | string | `NC` |
| `address.zip` | string | `28403` |

**Status & Registration:**
| Field | Type | Value |
|-------|------|-------|
| `status` | string | `active` |
| `registeredAt` | timestamp | [Current time] |
| `approvedAt` | timestamp | [Current time] |
| `approvedBy` | string | `Z1eL0Hz4pcdqYk1GJKbr0OWGOKv2` |

**Trial Management:**
| Field | Type | Value |
|-------|------|-------|
| `trialStartDate` | timestamp | [Current time] |
| `trialEndDate` | timestamp | [30 days from now] |

**Subscription:**
| Field | Type | Value |
|-------|------|-------|
| `currentPlan` | string | `trial` |
| `planStartDate` | timestamp | [Current time] |
| `maxEmployees` | number | `25` |

**Metadata:**
| Field | Type | Value |
|-------|------|-------|
| `createdAt` | timestamp | [Current time] |
| `createdBy` | string | `Z1eL0Hz4pcdqYk1GJKbr0OWGOKv2` |
| `lastLoginAt` | timestamp | [Current time] |
| `isActive` | boolean | `true` |
| `notes` | string | `Initial test company for development` |

6. Click **Save**

7. **IMPORTANT**: Copy the document ID (companyId) - you'll need it later!

---

## Step 4: Update Existing Users (If Any)

If you have existing users in the `users` collection:

1. Go to the `users` collection in Firestore
2. For each user document:
   - Click the document
   - Click **+ Add field**
   - Field: `companyId`
   - Type: string
   - Value: [The companyId from Step 3]
   - Click **Add**

---

## Step 5: Seed Subscription Plans

Now we'll run the seeding script to create the 5 subscription tiers:

```bash
cd ChronoWorks/scripts
npm run seed:plans
```

**Expected output:**
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

## Step 6: Deploy Firestore Indexes

```bash
cd ChronoWorks
firebase deploy --only firestore:indexes
```

Wait for indexes to build (check status in Firebase Console → Firestore → Indexes).

---

## Step 7: Deploy Security Rules

First, replace the old rules with the new multi-tenant rules:

```bash
cd ChronoWorks
copy firestore.rules firestore.rules.backup
copy firestore.rules.new firestore.rules
```

Then deploy:

```bash
firebase deploy --only firestore:rules
```

---

## Step 8: Verify Setup

1. Go to Firebase Console → Firestore Database
2. You should see these collections:
   - ✅ `superAdmins` (1 document - you)
   - ✅ `companies` (1 document - test company)
   - ✅ `subscriptionPlans` (5 documents - Free, Bronze, Silver, Gold, Platinum)

3. Try accessing data:
   - Click on any collection
   - Verify you can see all documents
   - This confirms your super admin access is working

---

## Next Steps

After completing these steps:

1. **Phase 2**: Build public registration page
2. **Phase 3**: Build super admin approval dashboard
3. **Phase 4**: Implement trial management system
4. **Phase 5**: Add subscription plan selection
5. **Phase 6**: Integrate payment processing (Stripe)

---

## Troubleshooting

**Can't add timestamp fields?**
- Click the field type dropdown
- Select "timestamp"
- Click "Set to current time" button

**Forgot to copy the company ID?**
- Go back to the `companies` collection
- Click your company document
- The document ID is shown at the top

**Need to update security rules later?**
- Your backup is at: `firestore.rules.backup`
- New rules are at: `firestore.rules.new`

---

## Summary

You've now completed:
- ✅ Created super admin account
- ✅ Created test company
- ✅ Seeded subscription plans
- ✅ Deployed multi-tenant indexes
- ✅ Deployed security rules

ChronoWorks is now a multi-tenant SaaS platform! Ready for Phase 2.
