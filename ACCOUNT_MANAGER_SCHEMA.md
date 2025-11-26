# Account Manager Features - Database Schema

**Phase**: Account Manager Support System
**Purpose**: Enable Account Managers to manage assigned customers

---

## 📊 New Collections

### 1. `accountManagers` Collection

Stores Account Manager profiles and their assignments.

```javascript
accountManagers/{accountManagerId}
{
  // Identity
  uid: "firebase_auth_uid",                    // Links to Firebase Auth
  email: "manager@chronoworks.com",
  displayName: "Jane Smith",
  phoneNumber: "+1234567890",                  // Optional
  photoURL: "https://...",                     // Optional

  // Role & Permissions
  role: "account_manager",
  permissions: [
    "view_assigned_customers",
    "edit_customer_settings",
    "manage_support_tickets",
    "view_analytics"
  ],

  // Customer Assignments
  assignedCompanies: [                         // Array of company IDs
    "companyId1",
    "companyId2",
    "companyId3"
  ],
  maxAssignedCompanies: 100,                   // Capacity limit

  // Performance Metrics
  metrics: {
    totalAssignedCustomers: 45,
    activeCustomers: 42,                       // Logged in last 7 days
    trialCustomers: 8,
    paidCustomers: 37,
    averageResponseTime: 2.5,                  // Hours
    customerSatisfactionScore: 4.7,            // Out of 5
    monthlyUpsellRevenue: 1250.00             // USD
  },

  // Status & Dates
  status: "active",                            // active, inactive, on_leave
  hireDate: Timestamp,
  createdAt: Timestamp,
  updatedAt: Timestamp,
  createdBy: "superAdminUid"
}
```

**Indexes**:
- `status` (ascending)
- `assignedCompanies` (array)

---

### 2. `supportTickets` Collection

Tracks customer support requests.

```javascript
supportTickets/{ticketId}
{
  // Ticket Identity
  ticketNumber: "TKT-2024-001234",             // Human-readable ID

  // Customer Info
  companyId: "xyz123",
  companyName: "Acme Corp",
  submittedBy: {
    userId: "user123",
    name: "John Doe",
    email: "john@acmecorp.com",
    role: "company_admin"
  },

  // Ticket Details
  subject: "Cannot add new employee",
  description: "When I click Add Employee, nothing happens...",
  category: "technical_issue",                 // Options below
  priority: "medium",                          // low, medium, high, urgent
  status: "open",                              // open, in_progress, waiting_on_customer, resolved, closed

  // Assignment
  assignedTo: "accountManagerId",              // Account Manager UID
  assignedToName: "Jane Smith",
  assignedAt: Timestamp,

  // Resolution
  resolution: "Fixed bug in employee creation logic...",
  resolvedAt: Timestamp,
  resolvedBy: "accountManagerId",

  // Communication History
  messages: [                                  // Thread of responses
    {
      messageId: "msg1",
      from: "userId",
      fromName: "John Doe",
      fromRole: "company_admin",
      message: "Cannot add new employee...",
      timestamp: Timestamp,
      attachments: ["url1", "url2"]            // Optional screenshots
    },
    {
      messageId: "msg2",
      from: "accountManagerId",
      fromName: "Jane Smith",
      fromRole: "account_manager",
      message: "Thanks for reporting. Can you try...",
      timestamp: Timestamp,
      attachments: []
    }
  ],

  // Metadata
  tags: ["employee_management", "bug"],
  escalatedToSuperAdmin: false,
  escalatedAt: null,
  internalNotes: "Customer using old browser version",

  // Timestamps
  createdAt: Timestamp,
  updatedAt: Timestamp,
  closedAt: Timestamp
}
```

**Category Options**:
- `technical_issue` - Bug, error, feature not working
- `how_to` - Question about using the platform
- `billing` - Payment, invoice, plan questions
- `feature_request` - Want new functionality
- `account_management` - User access, passwords
- `other` - Miscellaneous

**Indexes**:
- `companyId` + `status` (composite)
- `assignedTo` + `status` (composite)
- `status` + `priority` + `createdAt` (composite)
- `category` (ascending)

---

### 3. `customerNotes` Collection

CRM-style notes about customer interactions.

```javascript
customerNotes/{noteId}
{
  // Related To
  companyId: "xyz123",
  companyName: "Acme Corp",

  // Note Content
  note: "Customer mentioned they're planning to hire 10 more employees next month. Good opportunity for Bronze plan upgrade.",
  noteType: "interaction",                     // Options below

  // Author
  createdBy: "accountManagerId",
  createdByName: "Jane Smith",
  createdByRole: "account_manager",

  // Context
  relatedTicketId: "ticket123",                // Optional - if related to support ticket
  relatedCallId: "call456",                    // Optional - future feature

  // Tags & Categories
  tags: ["upsell_opportunity", "growth_phase"],
  sentiment: "positive",                       // positive, neutral, negative

  // Follow-up
  followUpRequired: true,
  followUpDate: Timestamp,
  followUpCompleted: false,

  // Timestamps
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

**Note Types**:
- `interaction` - General customer interaction
- `onboarding_call` - Onboarding session notes
- `support_call` - Support phone call
- `feedback` - Customer feedback/complaint
- `feature_request` - Feature request from customer
- `upsell_opportunity` - Potential upgrade
- `churn_risk` - Customer at risk of canceling
- `success_story` - Positive outcome

**Indexes**:
- `companyId` + `createdAt` (composite, descending)
- `createdBy` + `createdAt` (composite)
- `followUpRequired` + `followUpDate` (composite)

---

### 4. Updates to `companies` Collection

Add Account Manager assignment fields.

```javascript
companies/{companyId}
{
  // ... existing fields ...

  // Account Manager Assignment (NEW)
  assignedAccountManager: {
    id: "accountManagerId",
    name: "Jane Smith",
    email: "jane@chronoworks.com",
    assignedAt: Timestamp
  },

  // Customer Health Metrics (NEW)
  healthScore: 85,                             // 0-100, calculated
  healthMetrics: {
    lastLoginDate: Timestamp,
    daysSinceLastLogin: 2,
    activeEmployees: 12,
    totalEmployees: 15,
    weeklyClockIns: 156,
    monthlyClockIns: 680,
    featureAdoption: 0.75,                     // 0-1, % of features used
    paymentStatus: "current"                   // current, overdue, failed
  },

  // Support History (NEW)
  supportStats: {
    totalTickets: 8,
    openTickets: 1,
    resolvedTickets: 7,
    averageResolutionTime: 4.2,                // Hours
    lastTicketDate: Timestamp,
    customerSatisfactionAverage: 4.8
  }
}
```

---

### 5. Updates to `users` Collection

Add Account Manager role support.

```javascript
users/{userId}
{
  // ... existing fields ...

  // For Account Manager users (NEW)
  isAccountManager: true,                      // True if this user is an AM
  accountManagerProfile: "accountManagerId"    // Links to accountManagers collection
}
```

---

## 🔒 Security Rules Updates

Add Account Manager permissions to `firestore.rules`:

```javascript
// Helper function to check if user is an Account Manager
function isAccountManager() {
  return request.auth != null &&
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'account_manager';
}

// Helper function to check if Account Manager has access to a company
function accountManagerHasAccessToCompany(companyId) {
  let accountManagerDoc = get(/databases/$(database)/documents/accountManagers/$(request.auth.uid));
  return request.auth != null &&
         accountManagerDoc.data.assignedCompanies.hasAny([companyId]);
}

// Account Managers collection - only Super Admins can create/edit
match /accountManagers/{accountManagerId} {
  allow read: if isSuperAdmin() || request.auth.uid == accountManagerId;
  allow create, update, delete: if isSuperAdmin();
}

// Support Tickets collection
match /supportTickets/{ticketId} {
  allow create: if isAuthenticated() && belongsToSameCompany(resource.data.companyId);
  allow read: if isSuperAdmin() ||
                 belongsToSameCompany(resource.data.companyId) ||
                 accountManagerHasAccessToCompany(resource.data.companyId);
  allow update: if isSuperAdmin() ||
                   accountManagerHasAccessToCompany(resource.data.companyId);
  allow delete: if isSuperAdmin();
}

// Customer Notes collection
match /customerNotes/{noteId} {
  allow create: if isSuperAdmin() ||
                   (isAccountManager() && accountManagerHasAccessToCompany(request.resource.data.companyId));
  allow read: if isSuperAdmin() ||
                 belongsToSameCompany(resource.data.companyId) ||
                 accountManagerHasAccessToCompany(resource.data.companyId);
  allow update, delete: if isSuperAdmin() ||
                           request.auth.uid == resource.data.createdBy;
}

// Companies collection - Account Managers can read assigned companies
match /companies/{companyId} {
  allow read: if isSuperAdmin() ||
                 belongsToSameCompany(companyId) ||
                 accountManagerHasAccessToCompany(companyId);
  allow update: if isSuperAdmin() ||
                   (belongsToSameCompany(companyId) && hasRole('company_admin'));
  allow create, delete: if isSuperAdmin();
}

// Users collection - Account Managers can view users from assigned companies
match /users/{userId} {
  allow read: if isSuperAdmin() ||
                 request.auth.uid == userId ||
                 belongsToSameCompany(resource.data.companyId) ||
                 accountManagerHasAccessToCompany(resource.data.companyId);
  allow update: if isSuperAdmin() ||
                   request.auth.uid == userId ||
                   (belongsToSameCompany(resource.data.companyId) && hasRole('company_admin'));
  allow create, delete: if isSuperAdmin();
}

// Shifts, timeEntries, etc. - Account Managers can view for assigned companies
match /shifts/{shiftId} {
  allow read: if isSuperAdmin() ||
                 belongsToSameCompany(resource.data.companyId) ||
                 accountManagerHasAccessToCompany(resource.data.companyId);
  allow write: if isSuperAdmin() ||
                  (belongsToSameCompany(resource.data.companyId) && hasRole(['company_admin', 'manager']));
}

// Similar rules for timeEntries, activeClockIns, etc.
```

---

## 📱 Flutter Models

### Account Manager Model

```dart
// lib/models/account_manager.dart
class AccountManager {
  final String id;
  final String uid;
  final String email;
  final String displayName;
  final String? phoneNumber;
  final String? photoURL;
  final String role;
  final List<String> permissions;
  final List<String> assignedCompanies;
  final int maxAssignedCompanies;
  final AccountManagerMetrics? metrics;
  final String status;
  final DateTime? hireDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  AccountManager({
    required this.id,
    required this.uid,
    required this.email,
    required this.displayName,
    this.phoneNumber,
    this.photoURL,
    required this.role,
    required this.permissions,
    required this.assignedCompanies,
    required this.maxAssignedCompanies,
    this.metrics,
    required this.status,
    this.hireDate,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory AccountManager.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AccountManager(
      id: doc.id,
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      phoneNumber: data['phoneNumber'],
      photoURL: data['photoURL'],
      role: data['role'] ?? 'account_manager',
      permissions: List<String>.from(data['permissions'] ?? []),
      assignedCompanies: List<String>.from(data['assignedCompanies'] ?? []),
      maxAssignedCompanies: data['maxAssignedCompanies'] ?? 100,
      metrics: data['metrics'] != null
          ? AccountManagerMetrics.fromMap(data['metrics'])
          : null,
      status: data['status'] ?? 'active',
      hireDate: data['hireDate']?.toDate(),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'role': role,
      'permissions': permissions,
      'assignedCompanies': assignedCompanies,
      'maxAssignedCompanies': maxAssignedCompanies,
      'metrics': metrics?.toMap(),
      'status': status,
      'hireDate': hireDate != null ? Timestamp.fromDate(hireDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'createdBy': createdBy,
    };
  }
}

class AccountManagerMetrics {
  final int totalAssignedCustomers;
  final int activeCustomers;
  final int trialCustomers;
  final int paidCustomers;
  final double averageResponseTime;
  final double customerSatisfactionScore;
  final double monthlyUpsellRevenue;

  AccountManagerMetrics({
    required this.totalAssignedCustomers,
    required this.activeCustomers,
    required this.trialCustomers,
    required this.paidCustomers,
    required this.averageResponseTime,
    required this.customerSatisfactionScore,
    required this.monthlyUpsellRevenue,
  });

  factory AccountManagerMetrics.fromMap(Map<String, dynamic> map) {
    return AccountManagerMetrics(
      totalAssignedCustomers: map['totalAssignedCustomers'] ?? 0,
      activeCustomers: map['activeCustomers'] ?? 0,
      trialCustomers: map['trialCustomers'] ?? 0,
      paidCustomers: map['paidCustomers'] ?? 0,
      averageResponseTime: (map['averageResponseTime'] ?? 0).toDouble(),
      customerSatisfactionScore: (map['customerSatisfactionScore'] ?? 0).toDouble(),
      monthlyUpsellRevenue: (map['monthlyUpsellRevenue'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalAssignedCustomers': totalAssignedCustomers,
      'activeCustomers': activeCustomers,
      'trialCustomers': trialCustomers,
      'paidCustomers': paidCustomers,
      'averageResponseTime': averageResponseTime,
      'customerSatisfactionScore': customerSatisfactionScore,
      'monthlyUpsellRevenue': monthlyUpsellRevenue,
    };
  }
}
```

### Support Ticket Model

```dart
// lib/models/support_ticket.dart
class SupportTicket {
  final String id;
  final String ticketNumber;
  final String companyId;
  final String companyName;
  final TicketSubmitter submittedBy;
  final String subject;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String? assignedTo;
  final String? assignedToName;
  final DateTime? assignedAt;
  final String? resolution;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final List<TicketMessage> messages;
  final List<String> tags;
  final bool escalatedToSuperAdmin;
  final DateTime? escalatedAt;
  final String? internalNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;

  SupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.companyId,
    required this.companyName,
    required this.submittedBy,
    required this.subject,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.assignedTo,
    this.assignedToName,
    this.assignedAt,
    this.resolution,
    this.resolvedAt,
    this.resolvedBy,
    required this.messages,
    required this.tags,
    required this.escalatedToSuperAdmin,
    this.escalatedAt,
    this.internalNotes,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
  });

  factory SupportTicket.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SupportTicket(
      id: doc.id,
      ticketNumber: data['ticketNumber'] ?? '',
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      submittedBy: TicketSubmitter.fromMap(data['submittedBy'] ?? {}),
      subject: data['subject'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'other',
      priority: data['priority'] ?? 'medium',
      status: data['status'] ?? 'open',
      assignedTo: data['assignedTo'],
      assignedToName: data['assignedToName'],
      assignedAt: data['assignedAt']?.toDate(),
      resolution: data['resolution'],
      resolvedAt: data['resolvedAt']?.toDate(),
      resolvedBy: data['resolvedBy'],
      messages: (data['messages'] as List?)
          ?.map((m) => TicketMessage.fromMap(m))
          .toList() ?? [],
      tags: List<String>.from(data['tags'] ?? []),
      escalatedToSuperAdmin: data['escalatedToSuperAdmin'] ?? false,
      escalatedAt: data['escalatedAt']?.toDate(),
      internalNotes: data['internalNotes'],
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
      closedAt: data['closedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ticketNumber': ticketNumber,
      'companyId': companyId,
      'companyName': companyName,
      'submittedBy': submittedBy.toMap(),
      'subject': subject,
      'description': description,
      'category': category,
      'priority': priority,
      'status': status,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'resolution': resolution,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolvedBy': resolvedBy,
      'messages': messages.map((m) => m.toMap()).toList(),
      'tags': tags,
      'escalatedToSuperAdmin': escalatedToSuperAdmin,
      'escalatedAt': escalatedAt != null ? Timestamp.fromDate(escalatedAt!) : null,
      'internalNotes': internalNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
    };
  }
}

class TicketSubmitter {
  final String userId;
  final String name;
  final String email;
  final String role;

  TicketSubmitter({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
  });

  factory TicketSubmitter.fromMap(Map<String, dynamic> map) {
    return TicketSubmitter(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'role': role,
    };
  }
}

class TicketMessage {
  final String messageId;
  final String from;
  final String fromName;
  final String fromRole;
  final String message;
  final DateTime timestamp;
  final List<String> attachments;

  TicketMessage({
    required this.messageId,
    required this.from,
    required this.fromName,
    required this.fromRole,
    required this.message,
    required this.timestamp,
    required this.attachments,
  });

  factory TicketMessage.fromMap(Map<String, dynamic> map) {
    return TicketMessage(
      messageId: map['messageId'] ?? '',
      from: map['from'] ?? '',
      fromName: map['fromName'] ?? '',
      fromRole: map['fromRole'] ?? '',
      message: map['message'] ?? '',
      timestamp: map['timestamp']?.toDate() ?? DateTime.now(),
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'from': from,
      'fromName': fromName,
      'fromRole': fromRole,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'attachments': attachments,
    };
  }
}
```

### Customer Note Model

```dart
// lib/models/customer_note.dart
class CustomerNote {
  final String id;
  final String companyId;
  final String companyName;
  final String note;
  final String noteType;
  final String createdBy;
  final String createdByName;
  final String createdByRole;
  final String? relatedTicketId;
  final List<String> tags;
  final String sentiment;
  final bool followUpRequired;
  final DateTime? followUpDate;
  final bool followUpCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerNote({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.note,
    required this.noteType,
    required this.createdBy,
    required this.createdByName,
    required this.createdByRole,
    this.relatedTicketId,
    required this.tags,
    required this.sentiment,
    required this.followUpRequired,
    this.followUpDate,
    required this.followUpCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerNote.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CustomerNote(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      note: data['note'] ?? '',
      noteType: data['noteType'] ?? 'interaction',
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      createdByRole: data['createdByRole'] ?? '',
      relatedTicketId: data['relatedTicketId'],
      tags: List<String>.from(data['tags'] ?? []),
      sentiment: data['sentiment'] ?? 'neutral',
      followUpRequired: data['followUpRequired'] ?? false,
      followUpDate: data['followUpDate']?.toDate(),
      followUpCompleted: data['followUpCompleted'] ?? false,
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'note': note,
      'noteType': noteType,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdByRole': createdByRole,
      'relatedTicketId': relatedTicketId,
      'tags': tags,
      'sentiment': sentiment,
      'followUpRequired': followUpRequired,
      'followUpDate': followUpDate != null ? Timestamp.fromDate(followUpDate!) : null,
      'followUpCompleted': followUpCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }
}
```

---

## 🚀 Implementation Order

1. **Update database schema** - Add collections
2. **Update security rules** - Deploy new rules
3. **Create Flutter models** - AccountManager, SupportTicket, CustomerNote
4. **Build services** - AccountManagerService, TicketService, NotesService
5. **Build UI screens**:
   - Account Manager Dashboard
   - Customer Assignment page (Super Admin)
   - Support Ticket list and detail pages
   - Customer Notes page
6. **Test everything** - Create test Account Manager, assign customers, test tickets

---

Ready to start building?
