const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

/**
 * Cloud Function to create a new Account Manager
 * Only callable by Super Admins
 */
exports.createAccountManager = onCall(
    {
      region: "us-central1",
    },
    async (request) => {
      try {
        // Check if caller is authenticated
        if (!request.auth) {
          throw new HttpsError(
              "unauthenticated",
              "Must be authenticated to create Account Managers",
          );
        }

        const callerId = request.auth.uid;

        // Check if caller is a Super Admin
        const superAdminDoc = await admin.firestore()
            .collection("superAdmins")
            .doc(callerId)
            .get();

        if (!superAdminDoc.exists) {
          throw new HttpsError(
              "permission-denied",
              "Only Super Admins can create Account Managers",
          );
        }

        // Extract data from request
        const {
          email,
          displayName,
          password,
          phoneNumber,
          maxAssignedCompanies,
        } = request.data;

        // Validate required fields
        if (!email || !displayName || !password) {
          throw new HttpsError(
              "invalid-argument",
              "Email, display name, and password are required",
          );
        }

        logger.info(`Creating Account Manager: ${displayName} (${email})`);

        // 1. Create Firebase Auth user
        const userRecord = await admin.auth().createUser({
          email: email,
          password: password,
          displayName: displayName,
          disabled: false,
        });

        logger.info(`Created Auth user: ${userRecord.uid}`);

        const uid = userRecord.uid;

        // 2. Create Account Manager document
        const accountManagerData = {
          id: uid,
          uid: uid,
          email: email,
          displayName: displayName,
          phoneNumber: phoneNumber || null,
          photoURL: null,
          role: "account_manager",
          permissions: [
            "view_assigned_customers",
            "edit_customer_settings",
            "manage_support_tickets",
            "view_analytics",
          ],
          assignedCompanies: [],
          maxAssignedCompanies: maxAssignedCompanies || 100,
          metrics: {
            totalAssignedCustomers: 0,
            activeCustomers: 0,
            trialCustomers: 0,
            paidCustomers: 0,
            averageResponseTime: 0,
            customerSatisfactionScore: 0,
            monthlyUpsellRevenue: 0,
          },
          status: "active",
          hireDate: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: callerId,
        };

        await admin.firestore()
            .collection("accountManagers")
            .doc(uid)
            .set(accountManagerData);

        logger.info("Created accountManagers document");

        // 3. Create users document
        const userData = {
          email: email,
          displayName: displayName,
          phoneNumber: phoneNumber || null,
          role: "account_manager",
          isAccountManager: true,
          accountManagerProfile: uid,
          status: "active",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        await admin.firestore()
            .collection("users")
            .doc(uid)
            .set(userData);

        logger.info("Created users document");

        logger.info(`✅ Account Manager created successfully: ${uid}`);

        // Return success with the new Account Manager ID
        return {
          success: true,
          accountManagerId: uid,
          message: `Account Manager created successfully: ${displayName}`,
        };
      } catch (error) {
        logger.error("Error creating Account Manager:", error);

        // Re-throw HttpsErrors as-is
        if (error instanceof HttpsError) {
          throw error;
        }

        // Handle specific Firebase Auth errors
        if (error.code === "auth/email-already-exists") {
          throw new HttpsError(
              "already-exists",
              "An account with this email already exists",
          );
        }

        if (error.code === "auth/invalid-email") {
          throw new HttpsError(
              "invalid-argument",
              "Invalid email address",
          );
        }

        if (error.code === "auth/weak-password") {
          throw new HttpsError(
              "invalid-argument",
              "Password is too weak. Must be at least 6 characters.",
          );
        }

        // Generic error
        throw new HttpsError(
            "internal",
            `Failed to create Account Manager: ${error.message}`,
        );
      }
    },
);
