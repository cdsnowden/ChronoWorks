# ChronoWorks Admin Hierarchy & Responsibility Structure

**Last Updated**: November 2025
**Purpose**: Define roles, permissions, and responsibilities as ChronoWorks scales

---

## 🏢 Role Hierarchy Overview

```
┌─────────────────────────────────────────────────┐
│         SUPER ADMIN (Platform Owner)            │
│              Chris Snowden                       │
│      • Full platform control                     │
│      • All permissions                           │
│      • Final decision authority                  │
└─────────────────────────────────────────────────┘
                      │
    ┌─────────────────┴─────────────────┐
    │                                    │
┌───▼─────────────────────┐  ┌──────────▼──────────────────┐
│  ACCOUNT MANAGERS       │  │  TECHNICAL SUPPORT          │
│  (Customer Success)     │  │  (Platform Maintenance)     │
│  • Manage 50-100        │  │  • Bug fixes                │
│    customer accounts    │  │  • Feature updates          │
│  • Onboarding           │  │  • Server maintenance       │
│  • Tier 1 support       │  │  • Database management      │
│  • Billing issues       │  │  • Security patches         │
└─────────────────────────┘  └─────────────────────────────┘
            │
    ┌───────┴────────┐
    │                │
┌───▼──────────┐  ┌──▼──────────────┐
│ CUSTOMER     │  │ CUSTOMER         │
│ COMPANY A    │  │ COMPANY B        │
│              │  │                  │
│ • Company    │  │ • Company        │
│   Admin      │  │   Admin          │
│ • Managers   │  │ • Managers       │
│ • Employees  │  │ • Employees      │
└──────────────┘  └──────────────────┘
```

---

## 👤 Role Definitions & Permissions

### 1️⃣ **Super Admin** (Platform Owner)

**Who**: Chris Snowden (chris.s@snowdensjewelers.com)

**Database Field**:
```javascript
{
  role: 'super_admin',
  isSuperAdmin: true,
  permissions: ['all']
}
```

**Permissions**:
- ✅ **Full Platform Access**: View/edit ALL companies
- ✅ **User Management**: Create/delete account managers
- ✅ **Registration Approval**: Approve/reject new company registrations
- ✅ **Billing Override**: Manually adjust subscriptions, grant extensions
- ✅ **Analytics**: Platform-wide metrics, revenue, usage stats
- ✅ **Database Access**: Direct Firestore/Firebase Console access
- ✅ **Code Deployment**: Deploy updates, manage hosting
- ✅ **Email Templates**: Edit SendGrid templates
- ✅ **Security Rules**: Modify Firestore security rules
- ✅ **Feature Flags**: Enable/disable features globally

**Responsibilities**:
1. **Strategic Decisions**
   - Product roadmap and feature prioritization
   - Pricing changes
   - Marketing strategy
   - Hiring decisions (when to add Account Managers)

2. **Registration Approval**
   - Review new company sign-ups
   - Approve/reject based on legitimacy
   - Assign new customers to Account Managers

3. **Escalation Handling**
   - Handle complex customer issues from Account Managers
   - Resolve billing disputes
   - Major technical issues

4. **Platform Maintenance**
   - Deploy updates
   - Monitor server health
   - Database backups
   - Security audits

5. **Financial Management**
   - Revenue tracking
   - Expense monitoring
   - Subscription plan pricing
   - Payment gateway management

**Typical Time Commitment**:
- **0-50 customers**: 5-10 hours/week (mostly technical)
- **50-200 customers**: 15-20 hours/week (more management)
- **200+ customers**: Full-time role OR delegate to COO

---

### 2️⃣ **Account Manager** (Customer Success)

**Who**: To be hired as platform scales

**Database Field**:
```javascript
{
  role: 'account_manager',
  permissions: ['view_customers', 'edit_customer_settings', 'view_analytics'],
  assignedCompanies: ['companyId1', 'companyId2', ...],
  maxAssignedCompanies: 100
}
```

**Permissions**:
- ✅ **Assigned Companies Only**: View/edit only companies assigned to them
- ✅ **Customer Support**: Respond to support tickets
- ✅ **Onboarding**: Guide new customers through setup
- ✅ **Billing Support**: View invoices, process refunds (with approval)
- ✅ **Feature Training**: Teach customers how to use features
- ✅ **Analytics**: View metrics for their assigned companies
- ❌ **No Access**: Other companies, global settings, code, database

**Responsibilities**:

1. **Customer Onboarding** (First 7-14 days)
   - Welcome call/email after registration approved
   - Setup checklist:
     - Add employees
     - Create first shift template
     - Set up overtime rules
     - Test clock in/out
     - Configure notifications
   - Schedule follow-up calls (Day 3, Day 7, Day 14)

2. **Ongoing Support** (Tier 1)
   - Respond to customer emails within 4 hours
   - Answer "how do I...?" questions
   - Troubleshoot common issues:
     - Password resets
     - Employee not showing up
     - Clock in/out not working
     - Schedule conflicts
   - Escalate technical bugs to Super Admin

3. **Usage Monitoring**
   - Weekly check: Are customers actively using the platform?
   - Identify at-risk accounts (no logins in 7 days)
   - Reach out to inactive customers
   - Upsell opportunities (approaching employee limit)

4. **Billing Support**
   - Handle plan upgrade/downgrade requests
   - Process refund requests (get Super Admin approval)
   - Explain charges
   - Send payment reminders for overdue accounts

5. **Feature Requests & Feedback**
   - Collect customer feature requests
   - Document pain points
   - Report trends to Super Admin
   - Suggest product improvements

6. **Retention**
   - Monitor trial conversions (Day 30 check-ins)
   - Handle cancellation requests
   - Exit interviews (why are they leaving?)
   - Win-back campaigns for churned customers

**Key Performance Indicators (KPIs)**:
- Customer Satisfaction Score (CSAT): >4.5/5
- Response Time: <4 hours
- Trial → Paid Conversion: >40%
- Monthly Churn Rate: <5%
- Upsell Revenue: Track monthly
- Active Usage Rate: >70% of assigned accounts logging in weekly

**Typical Workload**:
- **1-25 customers**: Part-time (10-15 hrs/week)
- **25-50 customers**: Part-time (20-25 hrs/week)
- **50-100 customers**: Full-time (40 hrs/week)

**Compensation Structure** (Suggested):
- Base salary: $35-50k/year (depending on full/part-time)
- Performance bonus: 10% based on KPIs
- Upsell commission: 5-10% of upgrade revenue
- Retention bonus: $50 per customer that renews

---

### 3️⃣ **Technical Support** (Optional - Can be Super Admin initially)

**Who**: Hired when technical issues exceed Super Admin capacity

**Database Field**:
```javascript
{
  role: 'technical_support',
  permissions: ['view_all_companies', 'edit_settings', 'view_logs'],
  specializations: ['database', 'api', 'integrations']
}
```

**Permissions**:
- ✅ **View All Companies**: Read-only access to all company data
- ✅ **Edit Settings**: Change configurations to fix issues
- ✅ **View Logs**: Access Firebase Functions logs, error reports
- ✅ **Database Access**: Read/write to Firestore (limited)
- ❌ **No Access**: Billing, code deployment, security rules

**Responsibilities**:

1. **Bug Fixes & Troubleshooting**
   - Investigate technical errors reported by Account Managers
   - Reproduce bugs
   - Fix database issues (corrupted data, missing fields)
   - API integration problems (payroll exports, etc.)

2. **Platform Maintenance**
   - Monitor server uptime
   - Check Firebase quotas/limits
   - Database optimization
   - Index management
   - Performance monitoring

3. **Feature Updates**
   - Deploy non-critical updates
   - Test new features before rollout
   - Rollback if issues occur

4. **Integration Support**
   - Help customers with API setup
   - Troubleshoot payroll export issues
   - Third-party integration debugging

5. **Documentation**
   - Maintain internal knowledge base
   - Create troubleshooting guides
   - Update customer-facing docs

**When to Hire**:
- When technical support tickets exceed 10-15/week
- When Super Admin spends >50% of time on support
- Estimated at **150-200 active customers**

---

### 4️⃣ **Customer Company Admin** (Their Business)

**Who**: The business owner who registered

**Database Field**:
```javascript
{
  role: 'company_admin',
  companyId: 'xyz123',
  permissions: ['manage_employees', 'manage_schedules', 'view_reports', 'billing']
}
```

**Permissions** (Within Their Company Only):
- ✅ **Employee Management**: Add/remove employees
- ✅ **Schedule Management**: Create/edit shifts
- ✅ **Time Tracking**: View all clock ins/outs
- ✅ **Reports**: Labor costs, overtime, attendance
- ✅ **Billing**: View invoices, upgrade/downgrade plan
- ✅ **Settings**: Company info, timezone, preferences
- ❌ **No Access**: Other companies, platform settings

**Responsibilities**:
- Manage their own business operations
- Add/train their employees
- Review and approve timesheets
- Export payroll data
- Monitor overtime alerts
- Pay subscription fees

---

### 5️⃣ **Customer Manager** (Mid-level at Customer Company)

**Database Field**:
```javascript
{
  role: 'manager',
  companyId: 'xyz123',
  permissions: ['manage_schedules', 'approve_time', 'view_reports'],
  departmentId: 'sales' // optional
}
```

**Permissions** (Within Their Company Only):
- ✅ **Schedule Management**: Create/edit shifts for their department
- ✅ **Time Approval**: Approve/reject time entries
- ✅ **View Reports**: Department-level analytics
- ❌ **No Access**: Company billing, employee deletion, global settings

---

### 6️⃣ **Customer Employee** (End Users)

**Database Field**:
```javascript
{
  role: 'employee',
  companyId: 'xyz123',
  permissions: ['clock_in', 'clock_out', 'view_schedule'],
  managerId: 'manager123' // optional
}
```

**Permissions**:
- ✅ **Clock In/Out**: Track their own time
- ✅ **View Schedule**: See their shifts
- ✅ **View Timesheets**: See their own hours
- ❌ **No Access**: Other employees, schedules, reports, settings

---

## 📊 Customer Assignment Strategy

### How to Assign Companies to Account Managers

**Option 1: Geographic Assignment**
- **Account Manager 1**: East Coast companies
- **Account Manager 2**: West Coast companies
- **Benefit**: Timezone alignment for support calls

**Option 2: Industry Assignment**
- **Account Manager 1**: Restaurants, Retail, Hospitality
- **Account Manager 2**: Healthcare, Construction, Tech
- **Benefit**: Specialized industry knowledge

**Option 3: Size Assignment**
- **Account Manager 1**: Free & Starter plans (10-12 employees)
- **Account Manager 2**: Bronze & Silver plans (25-50 employees)
- **Account Manager 3**: Gold+ plans (100+ employees)
- **Benefit**: High-value customers get experienced manager

**Recommended**: **Hybrid Approach**
- Start with size-based assignment
- As you learn customer needs, adjust to industry specialization

### Reassignment Triggers
- Account Manager reaches 100 customers → Hire new AM
- High-value customer (Platinum/Diamond) → Assign to most experienced AM
- Customer requests specific manager → Accommodate if possible
- Account Manager leaving → Redistribute customers evenly

---

## 🎯 Responsibility Matrix

| Task | Super Admin | Account Manager | Tech Support | Customer Admin |
|------|-------------|-----------------|--------------|----------------|
| **Approve new registrations** | ✅ Primary | | | |
| **Assign customers to AMs** | ✅ Primary | | | |
| **Customer onboarding** | ✅ Backup | ✅ Primary | | |
| **Answer support emails** | ✅ Escalations | ✅ Primary | | |
| **Fix technical bugs** | ✅ Primary | | ✅ Primary | |
| **Process refunds** | ✅ Approve | 📝 Request | | |
| **Plan upgrades/downgrades** | | ✅ Primary | | ✅ Request |
| **Deploy code updates** | ✅ Primary | | ✅ Minor | |
| **Monitor server health** | ✅ Primary | | ✅ Primary | |
| **Revenue reporting** | ✅ Primary | 📊 View assigned | | |
| **Feature requests** | ✅ Decide | 📝 Collect | | 📝 Submit |
| **Manage employees** | | | | ✅ Primary |
| **View company analytics** | ✅ All companies | ✅ Assigned companies | ✅ All companies | ✅ Own company |

**Legend**:
- ✅ = Primary responsibility
- 📝 = Submit/Request
- 📊 = View/Monitor

---

## 🚨 Escalation Path

```
Employee → Manager → Company Admin
                           ↓
                    Account Manager
                           ↓
                    Super Admin / Tech Support
                           ↓
                    Code Fix / Database Repair
```

**Escalation Triggers**:

**Account Manager → Super Admin**:
- Customer threatening to cancel
- Refund request >$500
- Feature request mentioned by 5+ customers
- Billing dispute
- Legal/compliance question
- Technical issue beyond their expertise

**Tech Support → Super Admin**:
- Database corruption requiring manual fix
- Security vulnerability discovered
- Major bug affecting multiple customers
- Performance issue requiring infrastructure changes

**Response Time SLAs**:
- **Critical** (app down, data loss): 1 hour
- **High** (major feature broken): 4 hours
- **Medium** (minor bug, workaround exists): 24 hours
- **Low** (feature request, cosmetic issue): 1 week

---

## 📈 Scaling Timeline

### Phase 1: 0-50 Customers (Months 1-6)
**Team**:
- Super Admin (Chris) - 10-15 hrs/week
- No Account Managers yet

**Super Admin Handles**:
- All registrations
- All onboarding
- All support
- All technical issues
- All billing

**Why This Works**: Low volume, can provide white-glove service

---

### Phase 2: 50-150 Customers (Months 7-12)
**Team**:
- Super Admin (Chris) - 20-25 hrs/week
- **Hire 1st Account Manager** - Full-time

**Division of Labor**:
- Super Admin: Registrations, technical issues, platform development
- Account Manager: All onboarding, tier 1 support, billing questions

**Account Manager Profile**:
- Experience: 2+ years customer success or account management
- Skills: SaaS knowledge, excellent communication, organized
- Traits: Patient, detail-oriented, problem-solver

---

### Phase 3: 150-300 Customers (Year 2)
**Team**:
- Super Admin (Chris) - 30-40 hrs/week
- **Account Manager #1** - Full-time (100 customers)
- **Account Manager #2** - Full-time (100 customers)
- **Hire Part-time Tech Support** - 15-20 hrs/week

**Division of Labor**:
- Super Admin: Strategy, major features, escalations, hiring
- Account Managers: Divided customer base, all support
- Tech Support: Bug fixes, monitoring, minor updates

---

### Phase 4: 300-500 Customers (Year 3)
**Team**:
- **Super Admin (Chris) - Full-time CEO/CTO role**
- Account Manager #1, #2, #3 - Full-time
- Tech Support Lead - Full-time
- **Hire Marketing/Sales** - Start outbound acquisition

**Consider**:
- Customer Success Manager (manages Account Managers)
- DevOps Engineer (dedicated infrastructure)
- Product Manager (roadmap, prioritization)

---

### Phase 5: 500+ Customers (Year 4+)
**Full Company Structure**:
- CEO/Founder (Chris)
- CTO / Tech Lead
- Customer Success Director
  - 5-10 Account Managers
- Engineering Team (3-5 developers)
- Marketing/Sales Team
- Finance/Operations

---

## 🛠️ Tools & Dashboards Needed

### For Super Admin
**Dashboard Features**:
- Platform-wide metrics:
  - Total customers (active, trial, churned)
  - MRR (Monthly Recurring Revenue)
  - ARR (Annual Recurring Revenue)
  - Churn rate
  - Trial conversion rate
  - Average customer lifetime value
- Registration queue (pending approvals)
- Revenue chart (by month, by plan)
- Customer distribution (by plan, by industry, by state)
- System health (uptime, errors, API usage)
- Account Manager performance (assigned customers, CSAT scores)

**Tools**:
- Firebase Console
- Stripe Dashboard (when integrated)
- SendGrid Analytics
- Google Analytics (website traffic)
- Custom admin dashboard (build in Flutter)

---

### For Account Managers
**Dashboard Features**:
- My Customers List:
  - Company name, plan, status (active/trial), days since last login
  - Red flags (overdue payment, low usage, trial expiring soon)
- Support Ticket Queue
- Onboarding Checklist Progress (per customer)
- Usage Metrics (for assigned customers)
- Billing History (invoices, payments)
- Notes/CRM (log customer interactions)

**Tools**:
- Zendesk or Intercom (support ticketing)
- Google Sheets (customer tracking - initially)
- Slack/Email (customer communication)
- Calendly (schedule calls)
- Custom Account Manager dashboard

---

### For Customer Company Admins
**Dashboard Features**:
- Employee list
- Weekly schedule
- Time entry reports
- Overtime alerts
- Payroll export
- Subscription/billing page
- Settings

---

## 💰 Financial Planning for Staffing

### Account Manager Costs (Year 1-3)

**Year 1 (0-50 customers)**:
- Staff: Just you
- Cost: $0 additional

**Year 2 (50-150 customers)**:
- Hire Account Manager #1: $45,000/year
- Benefits (20%): $9,000
- **Total**: $54,000/year
- **Revenue Needed**: ~35-40 paying customers at avg $75/mo

**Year 3 (150-300 customers)**:
- Account Manager #1: $45,000
- Account Manager #2: $45,000
- Tech Support (PT): $30,000
- Benefits: $24,000
- **Total**: $144,000/year
- **Revenue Needed**: ~100 paying customers at avg $100/mo

**Break-even math**:
- If 50% of trial customers convert to paid
- Average paying customer: $75/month
- To afford 1 Account Manager ($54k/year = $4,500/mo)
- Need: ~60 paying customers generating $4,500/mo

---

## 🎓 Training & Onboarding for Account Managers

### Week 1: Platform Training
- Day 1-2: How the platform works (as a customer)
  - Create test company
  - Add employees
  - Create schedules
  - Clock in/out
  - Run reports
- Day 3-4: Admin tools
  - Firebase Console basics
  - How to view customer data
  - How to troubleshoot common issues
- Day 5: Shadow Super Admin
  - Watch registration approval
  - Watch customer onboarding call
  - Observe support ticket handling

### Week 2: Customer Success Training
- Day 1: Onboarding checklist walkthrough
- Day 2: Common support questions & answers
- Day 3: Billing & subscription management
- Day 4: Escalation procedures
- Day 5: First solo customer onboarding (with supervision)

### Week 3: Practice & Review
- Handle 5 test support tickets
- Complete 3 mock onboarding calls
- Review first week metrics
- Adjust processes as needed

### Ongoing Training
- Weekly team meetings (share learnings, new features)
- Monthly review of KPIs
- Quarterly training on new features

---

## 📝 Standard Operating Procedures (SOPs)

### SOP 1: New Customer Registration Approval

**Super Admin Process**:
1. Receive email: "New Registration Request"
2. Log into admin dashboard
3. Review registration details:
   - Business name (Google it - does it exist?)
   - Owner name and email (legitimate domain?)
   - Number of employees (realistic for business size?)
   - Industry (does it match business?)
4. Red flags to reject:
   - Fake business name
   - Free email (Gmail, Yahoo) with large employee count
   - Suspicious details (1000 employees for "Bob's Shop")
5. If approved:
   - Click "Approve"
   - Assign to Account Manager (if applicable)
   - Customer receives welcome email
6. If rejected:
   - Click "Reject"
   - Enter reason
   - Customer receives rejection email

**Time**: 3-5 minutes per request

---

### SOP 2: Customer Onboarding Call

**Account Manager Process**:

**Pre-Call**:
- Review customer details (industry, employee count)
- Prepare custom checklist
- Schedule 30-min Zoom call

**During Call**:
1. **Introduction** (5 min)
   - Welcome to ChronoWorks
   - Explain 30-day trial
   - Set expectations (what we'll cover today)

2. **Platform Walkthrough** (15 min)
   - Show how to add employees
   - Create first shift template
   - Demonstrate clock in/out
   - Show reporting

3. **Answer Questions** (5 min)
   - Address specific needs
   - Recommend best practices

4. **Next Steps** (5 min)
   - Send follow-up email with resources
   - Schedule Day 7 check-in
   - Provide support contact

**Post-Call**:
- Log notes in CRM
- Send follow-up email
- Set reminder for Day 7 check-in

---

### SOP 3: Support Ticket Response

**Account Manager Process**:

1. **Read Ticket** (2 min)
   - Understand the issue
   - Check customer's plan (do they have access to this feature?)

2. **Categorize** (1 min)
   - How-to question → Answer with step-by-step
   - Bug report → Test to reproduce
   - Feature request → Log in spreadsheet, thank them
   - Billing question → Check invoice, explain

3. **Respond** (10 min)
   - Clear, friendly tone
   - Step-by-step instructions
   - Screenshots if helpful
   - Offer to schedule call if complex

4. **Escalate if Needed**
   - Technical bug → Forward to Tech Support/Super Admin
   - Refund request → Ask Super Admin
   - Threat to cancel → Alert Super Admin

5. **Follow Up**
   - Mark resolved
   - Ask "Did this solve your issue?"
   - Log in customer notes

**Target Response Time**: <4 hours

---

## 🚀 Implementation Checklist

Before hiring first Account Manager, build:

- [ ] Account Manager role in database schema
- [ ] Account Manager dashboard (Flutter web)
  - [ ] View assigned customers
  - [ ] Customer details page
  - [ ] Support ticket system
  - [ ] Notes/CRM functionality
- [ ] Customer assignment system (Super Admin can assign)
- [ ] Firestore security rules (Account Managers can only see assigned companies)
- [ ] Training documentation
- [ ] SOPs documented
- [ ] Job description written
- [ ] Interview questions prepared
- [ ] Onboarding checklist created

**Estimated Dev Time**: 2-3 weeks

---

## 📞 Support Contact Structure

### Customer-Facing Channels

**Email**: support@chronoworks.com
- Managed by: Account Managers (routed to assigned AM)
- Response Time: <4 hours business hours
- Use Cases: Questions, issues, feature requests

**Phone** (Optional - Phase 3+): 1-800-CHRONO-1
- Managed by: Account Managers
- Hours: 9am-5pm EST, Monday-Friday
- Use Cases: Urgent issues, onboarding calls

**Live Chat** (Optional - Phase 4+): On chronoworks.com
- Managed by: Account Managers (rotating)
- Hours: 9am-7pm EST
- Use Cases: Quick questions

**Help Center** (Self-Service): help.chronoworks.com
- Knowledge base articles
- Video tutorials
- Reduces support volume by 30-40%

---

## ✅ Summary: Who Does What

| Customer Count | Super Admin | Account Mgrs | Tech Support |
|----------------|-------------|--------------|--------------|
| **0-50** | Everything | None | None |
| **50-150** | Strategy, tech, approvals | Onboarding, support | None |
| **150-300** | Strategy, escalations | Onboarding, support | Bugs, monitoring |
| **300-500** | CEO/CTO role | 3 AMs (100 each) | Full-time |
| **500+** | Executive leadership | CS team (5-10) | Engineering team |

---

## 🎯 Key Takeaway

**Your role evolves**:
- **Months 1-6**: Hands-on everything (builder)
- **Months 7-12**: Hybrid - still hands-on but delegating support (manager)
- **Year 2**: Strategic focus - manage team, build features (leader)
- **Year 3+**: CEO - vision, fundraising, hiring (executive)

**Start hiring when**:
- You spend >20 hours/week on support
- You have >50 active paying customers
- You're turning down customers due to lack of time
- Customer satisfaction starts dropping

---

**Next Step**: Should I start building the Account Manager dashboard and permission system now?
