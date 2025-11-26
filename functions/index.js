const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Import additional functions
const {checkMissedClockOuts} = require("./checkMissedClockOuts");
const {monitorOvertimeRisk, checkOvertimeOnClockEvent} = require("./monitorOvertimeRisk");
const {
  onRegistrationSubmitted,
  approveRegistration,
  rejectRegistration,
} = require("./registrationFunctions");
const {
  checkFreePhase1Expirations,
  checkFreePhase2Expirations,
} = require("./freeAccountManagementFunctions");
const {
  detectAtRiskAccounts,
  notifyAccountManagers,
  updateRetentionTask,
  getRetentionDashboard,
} = require("./retentionManagementFunctions");

// Phase 4 - Subscription Management Functions
const {
  changePlan,
  cancelScheduledChange,
  getUpgradePreview,
} = require("./subscriptionManagementFunctions");

// Account Manager Functions
const {
  createAccountManager,
} = require("./accountManagerFunctions");

// Time-Off Notification Functions
const {
  onTimeOffRequestCreated,
  onTimeOffRequestUpdated,
} = require("./timeOffNotificationFunctions");

// Temporary cleanup function
const {
  deleteAllUsersExcept,
} = require("./deleteAllUsersExcept");

// Twilio configuration - Set these using Firebase Functions config
// firebase functions:config:set twilio.account_sid="YOUR_ACCOUNT_SID"
// firebase functions:config:set twilio.auth_token="YOUR_AUTH_TOKEN"
// firebase functions:config:set twilio.phone_number="YOUR_TWILIO_PHONE_NUMBER"

/**
 * Cloud Function that triggers when a new overtime request is created
 * Sends SMS notification to all admin users
 */
exports.notifyAdminsOfOvertime = onDocumentCreated(
    {
      document: "overtimeRequests/{requestId}",
      region: "us-central1",
    },
    async (event) => {
      try {
        const overtimeRequest = event.data.data();
        const requestId = event.params.requestId;

        logger.info(`Processing overtime request: ${requestId}`);

        // Get Twilio credentials from environment config
        // For local testing, you can use process.env.TWILIO_ACCOUNT_SID
        const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID;
        const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN;
        const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER;

        if (!twilioAccountSid || !twilioAuthToken || !twilioPhoneNumber) {
          logger.error("Twilio credentials not configured");
          throw new Error("Twilio credentials not configured. " +
            "Run: firebase functions:config:set twilio.account_sid=XXX " +
            "twilio.auth_token=XXX twilio.phone_number=XXX");
        }

        // Initialize Twilio client
        const twilio = require("twilio")(twilioAccountSid, twilioAuthToken);

        // Get all admin users with phone numbers
        const usersSnapshot = await admin.firestore()
            .collection("users")
            .where("role", "==", "admin")
            .get();

        const adminsWithPhones = [];
        usersSnapshot.forEach((doc) => {
          const user = doc.data();
          if (user.phoneNumber && user.phoneNumber.trim() !== "") {
            adminsWithPhones.push({
              id: doc.id,
              name: `${user.firstName} ${user.lastName}`,
              phone: user.phoneNumber,
            });
          }
        });

        if (adminsWithPhones.length === 0) {
          logger.warn("No admin users with phone numbers found");
          return {
            success: false,
            message: "No admins with phone numbers",
          };
        }

        // Format overtime information
        const {
          employeeName,
          managerName,
          overtimeHours,
          projectedWeeklyHours,
        } = overtimeRequest;

        const message = `ChronoWorks Overtime Alert!\n\n` +
          `Employee: ${employeeName}\n` +
          `Manager: ${managerName}\n` +
          `Overtime: ${overtimeHours.toFixed(1)} hrs\n` +
          `Weekly Total: ${projectedWeeklyHours.toFixed(1)} hrs\n\n` +
          `Approval required in ChronoWorks app.`;

        // Send SMS to all admins
        const smsResults = [];
        for (const admin of adminsWithPhones) {
          try {
            const result = await twilio.messages.create({
              body: message,
              to: admin.phone,
              from: twilioPhoneNumber,
            });

            logger.info(`SMS sent to ${admin.name} (${admin.phone}): ${result.sid}`);
            smsResults.push({
              admin: admin.name,
              phone: admin.phone,
              status: "sent",
              sid: result.sid,
            });
          } catch (error) {
            logger.error(`Failed to send SMS to ${admin.name}: ${error.message}`);
            smsResults.push({
              admin: admin.name,
              phone: admin.phone,
              status: "failed",
              error: error.message,
            });
          }
        }

        // Mark overtime request as notified
        await admin.firestore()
            .collection("overtimeRequests")
            .doc(requestId)
            .update({
              smsNotificationSent: true,
              smsNotificationResults: smsResults,
              smsNotificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
            });

        logger.info(`Overtime notification complete for request ${requestId}`);

        return {
          success: true,
          requestId: requestId,
          adminCount: adminsWithPhones.length,
          results: smsResults,
        };
      } catch (error) {
        logger.error(`Error in notifyAdminsOfOvertime: ${error.message}`, error);
        throw error;
      }
    }
);

/**
 * Temporary HTTP function to clear overtime notification records for testing
 * Call this endpoint to allow notifications to be sent again
 */
exports.clearOvertimeNotifications = onRequest(
    {
      region: "us-central1",
      cors: true,
    },
    async (req, res) => {
      try {
        logger.info("Clearing overtime notification records...");

        const notificationsSnapshot = await admin.firestore()
            .collection("overtimeRiskNotifications")
            .get();

        logger.info(`Found ${notificationsSnapshot.size} notification records`);

        if (notificationsSnapshot.empty) {
          logger.info("No notification records to delete");
          res.status(200).json({
            success: true,
            message: "No notification records found",
            deleted: 0,
          });
          return;
        }

        const deletePromises = notificationsSnapshot.docs.map((doc) => {
          const data = doc.data();
          logger.info(`Deleting: ${doc.id} - Employee: ${data.employeeId}`);
          return doc.ref.delete();
        });

        await Promise.all(deletePromises);

        logger.info(`Deleted ${notificationsSnapshot.size} notification records`);

        res.status(200).json({
          success: true,
          message: "Notification records cleared successfully",
          deleted: notificationsSnapshot.size,
        });
      } catch (error) {
        logger.error("Error clearing notifications:", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    }
);

/**
 * HTTP function to check admin email addresses
 * Returns all admin users and their email addresses for debugging
 */
exports.checkAdminEmails = onRequest(
    {
      region: "us-central1",
      cors: true,
    },
    async (req, res) => {
      try {
        logger.info("Checking admin email addresses...");

        // Get all admin users
        const adminsSnapshot = await admin.firestore()
            .collection("users")
            .where("role", "==", "admin")
            .get();

        const admins = [];
        adminsSnapshot.forEach((doc) => {
          const data = doc.data();
          admins.push({
            id: doc.id,
            name: data.fullName || `${data.firstName} ${data.lastName}`,
            email: data.email,
            phoneNumber: data.phoneNumber || "N/A",
          });
        });

        // Also check John Smith's email
        const johnSmithSnapshot = await admin.firestore()
            .collection("users")
            .where("firstName", "==", "John")
            .where("lastName", "==", "Smith")
            .get();

        const johnSmith = [];
        johnSmithSnapshot.forEach((doc) => {
          const data = doc.data();
          johnSmith.push({
            id: doc.id,
            name: `${data.firstName} ${data.lastName}`,
            email: data.email,
            role: data.role,
            phoneNumber: data.phoneNumber || "N/A",
          });
        });

        logger.info(`Found ${admins.length} admin users`);

        res.status(200).json({
          success: true,
          admins: admins,
          johnSmith: johnSmith,
          totalAdmins: admins.length,
        });
      } catch (error) {
        logger.error("Error checking admin emails:", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    }
);

// Export scheduled function for checking missed clock-outs
exports.checkMissedClockOuts = checkMissedClockOuts;

/**
 * HTTP function to create test overtime risk data for John Smith
 * This creates a properly formatted overtime risk record for testing
 */
exports.createTestOvertimeRisk = onRequest(
    {
      region: "us-central1",
      cors: true,
    },
    async (req, res) => {
      try {
        logger.info("Creating test overtime risk data...");

        // Get John Smith's user data
        const johnSmithSnapshot = await admin.firestore()
            .collection("users")
            .where("firstName", "==", "John")
            .where("lastName", "==", "Smith")
            .get();

        if (johnSmithSnapshot.empty) {
          res.status(404).json({
            success: false,
            error: "John Smith not found in users collection",
          });
          return;
        }

        const johnSmithDoc = johnSmithSnapshot.docs[0];
        const userId = johnSmithDoc.id;
        const userData = johnSmithDoc.data();

        logger.info(`Found John Smith: ${userId}`);

        // Use current date/time to ensure it falls within the current week
        // regardless of timezone differences between Cloud Functions (UTC) and Dart app (local)
        const now = new Date();

        // Create overtime risk notification with complete data structure
        const riskData = {
          employeeId: userId,
          employeeName: `${userData.firstName} ${userData.lastName}`,
          riskLevel: "critical",
          projectedHours: 42.5,
          overtimeHours: 2.5,
          date: admin.firestore.Timestamp.fromDate(now),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        const docRef = await admin.firestore()
            .collection("overtimeRiskNotifications")
            .add(riskData);

        logger.info(`Created overtime risk notification: ${docRef.id}`);

        res.status(200).json({
          success: true,
          message: "Test overtime risk created successfully",
          documentId: docRef.id,
          employeeName: riskData.employeeName,
          riskLevel: riskData.riskLevel,
          projectedHours: riskData.projectedHours,
          overtimeHours: riskData.overtimeHours,
        });
      } catch (error) {
        logger.error("Error creating test overtime risk:", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    }
);

/**
 * HTTP function to list all overtime risk notifications for debugging
 * Shows exactly what data exists in Firestore
 */
exports.listOvertimeRisks = onRequest(
    {
      region: "us-central1",
      cors: true,
    },
    async (req, res) => {
      try {
        logger.info("Listing all overtime risk notifications...");

        const snapshot = await admin.firestore()
            .collection("overtimeRiskNotifications")
            .get();

        logger.info(`Found ${snapshot.size} overtime risk notifications`);

        const risks = [];
        snapshot.forEach((doc) => {
          const data = doc.data();
          risks.push({
            id: doc.id,
            employeeId: data.employeeId,
            employeeName: data.employeeName,
            riskLevel: data.riskLevel,
            projectedHours: data.projectedHours,
            overtimeHours: data.overtimeHours,
            date: data.date?.toDate().toISOString(),
            createdAt: data.createdAt?.toDate().toISOString(),
          });
        });

        // Calculate current week start for comparison
        const now = new Date();
        const weekStart = new Date(now);
        weekStart.setDate(now.getDate() - (now.getDay() % 7));
        weekStart.setHours(0, 0, 0, 0);

        res.status(200).json({
          success: true,
          totalRecords: snapshot.size,
          currentWeekStart: weekStart.toISOString(),
          risks: risks,
        });
      } catch (error) {
        logger.error("Error listing overtime risks:", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    }
);

// Export overtime risk monitoring functions
exports.monitorOvertimeRisk = monitorOvertimeRisk;
exports.checkOvertimeOnClockEvent = checkOvertimeOnClockEvent;

// Export Phase 2 registration functions
exports.onRegistrationSubmitted = onRegistrationSubmitted;
exports.approveRegistration = approveRegistration;
exports.rejectRegistration = rejectRegistration;

// Export Phase 3 free account management functions
exports.checkFreePhase1Expirations = checkFreePhase1Expirations;
exports.checkFreePhase2Expirations = checkFreePhase2Expirations;

// Export Phase 3B retention management functions
exports.detectAtRiskAccounts = detectAtRiskAccounts;
exports.notifyAccountManagers = notifyAccountManagers;
exports.updateRetentionTask = updateRetentionTask;
exports.getRetentionDashboard = getRetentionDashboard;

// Export Account Manager functions
exports.createAccountManager = createAccountManager;

// Export Time-Off Notification functions
exports.onTimeOffRequestCreated = onTimeOffRequestCreated;
exports.onTimeOffRequestUpdated = onTimeOffRequestUpdated;

// Export temporary cleanup function (DELETE after use)
exports.deleteAllUsersExcept = deleteAllUsersExcept;

// Export Phase 4 subscription management functions
exports.changePlan = changePlan;
exports.cancelScheduledChange = cancelScheduledChange;
exports.getUpgradePreview = getUpgradePreview;

/**
 * Sends subscription management email to company owner
 * Called by Account Managers from the Flutter app
 * Generates token, creates URL, and emails customer
 */
exports.sendSubscriptionManagementEmail = onRequest(
    {
      region: "us-central1",
      cors: true,
    },
    async (req, res) => {
      try {
        // Verify this is a POST request
        if (req.method !== "POST") {
          res.status(405).json({
            success: false,
            error: "Method not allowed. Use POST.",
          });
          return;
        }

        const {companyId, accountManagerId} = req.body;

        if (!companyId || !accountManagerId) {
          res.status(400).json({
            success: false,
            error: "Missing required parameters: companyId and accountManagerId",
          });
          return;
        }

        logger.info(`Processing subscription email request for company: ${companyId}`);

        // Get company data
        const companyDoc = await admin.firestore()
            .collection("companies")
            .doc(companyId)
            .get();

        if (!companyDoc.exists) {
          res.status(404).json({
            success: false,
            error: "Company not found",
          });
          return;
        }

        const companyData = companyDoc.data();

        // Get owner email and name
        const ownerEmail = companyData.ownerEmail;
        const ownerName = companyData.ownerName;
        const companyName = companyData.businessName;

        if (!ownerEmail || !ownerName) {
          res.status(400).json({
            success: false,
            error: "Company missing owner email or name",
          });
          return;
        }

        // Generate subscription token (valid for 72 hours)
        const token = _generateSecureToken();
        const now = admin.firestore.Timestamp.now();
        const expiresAt = admin.firestore.Timestamp.fromMillis(
            now.toMillis() + (72 * 60 * 60 * 1000) // 72 hours
        );

        // Save token to Firestore
        await admin.firestore()
            .collection("subscriptionChangeTokens")
            .doc(token)
            .set({
              token: token,
              companyId: companyId,
              createdBy: accountManagerId,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              expiresAt: expiresAt,
              used: false,
              usedAt: null,
              usedBy: null,
            });

        // Generate management URL
        // TODO: Replace with actual production domain
        const managementUrl = `https://chronoworks.com/subscription/manage?token=${token}`;

        // Send email using SendGrid
        const {sendSubscriptionManagementEmail: sendEmail} = require("./emailService");
        await sendEmail({
          toEmail: ownerEmail,
          toName: ownerName,
          companyName: companyName,
          managementUrl: managementUrl,
          expiresInHours: 72,
        });

        logger.info(`Subscription management email sent to ${ownerEmail}`);

        res.status(200).json({
          success: true,
          message: "Email sent successfully",
          url: managementUrl,
          expiresAt: expiresAt.toDate().toISOString(),
        });
      } catch (error) {
        logger.error("Error sending subscription management email:", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    }
);

/**
 * Helper function to generate secure random token
 * @return {string} - 32-character random token
 */
function _generateSecureToken() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let token = "";
  const randomValues = new Uint8Array(32);
  require("crypto").randomFillSync(randomValues);
  for (let i = 0; i < 32; i++) {
    token += chars[randomValues[i] % chars.length];
  }
  return token;
}

/**
 * TESTING ONLY: Manual trigger for trial expiration check
 * DELETE after Phase 3 testing is complete
 */
exports.testTrialExpirations = onRequest(
    {
      region: "us-central1",
      cors: true,
    },
    async (req, res) => {
      try {
        logger.info("=== Manual Test: Trial Expiration Check ===");

        const {
          sendTrialWarningEmail,
          sendTrialExpiredEmail,
        } = require("./emailService");

        const now = admin.firestore.Timestamp.now();
        const today = new Date(now.toMillis());
        const threeDaysFromNow = new Date(today);
        threeDaysFromNow.setDate(today.getDate() + 3);
        const yesterday = new Date(today);
        yesterday.setDate(today.getDate() - 1);

        // Normalize dates to start of day for comparison
        const todayStart = new Date(today.setHours(0, 0, 0, 0));
        const threeDaysStart = new Date(threeDaysFromNow.setHours(0, 0, 0, 0));
        const yesterdayStart = new Date(yesterday.setHours(0, 0, 0, 0));

        logger.info(`Today: ${todayStart.toISOString()}`);
        logger.info(`3 days from now: ${threeDaysStart.toISOString()}`);
        logger.info(`Yesterday: ${yesterdayStart.toISOString()}`);

        // Get all trial companies
        const expiringTrialsSnapshot = await admin.firestore()
            .collection("companies")
            .where("currentPlan", "==", "trial")
            .where("status", "==", "active")
            .get();

        logger.info(`Found ${expiringTrialsSnapshot.size} companies on trial`);

        let warningsSent = 0;
        let transitioned = 0;
        const results = [];

        for (const doc of expiringTrialsSnapshot.docs) {
          const company = doc.data();
          const trialEndDate = company.trialEndDate.toDate();
          const trialEndStart = new Date(trialEndDate.setHours(0, 0, 0, 0));

          // Check if trial ends in exactly 3 days
          if (trialEndStart.getTime() === threeDaysStart.getTime()) {
            logger.info(`Sending warning for: ${company.businessName}`);

            try {
              await sendTrialWarningEmail({
                ownerName: company.ownerName,
                ownerEmail: company.ownerEmail,
                businessName: company.businessName,
                trialEndDate: company.trialEndDate.toDate(),
                daysLeft: 3,
              });
              warningsSent++;
              results.push({
                action: "warning_sent",
                company: company.businessName,
                email: company.ownerEmail,
              });
            } catch (error) {
              logger.error(`Failed to send warning: ${error.message}`);
              results.push({
                action: "warning_failed",
                company: company.businessName,
                error: error.message,
              });
            }
          }

          // Check if trial ended yesterday
          if (trialEndStart.getTime() === yesterdayStart.getTime()) {
            logger.info(`Transitioning to Free: ${company.businessName}`);

            try {
              const freeStartDate = new Date();
              const freeEndDate = new Date();
              freeEndDate.setDate(freeStartDate.getDate() + 30);

              await doc.ref.update({
                currentPlan: "free",
                freeStartDate: admin.firestore.Timestamp.fromDate(freeStartDate),
                freeEndDate: admin.firestore.Timestamp.fromDate(freeEndDate),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              await sendTrialExpiredEmail({
                ownerName: company.ownerName,
                ownerEmail: company.ownerEmail,
                businessName: company.businessName,
                freeEndDate,
              });

              transitioned++;
              results.push({
                action: "transitioned_to_free",
                company: company.businessName,
                email: company.ownerEmail,
                freeEndDate: freeEndDate.toISOString(),
              });
            } catch (error) {
              logger.error(`Failed to transition: ${error.message}`);
              results.push({
                action: "transition_failed",
                company: company.businessName,
                error: error.message,
              });
            }
          }
        }

        res.status(200).json({
          success: true,
          warningsSent,
          transitioned,
          results,
        });
      } catch (error) {
        logger.error("Error in testTrialExpirations:", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    }
);

/**
 * TESTING ONLY: Manual trigger for free account expiration check
 * DELETE after Phase 3 testing is complete
 */
exports.testFreeAccountExpirations = onRequest(
    {
      region: "us-central1",
      cors: true,
    },
    async (req, res) => {
      try {
        logger.info("=== Manual Test: Free Account Expiration Check ===");

        const {
          sendFreeAccountWarningEmail,
          sendAccountLockedEmail,
        } = require("./emailService");

        const now = admin.firestore.Timestamp.now();
        const today = new Date(now.toMillis());
        const threeDaysFromNow = new Date(today);
        threeDaysFromNow.setDate(today.getDate() + 3);
        const yesterday = new Date(today);
        yesterday.setDate(today.getDate() - 1);

        // Normalize dates to start of day
        const todayStart = new Date(today.setHours(0, 0, 0, 0));
        const threeDaysStart = new Date(threeDaysFromNow.setHours(0, 0, 0, 0));
        const yesterdayStart = new Date(yesterday.setHours(0, 0, 0, 0));

        logger.info(`Today: ${todayStart.toISOString()}`);
        logger.info(`3 days from now: ${threeDaysStart.toISOString()}`);
        logger.info(`Yesterday: ${yesterdayStart.toISOString()}`);

        // Get all free accounts
        const freeAccountsSnapshot = await admin.firestore()
            .collection("companies")
            .where("currentPlan", "==", "free")
            .where("status", "==", "active")
            .get();

        logger.info(`Found ${freeAccountsSnapshot.size} companies on Free plan`);

        let warningsSent = 0;
        let locked = 0;
        const results = [];

        for (const doc of freeAccountsSnapshot.docs) {
          const company = doc.data();

          if (!company.freeEndDate) {
            logger.warn(`Company ${doc.id} on Free plan but no freeEndDate`);
            continue;
          }

          const freeEndDate = company.freeEndDate.toDate();
          const freeEndStart = new Date(freeEndDate.setHours(0, 0, 0, 0));

          // Check if free period ends in exactly 3 days
          if (freeEndStart.getTime() === threeDaysStart.getTime()) {
            logger.info(`Sending lock warning for: ${company.businessName}`);

            try {
              await sendFreeAccountWarningEmail({
                ownerName: company.ownerName,
                ownerEmail: company.ownerEmail,
                businessName: company.businessName,
                lockDate: company.freeEndDate.toDate(),
                daysLeft: 3,
              });
              warningsSent++;
              results.push({
                action: "lock_warning_sent",
                company: company.businessName,
                email: company.ownerEmail,
              });
            } catch (error) {
              logger.error(`Failed to send lock warning: ${error.message}`);
              results.push({
                action: "lock_warning_failed",
                company: company.businessName,
                error: error.message,
              });
            }
          }

          // Check if free period ended yesterday
          if (freeEndStart.getTime() === yesterdayStart.getTime()) {
            logger.info(`Locking account: ${company.businessName}`);

            try {
              await doc.ref.update({
                status: "locked",
                lockedAt: admin.firestore.FieldValue.serverTimestamp(),
                lockedReason: "Free period expired without paid subscription",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              await sendAccountLockedEmail({
                ownerName: company.ownerName,
                ownerEmail: company.ownerEmail,
                businessName: company.businessName,
              });

              locked++;
              results.push({
                action: "account_locked",
                company: company.businessName,
                email: company.ownerEmail,
              });
            } catch (error) {
              logger.error(`Failed to lock account: ${error.message}`);
              results.push({
                action: "lock_failed",
                company: company.businessName,
                error: error.message,
              });
            }
          }
        }

        res.status(200).json({
          success: true,
          warningsSent,
          locked,
          results,
        });
      } catch (error) {
        logger.error("Error in testFreeAccountExpirations:", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    }
);

/**
 * Update subscription plan via secure token (customer self-service)
 * Called from customer subscription management screen
 */
exports.updateSubscriptionViaToken = onCall(
    {region: "us-central1"},
    async (request) => {
      try {
        const {token, newPlan, billingCycle} = request.data;

        // Validate input
        if (!token || !newPlan || !billingCycle) {
          throw new HttpsError("invalid-argument", "Missing required fields");
        }

        // Validate token
        const tokenDoc = await admin.firestore()
            .collection("subscriptionChangeTokens")
            .doc(token)
            .get();

        if (!tokenDoc.exists) {
          throw new HttpsError("not-found", "Invalid token");
        }

        const tokenData = tokenDoc.data();

        // Check if token has been used
        if (tokenData.used) {
          throw new HttpsError(
              "permission-denied",
              "This link has already been used",
          );
        }

        // Check if token has expired (72 hours)
        const now = admin.firestore.Timestamp.now();
        if (tokenData.expiresAt.toMillis() < now.toMillis()) {
          throw new HttpsError(
              "permission-denied",
              "This link has expired",
          );
        }

        const companyId = tokenData.companyId;

        // Get current company data
        const companyRef = admin.firestore().collection("companies").doc(companyId);
        const companyDoc = await companyRef.get();

        if (!companyDoc.exists) {
          throw new HttpsError("not-found", "Company not found");
        }

        const companyData = companyDoc.data();
        const currentPlan = companyData.currentPlan || "free";

        // Validate: Cannot select the same plan
        if (newPlan === currentPlan && billingCycle === companyData.billingCycle) {
          throw new HttpsError(
              "failed-precondition",
              "You are already subscribed to this plan. Please select a different plan.",
          );
        }

        // Validate: Cannot manually select Free plan
        // Free plan is only for initial signup and automatic downgrades
        const isNewPlanFree = newPlan === "free";

        if (isNewPlanFree) {
          throw new HttpsError(
              "failed-precondition",
              "You cannot manually select the Free plan. Free plan is only for new accounts. To cancel your subscription, please contact support.",
          );
        }

        // Validate: Free users must upgrade to a paid plan (Bronze, Silver, Gold, or Platinum)
        const paidPlans = ["bronze", "silver", "gold", "platinum"];
        if (currentPlan === "free" && !paidPlans.includes(newPlan)) {
          throw new HttpsError(
              "failed-precondition",
              "Free plan users must upgrade to a paid plan (Bronze, Silver, Gold, or Platinum).",
          );
        }

        // Get plan details to validate it exists
        const planDoc = await admin.firestore()
            .collection("subscriptionPlans")
            .doc(newPlan)
            .get();

        if (!planDoc.exists) {
          throw new HttpsError("not-found", `Subscription plan "${newPlan}" not found`);
        }

        const planData = planDoc.data();

        // Create plan history entry
        // Note: Cannot use FieldValue.serverTimestamp() inside arrays
        const planHistoryEntry = {
          previousPlan: currentPlan,
          newPlan: newPlan,
          billingCycle: billingCycle,
          changedAt: admin.firestore.Timestamp.now(),
          changedBy: "customer_self_service",
          changeMethod: "token_link",
        };

        // Update company subscription
        await companyRef.update({
          currentPlan: newPlan,
          billingCycle: billingCycle,
          customPriceMonthly: null,
          customPriceYearly: null,
          planHistory: admin.firestore.FieldValue.arrayUnion(planHistoryEntry),
          lastModified: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Mark token as used
        await tokenDoc.ref.update({
          used: true,
          usedAt: admin.firestore.FieldValue.serverTimestamp(),
          usedBy: "customer_self_service",
        });

        logger.info("Subscription updated via token", {
          companyId,
          token,
          previousPlan: currentPlan,
          newPlan,
          billingCycle,
        });

        return {
          success: true,
          message: `Subscription updated to ${planData.name} (${billingCycle} billing)`,
          companyId: companyId,
          newPlan: newPlan,
          newPlanName: planData.name,
          billingCycle: billingCycle,
        };
      } catch (error) {
        logger.error("Error in updateSubscriptionViaToken:", error);
        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError("internal", error.message);
      }
    },
);

/**
 * Validate subscription token and return Firebase custom auth token
 * Allows users to access subscription management via secure email links
 */
const {validateSubscriptionToken} = require("./subscriptionTokenService");

exports.validateAndAuthenticateToken = onCall(
    {region: "us-central1"},
    async (request) => {
      try {
        const {token} = request.data;

        if (!token) {
          throw new HttpsError("invalid-argument", "Token is required");
        }

        // Validate the token
        const tokenData = await validateSubscriptionToken(token);

        if (!tokenData) {
          throw new HttpsError(
              "permission-denied",
              "Invalid, expired, or already used token",
          );
        }

        // Create a custom Firebase Auth token for the user
        const customToken = await admin.auth().createCustomToken(tokenData.userId, {
          companyId: tokenData.companyId,
          purpose: "subscription_management",
        });

        logger.info(`Created auth token for user ${tokenData.userId} via subscription token`);

        return {
          success: true,
          customToken,
          companyId: tokenData.companyId,
          userId: tokenData.userId,
        };
      } catch (error) {
        logger.error("Error in validateAndAuthenticateToken:", error);
        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError("internal", error.message);
      }
    },
);

/**
 * Publishes weekly schedule and sends emails to all scheduled employees
 * Called from the schedule grid when admin clicks "Save and Publish"
 */
exports.publishSchedule = onCall(
    {region: "us-central1"},
    async (request) => {
      try {
        const {companyId, weekStart, weekEnd} = request.data;

        if (!companyId || !weekStart || !weekEnd) {
          throw new HttpsError("invalid-argument", "Missing required parameters");
        }

        logger.info(`Publishing schedule for company ${companyId}, week ${weekStart} - ${weekEnd}`);

        // Parse dates
        const startDate = admin.firestore.Timestamp.fromDate(new Date(weekStart));
        const endDate = admin.firestore.Timestamp.fromDate(new Date(weekEnd));

        // Get all shifts for this week
        // Note: Shifts don't have companyId, so we query by date range only
        // and filter by company via employeeId later if needed
        const shiftsSnapshot = await admin.firestore()
            .collection("shifts")
            .where("startTime", ">=", startDate)
            .where("startTime", "<=", endDate)
            .get();

        logger.info(`Found ${shiftsSnapshot.size} shifts for the week`);

        if (shiftsSnapshot.empty) {
          logger.info("No shifts found for this week");
          return {
            success: true,
            message: "No shifts to publish",
            emailsSent: 0,
          };
        }

        // Group shifts by employee (filter by company)
        const employeeShifts = {};
        for (const doc of shiftsSnapshot.docs) {
          const shift = doc.data();
          const employeeId = shift.employeeId;

          // Check if employee belongs to this company
          const employeeDoc = await admin.firestore()
              .collection("users")
              .doc(employeeId)
              .get();

          if (!employeeDoc.exists) {
            logger.warn(`Employee ${employeeId} not found, skipping shift`);
            continue;
          }

          const employee = employeeDoc.data();
          if (employee.companyId !== companyId) {
            logger.info(`Employee ${employeeId} belongs to different company, skipping`);
            continue;
          }

          if (!employeeShifts[employeeId]) {
            employeeShifts[employeeId] = [];
          }

          employeeShifts[employeeId].push(shift);
        }

        logger.info(`Sending schedules to ${Object.keys(employeeShifts).length} employees`);

        // Send email to each employee
        const {sendScheduleEmail} = require("./emailService");
        let emailsSent = 0;
        const errors = [];

        for (const [employeeId, shifts] of Object.entries(employeeShifts)) {
          try {
            // Get employee data
            const employeeDoc = await admin.firestore()
                .collection("users")
                .doc(employeeId)
                .get();

            if (!employeeDoc.exists) {
              logger.warn(`Employee ${employeeId} not found`);
              continue;
            }

            const employee = employeeDoc.data();

            // Format shifts for email
            const formattedShifts = shifts.map((shift) => {
              const shiftDate = shift.startTime.toDate();
              const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

              // Format time
              let timeDisplay;
              if (shift.isDayOff) {
                if (shift.dayOffType === "paid") {
                  timeDisplay = `Paid Day Off (${shift.paidHours || 0}h)`;
                } else if (shift.dayOffType === "holiday") {
                  timeDisplay = `Holiday (${shift.paidHours || 0}h)`;
                } else {
                  timeDisplay = "Unpaid Day Off";
                }
              } else {
                // Extract time from formattedTimeRange if available
                timeDisplay = shift.formattedTimeRange || "N/A";
              }

              return {
                day: days[shiftDate.getDay()],
                date: shiftDate.toLocaleDateString("en-US", {
                  month: "short",
                  day: "numeric",
                  year: "numeric",
                }),
                startTime: timeDisplay.split(" - ")[0] || timeDisplay,
                endTime: timeDisplay.split(" - ")[1] || "",
                hours: shift.durationHours.toFixed(1),
              };
            }).sort((a, b) => {
              // Sort by day of week
              const dayOrder = {"Sunday": 0, "Monday": 1, "Tuesday": 2, "Wednesday": 3,
                "Thursday": 4, "Friday": 5, "Saturday": 6};
              return dayOrder[a.day] - dayOrder[b.day];
            });

            // Send email
            await sendScheduleEmail({
              employeeName: `${employee.firstName} ${employee.lastName}`,
              employeeEmail: employee.email,
              weekStart: new Date(weekStart).toLocaleDateString("en-US", {
                month: "short",
                day: "numeric",
              }),
              weekEnd: new Date(weekEnd).toLocaleDateString("en-US", {
                month: "short",
                day: "numeric",
                year: "numeric",
              }),
              shifts: formattedShifts,
            });

            emailsSent++;
            logger.info(`Schedule email sent to ${employee.email}`);
          } catch (error) {
            logger.error(`Failed to send schedule to employee ${employeeId}:`, error);
            errors.push({
              employeeId,
              error: error.message,
            });
          }
        }

        logger.info(`Schedule publish complete. Emails sent: ${emailsSent}, Errors: ${errors.length}`);

        return {
          success: true,
          message: `Schedule published successfully. Emails sent to ${emailsSent} employees.`,
          emailsSent,
          errors: errors.length > 0 ? errors : undefined,
        };
      } catch (error) {
        logger.error("Error in publishSchedule:", error);
        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError("internal", error.message);
      }
    },
);

/**
 * Cloud Function that triggers when employee clocks in off-premises
 * Sends notification emails to all admins and super admins
 */
exports.notifyOffPremisesClockIn = onDocumentCreated(
    {
      document: "offPremisesAlerts/{alertId}",
      region: "us-central1",
    },
    async (event) => {
      try {
        const alertData = event.data.data();
        const {userId, clockInTime, location, workLocation, timeEntryId} = alertData;

        logger.info(`Processing off-premises alert for user ${userId}`);

        // Get employee details
        const userDoc = await admin.firestore()
            .collection("users")
            .doc(userId)
            .get();

        if (!userDoc.exists) {
          logger.error(`User ${userId} not found`);
          return;
        }

        const employee = userDoc.data();
        const companyId = employee.companyId;

        // Get all admins and super admins for this company
        const adminsSnapshot = await admin.firestore()
            .collection("users")
            .where("companyId", "==", companyId)
            .where("role", "in", ["admin", "super-admin"])
            .get();

        if (adminsSnapshot.empty) {
          logger.warn(`No admins found for company ${companyId}`);
          return;
        }

        // Calculate distance from work location
        let distanceText = "Unknown";
        if (location && workLocation) {
          const distance = calculateDistance(
              location.lat,
              location.lng,
              workLocation.lat,
              workLocation.lng,
          );
          distanceText = `${Math.round(distance)} meters`;
        }

        const clockInDate = new Date(clockInTime.toDate());
        const formattedTime = clockInDate.toLocaleString("en-US", {
          weekday: "long",
          year: "numeric",
          month: "long",
          day: "numeric",
          hour: "numeric",
          minute: "2-digit",
          hour12: true,
        });

        // Send email to each admin
        const {sendOffPremisesAlert} = require("./emailService");
        const emailPromises = [];

        for (const adminDoc of adminsSnapshot.docs) {
          const admin = adminDoc.data();

          emailPromises.push(
              sendOffPremisesAlert({
                adminName: admin.firstName,
                adminEmail: admin.email,
                employeeName: `${employee.firstName} ${employee.lastName}`,
                employeeEmail: employee.email,
                clockInTime: formattedTime,
                distance: distanceText,
                locationUrl: location ?
                  `https://www.google.com/maps?q=${location.lat},${location.lng}` :
                  null,
              }),
          );
        }

        await Promise.all(emailPromises);

        // Mark alert as notified
        await event.data.ref.update({
          notified: true,
          notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          adminCount: adminsSnapshot.size,
        });

        logger.info(`Off-premises notification sent for user ${userId} to ${adminsSnapshot.size} admins`);
      } catch (error) {
        logger.error("Error in notifyOffPremisesClockIn:", error);
      }
    },
);

/**
 * Calculate distance between two coordinates in meters using Haversine formula
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth's radius in meters
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;

  const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

/**
 * Callable Function: Send welcome email to newly created employee
 * Called from Flutter app after creating a new employee
 */
exports.sendNewEmployeeWelcome = onCall(
    {
      region: "us-central1",
      cors: true,
    },
    async (request) => {
      try {
        // Verify user is authenticated
        if (!request.auth) {
          throw new HttpsError(
              "unauthenticated",
              "Must be logged in to send welcome emails"
          );
        }

        const {userId, temporaryPassword} = request.data;

        if (!userId || !temporaryPassword) {
          throw new HttpsError(
              "invalid-argument",
              "userId and temporaryPassword are required"
          );
        }

        // Get employee details
        const userDoc = await admin.firestore()
            .collection("users")
            .doc(userId)
            .get();

        if (!userDoc.exists) {
          throw new HttpsError(
              "not-found",
              "User not found"
          );
        }

        const employee = userDoc.data();

        // Only send welcome emails to employees (not admins/managers)
        if (employee.role === "employee") {
          // Get company name
          const companyDoc = await admin.firestore()
              .collection("companies")
              .doc(employee.companyId)
              .get();

          const companyName = companyDoc.exists ?
            companyDoc.data().businessName :
            "Your Company";

          // Send welcome email
          const {sendEmployeeWelcomeEmail} = require("./emailService");
          await sendEmployeeWelcomeEmail({
            employeeName: `${employee.firstName} ${employee.lastName}`,
            employeeEmail: employee.email,
            companyName,
            temporaryPassword,
            appUrl: "https://chronoworks-dcfd6.web.app",
          });

          logger.info(`Welcome email sent to new employee: ${employee.email}`);

          return {
            success: true,
            message: "Welcome email sent successfully",
          };
        } else {
          logger.info(`Skipping welcome email for non-employee user: ${employee.role}`);
          return {
            success: true,
            message: "Welcome email not sent (user is not an employee)",
          };
        }
      } catch (error) {
        logger.error("Error in sendNewEmployeeWelcome:", error);
        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError("internal", error.message);
      }
    }
);
