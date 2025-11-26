const {onRequest} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

/**
 * Temporary Cloud Function to delete all users except chris.s@snowdensjewelers.com
 * DELETE after cleanup is complete
 */
exports.deleteAllUsersExcept = onRequest(
    {
      region: "us-central1",
      cors: true,
    },
    async (req, res) => {
      try {
        const KEEP_EMAIL = "chris.s@snowdensjewelers.com";

        logger.info("🔍 Fetching all users...");
        logger.info(`⚠️  Will keep: ${KEEP_EMAIL}`);

        const listUsersResult = await admin.auth().listUsers(1000);
        const users = listUsersResult.users;

        logger.info(`📊 Found ${users.length} total users`);

        // Filter out the user to keep
        const usersToDelete = users.filter((user) => user.email !== KEEP_EMAIL);

        logger.info(`🗑️  Will delete ${usersToDelete.length} users`);

        if (usersToDelete.length === 0) {
          res.json({
            success: true,
            message: "No users to delete",
            kept: KEEP_EMAIL,
          });
          return;
        }

        // Show which users will be deleted
        logger.info("Users to be deleted:");
        usersToDelete.forEach((user) => {
          logger.info(`  - ${user.email || "No email"} (${user.uid})`);
        });

        // Delete users
        let deletedCount = 0;
        for (const user of usersToDelete) {
          try {
            // Delete from Firebase Auth
            await admin.auth().deleteUser(user.uid);

            // Also delete from Firestore collections if they exist
            await Promise.all([
              admin.firestore().collection("users").doc(user.uid).delete()
                  .catch(() => {}),
              admin.firestore().collection("accountManagers").doc(user.uid)
                  .delete().catch(() => {}),
              admin.firestore().collection("superAdmins").doc(user.uid).delete()
                  .catch(() => {}),
            ]);

            deletedCount++;
            logger.info(`✅ Deleted: ${user.email || user.uid}`);
          } catch (error) {
            logger.error(
                `❌ Failed to delete ${user.email || user.uid}: ${error.message}`,
            );
          }
        }

        logger.info(`🎉 Deleted ${deletedCount} out of ${usersToDelete.length} users`);
        logger.info(`✅ Kept: ${KEEP_EMAIL}`);

        res.json({
          success: true,
          deletedCount: deletedCount,
          totalUsers: users.length,
          kept: KEEP_EMAIL,
        });
      } catch (error) {
        logger.error("❌ Error:", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    },
);
