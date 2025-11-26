/**
 * Free Account Management Functions for ChronoWorks
 * Handles free plan phase transitions and account locking
 *
 * Free Plan Lifecycle:
 * - Phase 1 (Days 1-30): Full functionality
 * - Phase 2 (Days 31-60): Limited functionality
 * - After Day 60: Account locked
 */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const {
  sendFreePhase1WarningEmail,
  sendFreePhase2TransitionEmail,
  sendFreePhase2WarningEmail,
  sendAccountLockedEmail,
} = require("./emailService");
const {generateSubscriptionToken} = require("./subscriptionTokenService");

/**
 * Scheduled Function: Runs daily at 9 AM to check Free Phase 1 expirations
 *
 * Actions:
 * 1. Find Phase 1 expiring in 3 days → send warning email with upgrade link
 * 2. Find Phase 1 that expired yesterday → transition to Phase 2
 */
const checkFreePhase1Expirations = onSchedule(
    {
      schedule: "0 9 * * *", // Every day at 9 AM
      timeZone: "America/New_York",
      region: "us-central1",
    },
    async (event) => {
      try {
        logger.info("=== Starting Free Phase 1 Expiration Check ===");

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
        // 1. Send warnings for Phase 1 expiring in 3 days
        // ==========================================

        const phase1AccountsSnapshot = await admin.firestore()
            .collection("companies")
            .where("currentPlan", "==", "free")
            .where("freePhase", "==", 1)
            .where("status", "==", "active")
            .get();

        logger.info(`Found ${phase1AccountsSnapshot.size} companies on Free Phase 1`);

        let warningsSent = 0;
        for (const doc of phase1AccountsSnapshot.docs) {
          const company = doc.data();

          if (!company.freePhase1EndDate) {
            logger.warn(`Company ${doc.id} in Phase 1 but no freePhase1EndDate set`);
            continue;
          }

          const phase1EndDate = company.freePhase1EndDate.toDate();
          const phase1EndStart = new Date(phase1EndDate.setHours(0, 0, 0, 0));

          // Check if phase 1 ends in exactly 3 days
          if (phase1EndStart.getTime() === threeDaysStart.getTime()) {
            logger.info(`Sending Phase 1 warning for: ${company.businessName} (${doc.id})`);

            try {
              // Generate secure token for subscription management
              const tokenData = await generateSubscriptionToken(
                doc.id,
                company.ownerId,
                72 // Token valid for 72 hours
              );

              await sendFreePhase1WarningEmail({
                ownerName: company.ownerName,
                ownerEmail: company.ownerEmail,
                businessName: company.businessName,
                phase1EndDate: company.freePhase1EndDate.toDate(),
                daysLeft: 3,
                managementUrl: tokenData.managementUrl,
              });
              warningsSent++;
              logger.info(`Phase 1 warning email sent to ${company.ownerEmail}`);
            } catch (emailError) {
              logger.error(`Failed to send Phase 1 warning to ${company.ownerEmail}:`, emailError);
            }
          }
        }

        logger.info(`Phase 1 warnings sent: ${warningsSent}`);

        // ==========================================
        // 2. Transition expired Phase 1 to Phase 2
        // ==========================================

        let transitioned = 0;
        for (const doc of phase1AccountsSnapshot.docs) {
          const company = doc.data();

          if (!company.freePhase1EndDate) {
            continue;
          }

          const phase1EndDate = company.freePhase1EndDate.toDate();
          const phase1EndStart = new Date(phase1EndDate.setHours(0, 0, 0, 0));

          // Check if phase 1 ended yesterday
          if (phase1EndStart.getTime() === yesterdayStart.getTime()) {
            logger.info(`Transitioning to Phase 2: ${company.businessName} (${doc.id})`);

            try {
              // Calculate Phase 2 end date (30 days from now)
              const phase2StartDate = new Date();
              const phase2EndDate = new Date();
              phase2EndDate.setDate(phase2StartDate.getDate() + 30);

              // Update company document
              await doc.ref.update({
                freePhase: 2,
                freePhase2StartDate: admin.firestore.Timestamp.fromDate(phase2StartDate),
                freePhase2EndDate: admin.firestore.Timestamp.fromDate(phase2EndDate),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              logger.info(`Company ${doc.id} transitioned to Free Phase 2`);

              // Send email notification
              try {
                // Generate token for upgrade option
                const tokenData = await generateSubscriptionToken(
                  doc.id,
                  company.ownerId,
                  72
                );

                await sendFreePhase2TransitionEmail({
                  ownerName: company.ownerName,
                  ownerEmail: company.ownerEmail,
                  businessName: company.businessName,
                  phase2EndDate,
                  managementUrl: tokenData.managementUrl,
                });
                logger.info(`Phase 2 transition email sent to ${company.ownerEmail}`);
              } catch (emailError) {
                logger.error(`Failed to send Phase 2 email to ${company.ownerEmail}:`, emailError);
              }

              transitioned++;
            } catch (error) {
              logger.error(`Failed to transition company ${doc.id}:`, error);
            }
          }
        }

        logger.info(`Companies transitioned to Phase 2: ${transitioned}`);
        logger.info("=== Free Phase 1 Expiration Check Complete ===");

        return {
          success: true,
          warningsSent,
          transitioned,
        };
      } catch (error) {
        logger.error("Error in checkFreePhase1Expirations:", error);
        return {success: false, error: error.message};
      }
    }
);

/**
 * Scheduled Function: Runs daily at 9 AM to check Free Phase 2 expirations
 *
 * Actions:
 * 1. Find Phase 2 expiring in 3 days → send final warning email with upgrade link
 * 2. Find Phase 2 that expired yesterday → lock account
 */
const checkFreePhase2Expirations = onSchedule(
    {
      schedule: "0 9 * * *", // Every day at 9 AM
      timeZone: "America/New_York",
      region: "us-central1",
    },
    async (event) => {
      try {
        logger.info("=== Starting Free Phase 2 Expiration Check ===");

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
        // 1. Send warnings for Phase 2 expiring in 3 days
        // ==========================================

        const phase2AccountsSnapshot = await admin.firestore()
            .collection("companies")
            .where("currentPlan", "==", "free")
            .where("freePhase", "==", 2)
            .where("status", "==", "active")
            .get();

        logger.info(`Found ${phase2AccountsSnapshot.size} companies on Free Phase 2`);

        let warningsSent = 0;
        for (const doc of phase2AccountsSnapshot.docs) {
          const company = doc.data();

          if (!company.freePhase2EndDate) {
            logger.warn(`Company ${doc.id} in Phase 2 but no freePhase2EndDate set`);
            continue;
          }

          const phase2EndDate = company.freePhase2EndDate.toDate();
          const phase2EndStart = new Date(phase2EndDate.setHours(0, 0, 0, 0));

          // Check if phase 2 ends in exactly 3 days
          if (phase2EndStart.getTime() === threeDaysStart.getTime()) {
            logger.info(`Sending Phase 2 final warning for: ${company.businessName} (${doc.id})`);

            try {
              // Generate secure token for subscription management
              const tokenData = await generateSubscriptionToken(
                doc.id,
                company.ownerId,
                72 // Token valid for 72 hours
              );

              await sendFreePhase2WarningEmail({
                ownerName: company.ownerName,
                ownerEmail: company.ownerEmail,
                businessName: company.businessName,
                lockDate: company.freePhase2EndDate.toDate(),
                daysLeft: 3,
                managementUrl: tokenData.managementUrl,
              });
              warningsSent++;
              logger.info(`Phase 2 final warning sent to ${company.ownerEmail}`);
            } catch (emailError) {
              logger.error(`Failed to send Phase 2 warning to ${company.ownerEmail}:`, emailError);
            }
          }
        }

        logger.info(`Phase 2 warnings sent: ${warningsSent}`);

        // ==========================================
        // 2. Lock expired Phase 2 accounts
        // ==========================================

        let locked = 0;
        for (const doc of phase2AccountsSnapshot.docs) {
          const company = doc.data();

          if (!company.freePhase2EndDate) {
            continue;
          }

          const phase2EndDate = company.freePhase2EndDate.toDate();
          const phase2EndStart = new Date(phase2EndDate.setHours(0, 0, 0, 0));

          // Check if phase 2 ended yesterday
          if (phase2EndStart.getTime() === yesterdayStart.getTime()) {
            logger.info(`Locking account: ${company.businessName} (${doc.id})`);

            try {
              // Update company status to locked
              await doc.ref.update({
                status: "locked",
                lockedAt: admin.firestore.FieldValue.serverTimestamp(),
                lockedReason: "Free period (60 days) expired without paid subscription",
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
        logger.info("=== Free Phase 2 Expiration Check Complete ===");

        return {
          success: true,
          warningsSent,
          locked,
        };
      } catch (error) {
        logger.error("Error in checkFreePhase2Expirations:", error);
        return {success: false, error: error.message};
      }
    }
);

module.exports = {
  checkFreePhase1Expirations,
  checkFreePhase2Expirations,
};
