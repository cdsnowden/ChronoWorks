/**
 * Trial Management Functions for ChronoWorks Phase 3
 * Handles trial expiration, free account transitions, and account locking
 */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const {
  sendTrialWarningEmail,
  sendTrialExpiredEmail,
  sendFreeAccountWarningEmail,
  sendAccountLockedEmail,
} = require("./emailService");
const {generateSubscriptionToken} = require("./subscriptionTokenService");

/**
 * Scheduled Function: Runs daily at 9 AM to check trial expirations
 *
 * Actions:
 * 1. Find trials expiring in 3 days → send warning email
 * 2. Find trials that expired yesterday → transition to Free plan
 */
const checkTrialExpirations = onSchedule(
    {
      schedule: "0 9 * * *", // Every day at 9 AM
      timeZone: "America/New_York",
      region: "us-central1",
    },
    async (event) => {
      try {
        logger.info("=== Starting Trial Expiration Check ===");

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

        // ==========================================
        // 1. Send warnings for trials expiring in 3 days
        // ==========================================

        const expiringTrialsSnapshot = await admin.firestore()
            .collection("companies")
            .where("currentPlan", "==", "trial")
            .where("status", "==", "active")
            .get();

        logger.info(`Found ${expiringTrialsSnapshot.size} companies on trial`);

        let warningsSent = 0;
        for (const doc of expiringTrialsSnapshot.docs) {
          const company = doc.data();
          const trialEndDate = company.trialEndDate.toDate();
          const trialEndStart = new Date(trialEndDate.setHours(0, 0, 0, 0));

          // Check if trial ends in exactly 3 days
          if (trialEndStart.getTime() === threeDaysStart.getTime()) {
            logger.info(`Sending warning for company: ${company.businessName} (${doc.id})`);

            try {
              // Generate secure token for subscription management
              const tokenData = await generateSubscriptionToken(
                doc.id,
                company.ownerId,
                72 // Token valid for 72 hours
              );

              await sendTrialWarningEmail({
                ownerName: company.ownerName,
                ownerEmail: company.ownerEmail,
                businessName: company.businessName,
                trialEndDate: company.trialEndDate.toDate(),
                daysLeft: 3,
                managementUrl: tokenData.managementUrl,
              });
              warningsSent++;
              logger.info(`Warning email sent to ${company.ownerEmail} with token ${tokenData.tokenId}`);
            } catch (emailError) {
              logger.error(`Failed to send warning email to ${company.ownerEmail}:`, emailError);
            }
          }
        }

        logger.info(`Trial warnings sent: ${warningsSent}`);

        // ==========================================
        // 2. Transition expired trials to Free plan
        // ==========================================

        let transitioned = 0;
        for (const doc of expiringTrialsSnapshot.docs) {
          const company = doc.data();
          const trialEndDate = company.trialEndDate.toDate();
          const trialEndStart = new Date(trialEndDate.setHours(0, 0, 0, 0));

          // Check if trial ended yesterday
          if (trialEndStart.getTime() === yesterdayStart.getTime()) {
            logger.info(`Transitioning company to Free plan: ${company.businessName} (${doc.id})`);

            try {
              // Calculate free plan end date (30 days from now)
              const freeStartDate = new Date();
              const freeEndDate = new Date();
              freeEndDate.setDate(freeStartDate.getDate() + 30);

              // Update company document
              await doc.ref.update({
                currentPlan: "free",
                freeStartDate: admin.firestore.Timestamp.fromDate(freeStartDate),
                freeEndDate: admin.firestore.Timestamp.fromDate(freeEndDate),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              logger.info(`Company ${doc.id} transitioned to Free plan`);

              // Send email notification
              try {
                await sendTrialExpiredEmail({
                  ownerName: company.ownerName,
                  ownerEmail: company.ownerEmail,
                  businessName: company.businessName,
                  freeEndDate,
                });
                logger.info(`Free plan notification sent to ${company.ownerEmail}`);
              } catch (emailError) {
                logger.error(`Failed to send free plan email to ${company.ownerEmail}:`, emailError);
              }

              transitioned++;
            } catch (error) {
              logger.error(`Failed to transition company ${doc.id}:`, error);
            }
          }
        }

        logger.info(`Companies transitioned to Free plan: ${transitioned}`);
        logger.info("=== Trial Expiration Check Complete ===");

        return {
          success: true,
          warningsSent,
          transitioned,
        };
      } catch (error) {
        logger.error("Error in checkTrialExpirations:", error);
        return {success: false, error: error.message};
      }
    }
);

/**
 * Scheduled Function: Runs daily at 9 AM to check free account expirations
 *
 * Actions:
 * 1. Find free accounts expiring in 3 days → send warning email
 * 2. Find free accounts that expired yesterday → lock account
 */
const checkFreeAccountExpirations = onSchedule(
    {
      schedule: "0 9 * * *", // Every day at 9 AM
      timeZone: "America/New_York",
      region: "us-central1",
    },
    async (event) => {
      try {
        logger.info("=== Starting Free Account Expiration Check ===");

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

        // ==========================================
        // 1. Send warnings for free accounts expiring in 3 days
        // ==========================================

        const freeAccountsSnapshot = await admin.firestore()
            .collection("companies")
            .where("currentPlan", "==", "free")
            .where("status", "==", "active")
            .get();

        logger.info(`Found ${freeAccountsSnapshot.size} companies on Free plan`);

        let warningsSent = 0;
        for (const doc of freeAccountsSnapshot.docs) {
          const company = doc.data();

          if (!company.freeEndDate) {
            logger.warn(`Company ${doc.id} on Free plan but no freeEndDate set`);
            continue;
          }

          const freeEndDate = company.freeEndDate.toDate();
          const freeEndStart = new Date(freeEndDate.setHours(0, 0, 0, 0));

          // Check if free period ends in exactly 3 days
          if (freeEndStart.getTime() === threeDaysStart.getTime()) {
            logger.info(`Sending lock warning for company: ${company.businessName} (${doc.id})`);

            try {
              await sendFreeAccountWarningEmail({
                ownerName: company.ownerName,
                ownerEmail: company.ownerEmail,
                businessName: company.businessName,
                lockDate: company.freeEndDate.toDate(),
                daysLeft: 3,
              });
              warningsSent++;
              logger.info(`Lock warning email sent to ${company.ownerEmail}`);
            } catch (emailError) {
              logger.error(`Failed to send lock warning to ${company.ownerEmail}:`, emailError);
            }
          }
        }

        logger.info(`Free account warnings sent: ${warningsSent}`);

        // ==========================================
        // 2. Lock expired free accounts
        // ==========================================

        let locked = 0;
        for (const doc of freeAccountsSnapshot.docs) {
          const company = doc.data();

          if (!company.freeEndDate) {
            continue;
          }

          const freeEndDate = company.freeEndDate.toDate();
          const freeEndStart = new Date(freeEndDate.setHours(0, 0, 0, 0));

          // Check if free period ended yesterday
          if (freeEndStart.getTime() === yesterdayStart.getTime()) {
            logger.info(`Locking account: ${company.businessName} (${doc.id})`);

            try {
              // Update company status to locked
              await doc.ref.update({
                status: "locked",
                lockedAt: admin.firestore.FieldValue.serverTimestamp(),
                lockedReason: "Free period expired without paid subscription",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              logger.info(`Company ${doc.id} locked`);

              // Send account locked email
              try {
                await sendAccountLockedEmail({
                  ownerName: company.ownerName,
                  ownerEmail: company.ownerEmail,
                  businessName: company.businessName,
                });
                logger.info(`Account locked notification sent to ${company.ownerEmail}`);
              } catch (emailError) {
                logger.error(`Failed to send locked email to ${company.ownerEmail}:`, emailError);
              }

              locked++;
            } catch (error) {
              logger.error(`Failed to lock company ${doc.id}:`, error);
            }
          }
        }

        logger.info(`Accounts locked: ${locked}`);
        logger.info("=== Free Account Expiration Check Complete ===");

        return {
          success: true,
          warningsSent,
          locked,
        };
      } catch (error) {
        logger.error("Error in checkFreeAccountExpirations:", error);
        return {success: false, error: error.message};
      }
    }
);

module.exports = {
  checkTrialExpirations,
  checkFreeAccountExpirations,
};
