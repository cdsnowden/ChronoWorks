# Phase 2: Public Registration System - Implementation Guide

## Overview
Phase 2 adds a public registration system where businesses can sign up for ChronoWorks, get super admin approval, and start their 30-day full trial.

---

## Architecture Overview

### **Registration Flow**
```
1. Public visits chronoworks.com/register
2. Fills out business information form
3. Submits registration request → Firestore (registrationRequests collection)
4. Super admin receives notification
5. Super admin reviews and approves/rejects
6. On approval:
   - Create company document in companies collection
   - Create owner user account
   - Send welcome email with login credentials
   - Start 30-day trial timer
7. On rejection:
   - Send rejection email with reason
```

---

## Components to Build

### **1. Public Registration Page (Flutter Web)**

**Route:** `/register`

**UI Components:**
- Hero section with value proposition
- Multi-step form (3 steps)
- Form validation
- Loading states
- Success/error messages

**Form Fields:**

**Step 1: Business Information**
- Business Name (required)
- Industry (dropdown: Retail, Restaurant, Healthcare, Construction, etc.)
- Number of Employees (dropdown: 1-10, 11-25, 26-50, 51-100, 100+)
- Website (optional)

**Step 2: Owner Information**
- Owner Full Name (required)
- Email Address (required, validated)
- Phone Number (required, formatted)
- Job Title (optional)

**Step 3: Business Address**
- Street Address (required)
- City (required)
- State (dropdown, required)
- ZIP Code (required, validated)
- Timezone (auto-detected, can override)

**Step 4: Account Setup**
- Password (required, min 8 chars, strength meter)
- Confirm Password (required, must match)
- Agree to Terms of Service (checkbox, required)
- Agree to Privacy Policy (checkbox, required)

---

### **2. Super Admin Approval Dashboard**

**Route:** `/admin/registration-requests`

**Features:**
- List of pending registration requests
- Search and filter functionality
- Detailed view of each request
- Approve/Reject buttons
- Rejection reason field
- Audit trail (who approved/rejected, when)

**UI Layout:**
```
┌─────────────────────────────────────────────────┐
│ Registration Requests                    [Filter]│
├─────────────────────────────────────────────────┤
│                                                   │
│ ┌───────────────────────────────────────────┐   │
│ │ ChronoWorks Test Company                  │   │
│ │ chris.s@snowdensjewelers.com              │   │
│ │ Submitted: 2025-01-15 10:30 AM            │   │
│ │ Employees: 15 | Industry: Retail          │   │
│ │                                            │   │
│ │ [View Details] [Approve] [Reject]         │   │
│ └───────────────────────────────────────────┘   │
│                                                   │
│ ┌───────────────────────────────────────────┐   │
│ │ ABC Construction LLC                      │   │
│ │ owner@abcconstruction.com                 │   │
│ │ Submitted: 2025-01-14 3:45 PM             │   │
│ │ Employees: 50 | Industry: Construction    │   │
│ │                                            │   │
│ │ [View Details] [Approve] [Reject]         │   │
│ └───────────────────────────────────────────┘   │
│                                                   │
└─────────────────────────────────────────────────┘
```

---

### **3. Cloud Functions (Firebase Functions)**

**Function: `onRegistrationSubmitted`**
- Trigger: onCreate in registrationRequests collection
- Action: Send email notification to super admin
- Email content: Link to approval dashboard

**Function: `approveRegistration`**
- HTTP callable function
- Creates company document
- Creates Firebase Auth user for owner
- Creates user document in users collection
- Sends welcome email to owner
- Updates registrationRequest status to 'approved'

**Function: `rejectRegistration`**
- HTTP callable function
- Updates registrationRequest status to 'rejected'
- Sends rejection email with reason

**Function: `sendWelcomeEmail`**
- Triggered after approval
- Sends email with:
  - Welcome message
  - Login credentials
  - Trial expiration date
  - Quick start guide link

---

### **4. Email Templates**

**Super Admin Notification Email:**
```
Subject: New ChronoWorks Registration Request

Hello Chris,

A new business has registered for ChronoWorks:

Business Name: [businessName]
Owner: [ownerName] ([ownerEmail])
Employees: [numberOfEmployees]
Industry: [industry]

Review and approve this registration:
[Link to admin dashboard]

---
ChronoWorks Admin System
```

**Welcome Email (After Approval):**
```
Subject: Welcome to ChronoWorks! Your Trial Has Started

Hello [ownerName],

Welcome to ChronoWorks! Your account has been approved and your 30-day full trial has started.

Login Details:
Email: [email]
Password: [temporary password]
Login URL: https://chronoworks.com/login

Trial Details:
- Full access to all features
- Trial ends: [trialEndDate]
- No credit card required

Getting Started:
1. Log in to your account
2. Add your employees
3. Create your first schedule
4. Start tracking time

Need help? Reply to this email or visit our help center.

Best regards,
The ChronoWorks Team
```

**Rejection Email:**
```
Subject: ChronoWorks Registration Update

Hello [ownerName],

Thank you for your interest in ChronoWorks.

Unfortunately, we're unable to approve your registration at this time.

Reason: [rejectionReason]

If you have questions or would like to discuss this further, please reply to this email.

Best regards,
The ChronoWorks Team
```

---

## File Structure

### **Flutter App**
```
lib/
├── screens/
│   ├── public/
│   │   ├── register_page.dart              # Public registration form
│   │   ├── register_success_page.dart      # Confirmation page
│   │   └── widgets/
│   │       ├── business_info_step.dart
│   │       ├── owner_info_step.dart
│   │       ├── address_step.dart
│   │       └── account_setup_step.dart
│   │
│   └── admin/
│       ├── registration_requests_page.dart # Admin dashboard
│       ├── registration_detail_page.dart   # Detailed view
│       └── widgets/
│           ├── request_card.dart
│           └── approve_reject_dialog.dart
│
├── models/
│   └── registration_request.dart           # Registration model
│
├── services/
│   ├── registration_service.dart           # Registration submission
│   └── admin_service.dart                  # Approval/rejection
│
└── utils/
    └── validators.dart                      # Form validation
```

### **Cloud Functions**
```
functions/
├── src/
│   ├── registration/
│   │   ├── onRegistrationSubmitted.ts
│   │   ├── approveRegistration.ts
│   │   └── rejectRegistration.ts
│   │
│   ├── email/
│   │   ├── sendAdminNotification.ts
│   │   ├── sendWelcomeEmail.ts
│   │   └── sendRejectionEmail.ts
│   │
│   └── utils/
│       ├── emailTemplates.ts
│       └── createUserAccount.ts
│
└── index.ts
```

---

## Implementation Steps

### **Step 1: Create Registration Models**
```dart
// lib/models/registration_request.dart
class RegistrationRequest {
  final String requestId;
  final String businessName;
  final String industry;
  final int numberOfEmployees;
  final String? website;

  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String? jobTitle;

  final Address address;
  final String timezone;

  final String status; // 'pending', 'approved', 'rejected'
  final DateTime submittedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
}
```

### **Step 2: Build Registration Form UI**
- Create multi-step form with validation
- Add form state management
- Implement password strength meter
- Add terms of service checkbox

### **Step 3: Create Registration Service**
```dart
// lib/services/registration_service.dart
class RegistrationService {
  Future<void> submitRegistration(RegistrationRequest request) async {
    await FirebaseFirestore.instance
        .collection('registrationRequests')
        .add(request.toJson());
  }
}
```

### **Step 4: Build Admin Dashboard**
- Create requests list view
- Add search and filter
- Implement approve/reject dialogs
- Add audit trail

### **Step 5: Implement Cloud Functions**
- Set up Firebase Functions project
- Install SendGrid or Firebase email extension
- Create email templates
- Implement registration functions
- Deploy functions

### **Step 6: Configure Email Service**
- Set up SendGrid account (or Firebase email extension)
- Configure API keys
- Test email delivery

### **Step 7: Add Security Rules**
```javascript
// Public can create registration requests
match /registrationRequests/{requestId} {
  allow create: if request.auth != null;
  allow read, update, delete: if isSuperAdmin();
}
```

### **Step 8: Testing**
- Test registration form validation
- Test registration submission
- Test admin notification email
- Test approval flow
- Test rejection flow
- Test welcome email
- Test trial period creation

---

## Database Updates

### **registrationRequests Collection**
Already defined in Phase 1 schema, but here's a reminder:

```javascript
{
  requestId: string,
  status: 'pending' | 'approved' | 'rejected',

  // Business info
  businessName: string,
  industry: string,
  numberOfEmployees: number,
  website?: string,

  // Owner info
  ownerName: string,
  ownerEmail: string,
  ownerPhone: string,
  jobTitle?: string,

  // Address
  address: {
    street: string,
    city: string,
    state: string,
    zip: string
  },
  timezone: string,

  // Metadata
  submittedAt: Timestamp,
  approvedAt?: Timestamp,
  approvedBy?: string (uid),
  rejectedAt?: Timestamp,
  rejectedBy?: string (uid),
  rejectionReason?: string,

  // Created company reference
  companyId?: string
}
```

---

## Email Service Options

### **Option 1: SendGrid (Recommended)**
- Free tier: 100 emails/day
- Easy API
- Reliable delivery
- Template support

**Setup:**
```bash
npm install @sendgrid/mail
```

```typescript
import sgMail from '@sendgrid/mail';
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

const msg = {
  to: 'recipient@example.com',
  from: 'noreply@chronoworks.com',
  subject: 'Subject',
  html: '<strong>Email content</strong>',
};

await sgMail.send(msg);
```

### **Option 2: Firebase Email Extension**
- Integrated with Firebase
- Uses Firestore triggers
- Good for getting started

---

## Trial Period Logic

### **On Approval:**
```typescript
const now = admin.firestore.Timestamp.now();
const trialEndDate = new Date(now.toMillis() + (30 * 24 * 60 * 60 * 1000));

const companyData = {
  // ... other fields
  currentPlan: 'trial',
  trialStartDate: now,
  trialEndDate: admin.firestore.Timestamp.fromDate(trialEndDate),
  status: 'active',
};
```

### **Trial Expiration Check:**
Will be implemented in Phase 4 (Trial Management)

---

## Next Steps After Phase 2

Once Phase 2 is complete, we'll have:
- ✅ Public registration page
- ✅ Super admin approval system
- ✅ Email notifications
- ✅ Automatic company creation
- ✅ Trial period initialization

**Then we move to Phase 3:**
- Trial expiration warnings
- Transition to Free plan (days 31-60)
- Plan selection UI
- Stripe payment integration
- Feature gating based on subscription tier

---

## Questions to Clarify

1. **Email service:** Do you have a preference for SendGrid vs Firebase Email Extension?
2. **Domain:** Do you have a domain for ChronoWorks? (for email sending: noreply@yourdomain.com)
3. **Branding:** Do you have a logo/brand colors to use in the registration page?
4. **Admin access:** Should there be multiple super admins, or just you?

Let me know and I'll start building!
