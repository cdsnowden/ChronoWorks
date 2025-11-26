/**
 * Registration Functions for ChronoWorks Phase 2
 * Handles business registration approval workflow
 */

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const {defineSecret} = require("firebase-functions/params");
const axios = require("axios");
const {
  sendAdminNotification,
  sendWelcomeEmail,
  sendRejectionEmail,
} = require("./emailService");

// Define Google Maps API key as a secret
const googleMapsApiKey = defineSecret("GOOGLE_MAPS_API_KEY");

/**
 * Firestore Trigger: Sends email to super admin when a new registration is submitted
 */
const onRegistrationSubmitted = onDocumentCreated(
    {
      document: "registrationRequests/{requestId}",
      region: "us-central1",
    },
    async (event) => {
      try {
        const requestId = event.params.requestId;
        const registration = event.data.data();

        logger.info(`New registration submitted: ${requestId} - ${registration.businessName}`);

        // Send email notification to super admin
        await sendAdminNotification(registration);

        logger.info(`Admin notification sent for registration: ${requestId}`);

        return {success: true, requestId};
      } catch (error) {
        logger.error(`Error in onRegistrationSubmitted: ${error.message}`, error);
        // Don't throw error - we don't want to retry this function
        // The registration is still saved, admin just didn't get email
        return {success: false, error: error.message};
      }
    }
);

/**
 * Callable Function: Approves a registration request
 *
 * This function:
 * 1. Creates company document
 * 2. Creates Firebase Auth user
 * 3. Creates user document in Firestore
 * 4. Sends welcome email with credentials
 * 5. Updates registration status to 'approved'
 */
const approveRegistration = onCall(
    {
      region: "us-central1",
      cors: true,
      secrets: [googleMapsApiKey],
    },
    async (request) => {
      try {
        // Verify user is authenticated
        if (!request.auth) {
          throw new HttpsError(
              "unauthenticated",
              "Must be logged in to approve registrations"
          );
        }

        const uid = request.auth.uid;
        const {requestId, approvedBy} = request.data;

        logger.info(`Approving registration: ${requestId} by ${uid}`);

        // Verify user is super admin
        const superAdminDoc = await admin.firestore()
            .collection("superAdmins")
            .doc(uid)
            .get();

        if (!superAdminDoc.exists) {
          throw new HttpsError(
              "permission-denied",
              "Only super admins can approve registrations"
          );
        }

        // Get registration request
        const registrationDoc = await admin.firestore()
            .collection("registrationRequests")
            .doc(requestId)
            .get();

        if (!registrationDoc.exists) {
          throw new HttpsError(
              "not-found",
              "Registration request not found"
          );
        }

        const registration = registrationDoc.data();

        // Check if already processed
        if (registration.status !== "pending") {
          throw new HttpsError(
              "failed-precondition",
              `Registration already ${registration.status}`
          );
        }

        // Generate temporary password
        const temporaryPassword = generateTemporaryPassword();

        // Calculate free plan phase 1 dates (30 days full functionality)
        const now = admin.firestore.Timestamp.now();
        const freePhase1EndDate = new Date(now.toMillis() + (30 * 24 * 60 * 60 * 1000));
        const freePhase1EndTimestamp = admin.firestore.Timestamp.fromDate(freePhase1EndDate);

        // Geocode business address to get work location coordinates
        let workLocation = null;
        if (registration.address) {
          workLocation = await geocodeAddress(registration.address);
          if (workLocation) {
            logger.info(`Successfully geocoded business address for ${registration.businessName}`);
          } else {
            logger.warn(`Failed to geocode address for ${registration.businessName}, geofencing will not work`);
          }
        }

        // 1. Create company document
        const companyData = {
          businessName: registration.businessName,
          industry: registration.industry,
          address: registration.address,
          workLocation, // Geocoded lat/lng for geofencing
          timezone: registration.timezone,
          numberOfEmployees: registration.numberOfEmployees,
          website: registration.website || null,

          // Owner info
          ownerName: registration.ownerName,
          ownerEmail: registration.ownerEmail,
          ownerPhone: registration.ownerPhone,
          ownerId: null, // Will be set after user creation

          // Free plan subscription (Phase 1: 30 days full features)
          currentPlan: "free",
          freePhase: 1,
          freePhase1StartDate: now,
          freePhase1EndDate: freePhase1EndTimestamp,
          freePhase2StartDate: null,
          freePhase2EndDate: null,
          status: "active",

          // Metadata
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: uid,
        };

        const companyRef = await admin.firestore()
            .collection("companies")
            .add(companyData);

        const companyId = companyRef.id;
        logger.info(`Created company: ${companyId} on Free Plan Phase 1`);

        // 2. Create Firebase Auth user
        let firebaseUser;
        try {
          firebaseUser = await admin.auth().createUser({
            email: registration.ownerEmail,
            password: temporaryPassword,
            displayName: registration.ownerName,
            emailVerified: false,
          });
          logger.info(`Created Firebase Auth user: ${firebaseUser.uid}`);
        } catch (authError) {
          // Rollback company creation
          await companyRef.delete();
          logger.error(`Failed to create auth user: ${authError.message}`);
          throw new HttpsError(
              "internal",
              `Failed to create user account: ${authError.message}`
          );
        }

        // 3. Create user document in Firestore
        try {
          const userData = {
            companyId,
            email: registration.ownerEmail,
            firstName: registration.ownerName.split(" ")[0],
            lastName: registration.ownerName.split(" ").slice(1).join(" ") || "",
            fullName: registration.ownerName,
            phoneNumber: registration.ownerPhone,
            role: "admin", // Owner is company admin
            isCompanyOwner: true,
            department: "Management",
            status: "active",
            requiresPasswordChange: true, // Force password change on first login
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          await admin.firestore()
              .collection("users")
              .doc(firebaseUser.uid)
              .set(userData);

          // Update company with ownerId
          await companyRef.update({
            ownerId: firebaseUser.uid,
          });

          logger.info(`Created user document: ${firebaseUser.uid}`);
        } catch (firestoreError) {
          // Rollback auth user and company
          await admin.auth().deleteUser(firebaseUser.uid);
          await companyRef.delete();
          logger.error(`Failed to create user document: ${firestoreError.message}`);
          throw new HttpsError(
              "internal",
              `Failed to create user profile: ${firestoreError.message}`
          );
        }

        // 4. Create HR person account if provided
        let hrUser = null;
        let hrPassword = null;
        if (registration.hrName && registration.hrEmail) {
          try {
            hrPassword = generateTemporaryPassword();

            // Create Firebase Auth user for HR person
            hrUser = await admin.auth().createUser({
              email: registration.hrEmail,
              password: hrPassword,
              displayName: registration.hrName,
              emailVerified: false,
            });
            logger.info(`Created Firebase Auth user for HR person: ${hrUser.uid}`);

            // Create Firestore user document for HR person
            const hrUserData = {
              companyId,
              email: registration.hrEmail,
              firstName: registration.hrName.split(" ")[0],
              lastName: registration.hrName.split(" ").slice(1).join(" ") || "",
              fullName: registration.hrName,
              phoneNumber: null,
              role: "admin", // HR person is also admin
              isCompanyOwner: false, // Not the owner
              department: "Human Resources",
              status: "active",
              requiresPasswordChange: true, // Force password change on first login
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            await admin.firestore()
                .collection("users")
                .doc(hrUser.uid)
                .set(hrUserData);

            logger.info(`Created HR user document: ${hrUser.uid}`);
          } catch (hrError) {
            // Log error but don't rollback entire registration
            // Owner account is still valid
            logger.error(`Failed to create HR user account: ${hrError.message}`);
            // Clean up HR auth user if it was created
            if (hrUser) {
              try {
                await admin.auth().deleteUser(hrUser.uid);
              } catch (deleteError) {
                logger.error(`Failed to delete HR auth user during rollback: ${deleteError.message}`);
              }
            }
            hrUser = null; // Clear so we don't send email
          }
        }

        // 5. Update registration status
        await registrationDoc.ref.update({
          status: "approved",
          approvedBy: uid,
          approvedAt: admin.firestore.FieldValue.serverTimestamp(),
          companyId,
        });

        logger.info(`Updated registration status to approved: ${requestId}`);

        // 6. Send welcome email to owner
        try {
          await sendWelcomeEmail({
            ownerName: registration.ownerName,
            ownerEmail: registration.ownerEmail,
            businessName: registration.businessName,
            temporaryPassword,
            freePhase1EndDate, // Changed from trialEndDate
          });
          logger.info(`Welcome email sent to: ${registration.ownerEmail}`);
        } catch (emailError) {
          // Don't fail the whole operation if email fails
          logger.error(`Failed to send welcome email: ${emailError.message}`);
        }

        // 7. Send welcome email to HR person if account was created
        if (hrUser && hrPassword) {
          try {
            await sendWelcomeEmail({
              ownerName: registration.hrName,
              ownerEmail: registration.hrEmail,
              businessName: registration.businessName,
              temporaryPassword: hrPassword,
              freePhase1EndDate, // Changed from trialEndDate
            });
            logger.info(`Welcome email sent to HR person: ${registration.hrEmail}`);
          } catch (emailError) {
            logger.error(`Failed to send HR welcome email: ${emailError.message}`);
          }
        }

        return {
          success: true,
          message: "Registration approved successfully",
          companyId,
          userId: firebaseUser.uid,
          hrUserId: hrUser ? hrUser.uid : null,
        };
      } catch (error) {
        logger.error(`Error in approveRegistration: ${error.message}`, error);
        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError("internal", error.message);
      }
    }
);

/**
 * Callable Function: Rejects a registration request
 *
 * This function:
 * 1. Updates registration status to 'rejected'
 * 2. Sends rejection email with reason
 */
const rejectRegistration = onCall(
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
              "Must be logged in to reject registrations"
          );
        }

        const uid = request.auth.uid;
        const {requestId, rejectionReason} = request.data;

        logger.info(`Rejecting registration: ${requestId} by ${uid}`);

        // Verify user is super admin
        const superAdminDoc = await admin.firestore()
            .collection("superAdmins")
            .doc(uid)
            .get();

        if (!superAdminDoc.exists) {
          throw new HttpsError(
              "permission-denied",
              "Only super admins can reject registrations"
          );
        }

        // Validate rejection reason
        if (!rejectionReason || rejectionReason.trim().length === 0) {
          throw new HttpsError(
              "invalid-argument",
              "Rejection reason is required"
          );
        }

        // Get registration request
        const registrationDoc = await admin.firestore()
            .collection("registrationRequests")
            .doc(requestId)
            .get();

        if (!registrationDoc.exists) {
          throw new HttpsError(
              "not-found",
              "Registration request not found"
          );
        }

        const registration = registrationDoc.data();

        // Check if already processed
        if (registration.status !== "pending") {
          throw new HttpsError(
              "failed-precondition",
              `Registration already ${registration.status}`
          );
        }

        // Update registration status
        await registrationDoc.ref.update({
          status: "rejected",
          rejectedBy: uid,
          rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
          rejectionReason: rejectionReason.trim(),
        });

        logger.info(`Updated registration status to rejected: ${requestId}`);

        // Send rejection email
        try {
          await sendRejectionEmail({
            ownerName: registration.ownerName,
            ownerEmail: registration.ownerEmail,
            businessName: registration.businessName,
            rejectionReason: rejectionReason.trim(),
          });
          logger.info(`Rejection email sent to: ${registration.ownerEmail}`);
        } catch (emailError) {
          // Don't fail the whole operation if email fails
          logger.error(`Failed to send rejection email: ${emailError.message}`);
        }

        return {
          success: true,
          message: "Registration rejected successfully",
        };
      } catch (error) {
        logger.error(`Error in rejectRegistration: ${error.message}`, error);
        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError("internal", error.message);
      }
    }
);

/**
 * Geocodes an address to lat/lng coordinates using Google Maps API
 * @param {Object} address - Address object with street, city, state, zip
 * @return {Promise<{lat: number, lng: number}|null>} Coordinates or null if failed
 */
async function geocodeAddress(address) {
  try {
    const fullAddress = `${address.street}, ${address.city}, ${address.state} ${address.zip}`;
    const apiKey = googleMapsApiKey.value();

    const response = await axios.get(
        "https://maps.googleapis.com/maps/api/geocode/json",
        {
          params: {
            address: fullAddress,
            key: apiKey,
          },
        }
    );

    if (response.data.status === "OK" && response.data.results.length > 0) {
      const location = response.data.results[0].geometry.location;
      logger.info(`Geocoded address "${fullAddress}" to: ${location.lat}, ${location.lng}`);
      return {
        lat: location.lat,
        lng: location.lng,
      };
    } else {
      logger.warn(`Geocoding failed for address "${fullAddress}": ${response.data.status}`);
      return null;
    }
  } catch (error) {
    logger.error(`Error geocoding address: ${error.message}`);
    return null;
  }
}

/**
 * Generates a random temporary password
 * Format: 3 words + 2 digits (e.g., "BlueSky42Mountain")
 * @return {string} Temporary password
 */
function generateTemporaryPassword() {
  const words = [
    "Blue", "Green", "Red", "Yellow", "Purple", "Orange",
    "Sky", "Ocean", "Mountain", "River", "Forest", "Desert",
    "Swift", "Bright", "Quick", "Bold", "Calm", "Brave",
  ];

  const word1 = words[Math.floor(Math.random() * words.length)];
  const word2 = words[Math.floor(Math.random() * words.length)];
  const word3 = words[Math.floor(Math.random() * words.length)];
  const numbers = Math.floor(Math.random() * 90) + 10; // 10-99

  return `${word1}${word2}${numbers}${word3}`;
}

module.exports = {
  onRegistrationSubmitted,
  approveRegistration,
  rejectRegistration,
};
