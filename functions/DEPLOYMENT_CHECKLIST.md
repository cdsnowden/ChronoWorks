# Missed Clock-Out Alerts - Deployment Checklist

Use this checklist to ensure successful deployment of the automated warning system.

---

## Pre-Deployment Setup

### 1. SendGrid Account Setup
- [ ] Create SendGrid account at https://sendgrid.com/
- [ ] Verify your email address in SendGrid
- [ ] Create API key with "Mail Send" permissions
- [ ] Copy API key (you won't see it again!)
- [ ] Choose sender email (e.g., noreply@yourdomain.com)

### 2. Local Environment Setup
- [ ] Navigate to functions directory: `cd C:\Users\chris\ChronoWorks\functions`
- [ ] Install dependencies: `npm install`
- [ ] Create `.env` file from template: `cp .env.example .env`
- [ ] Edit `.env` file with your actual credentials
- [ ] Add your test email to `.env` file

### 3. Test Configuration (IMPORTANT!)
- [ ] Run test script: `npm run test:email`
- [ ] Check inbox for test email
- [ ] Verify email formatting looks correct
- [ ] Check spam folder if email not received
- [ ] Confirm SendGrid dashboard shows email sent

**⚠️ DO NOT PROCEED if test email fails! Fix issues first.**

---

## Firebase Configuration

### 4. Set Environment Variables
```bash
# Run these commands:
firebase functions:config:set sendgrid.api_key="YOUR_SENDGRID_API_KEY"
firebase functions:config:set sendgrid.from_email="noreply@yourdomain.com"
```

- [ ] Run `firebase functions:config:set` commands above
- [ ] Verify configuration: `firebase functions:config:get`
- [ ] Confirm both `sendgrid.api_key` and `sendgrid.from_email` are set

### 5. Review Function Settings (Optional)
- [ ] Open `checkMissedClockOuts.js`
- [ ] Check grace period (default: 45 minutes) - Line ~305
- [ ] Check schedule frequency (default: every 15 minutes) - Line ~310
- [ ] Check timezone (default: America/New_York) - Line ~311
- [ ] Modify if needed, save changes

---

## Deployment

### 6. Deploy Function
```bash
# Deploy only the new function:
firebase deploy --only functions:checkMissedClockOuts

# OR deploy all functions:
firebase deploy --only functions
```

- [ ] Run deployment command
- [ ] Wait for deployment to complete (may take 2-5 minutes)
- [ ] Check for any errors in output
- [ ] Note the function URL from deployment output

### 7. Verify Deployment
- [ ] Open Firebase Console: https://console.firebase.google.com/
- [ ] Navigate to your project
- [ ] Click "Functions" in left sidebar
- [ ] Find `checkMissedClockOuts` in function list
- [ ] Verify status shows "Active" (green)
- [ ] Check "Trigger" shows "Scheduled"
- [ ] Check "Schedule" shows "every 15 minutes"

---

## Post-Deployment Verification

### 8. Check Function Logs
```bash
# View logs in real-time:
firebase functions:log --only checkMissedClockOuts

# OR view in Firebase Console:
# Functions > checkMissedClockOuts > Logs tab
```

- [ ] Wait for next scheduled run (up to 15 minutes)
- [ ] Check logs show function executed
- [ ] Verify no error messages
- [ ] Confirm log shows "Starting missed clock-out check..."

### 9. Verify Firestore Access
- [ ] Open Firebase Console > Firestore
- [ ] Check `activeClockIns` collection exists
- [ ] Check `shifts` collection exists
- [ ] Check `users` collection exists
- [ ] Verify at least one admin user has email address
- [ ] Verify admin user has `role: "admin"` and `isActive: true`

### 10. Test with Real Data (Optional but Recommended)
- [ ] Clock in a test employee
- [ ] Create/modify shift to end 50 minutes ago
- [ ] Wait for next scheduled function run (up to 15 minutes)
- [ ] Check logs for processing of test employee
- [ ] Verify email received by employee
- [ ] Verify email received by manager (if assigned)
- [ ] Verify email received by admins
- [ ] Check `missedClockOutWarnings` collection for new document
- [ ] Clean up test data if needed

---

## Monitoring Setup

### 11. Set Up Regular Monitoring
- [ ] Bookmark Firebase Console functions page
- [ ] Bookmark SendGrid dashboard
- [ ] Add reminder to check logs weekly
- [ ] Document any customizations made
- [ ] Share deployment status with team

### 12. Create Monitoring Schedule
- [ ] **Daily**: Quick check for critical errors (first week)
- [ ] **Weekly**: Review function logs and email delivery
- [ ] **Monthly**: Analyze warning patterns and adjust if needed
- [ ] **Quarterly**: Review costs and performance metrics

---

## Team Communication

### 13. Notify Stakeholders
- [ ] Inform admins about new automated system
- [ ] Explain what emails to expect
- [ ] Provide contact for technical issues
- [ ] Share quick reference guide (`MISSED_CLOCKOUT_ALERTS_QUICKSTART.md`)
- [ ] Set expectations for response times

### 14. Update Internal Documentation
- [ ] Add system to IT documentation
- [ ] Document SendGrid account ownership
- [ ] Document Firebase project access
- [ ] Create runbook for common issues
- [ ] Add to onboarding materials for new admins

---

## Rollback Plan (If Needed)

### 15. Know How to Rollback
If issues arise, you can disable or remove the function:

```bash
# Option 1: Delete the function
firebase functions:delete checkMissedClockOuts

# Option 2: Rollback via Firebase Console
# Functions > checkMissedClockOuts > ... menu > Rollback
```

- [ ] Understand rollback procedure
- [ ] Know who to contact for help
- [ ] Have backup plan for manual monitoring

---

## Success Criteria

### Before Marking Complete, Verify:
- [x] All pre-deployment setup completed
- [x] Test email sent and received successfully
- [x] Function deployed without errors
- [x] Function shows "Active" in Firebase Console
- [x] Function logs show successful execution
- [x] Firestore collections accessible
- [x] At least one successful test (real or simulated)
- [x] Team notified of new system
- [x] Monitoring schedule established

---

## Troubleshooting Reference

### Common Issues

**Issue: Test email not received**
- ✓ Check spam/junk folder
- ✓ Verify sender email in SendGrid dashboard
- ✓ Check SendGrid activity feed
- ✓ Verify API key has "Mail Send" permission

**Issue: Function not deploying**
- ✓ Check Firebase CLI is logged in: `firebase login`
- ✓ Verify correct project selected: `firebase use`
- ✓ Check for syntax errors in code
- ✓ Verify all dependencies installed: `npm install`

**Issue: Function deployed but not running**
- ✓ Check Cloud Scheduler is enabled in Google Cloud Console
- ✓ Verify function region matches expectation
- ✓ Check quota limits not exceeded
- ✓ Review function logs for errors

**Issue: Emails not sending in production**
- ✓ Verify config set correctly: `firebase functions:config:get`
- ✓ Check SendGrid account not suspended
- ✓ Verify sender email is verified
- ✓ Check function logs for SendGrid errors
- ✓ Verify recipient email addresses valid

---

## Documentation References

- **Full Documentation**: `functions/README.md`
- **Deployment Guide**: `functions/DEPLOYMENT_GUIDE.md`
- **Quick Reference**: `functions/MISSED_CLOCKOUT_ALERTS_QUICKSTART.md`
- **Architecture**: `functions/SYSTEM_ARCHITECTURE.md`
- **Implementation Summary**: `IMPLEMENTATION_SUMMARY.md`

---

## Sign-Off

### Deployment Completed By:
- **Name:** ________________
- **Date:** ________________
- **Signature:** ________________

### Verified By:
- **Name:** ________________
- **Date:** ________________
- **Signature:** ________________

### Notes:
```
Add any deployment notes, issues encountered, or customizations made:




```

---

## Next Review Date: ________________

**Status:** ⬜ Pending | ⬜ In Progress | ⬜ Complete | ⬜ Issues

---

**Congratulations! 🎉**

Once all items are checked, your automated missed clock-out warning system is live and monitoring your employees 24/7.

The system will now:
- ✅ Check every 15 minutes for missed clock-outs
- ✅ Send professional email alerts automatically
- ✅ Track all warnings in Firestore
- ✅ Help maintain accurate time tracking

**Remember:** Monitor the system regularly, especially in the first week, to ensure everything is working as expected.
