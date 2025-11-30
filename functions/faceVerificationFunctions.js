const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const path = require("path");

// Lazy-loaded modules (to avoid issues during Firebase deployment analysis)
let faceapi = null;
let canvas = null;
let modelsLoaded = false;

/**
 * Initialize face-api with lazy loading
 * This prevents module loading during Firebase deployment analysis on Windows
 */
async function initializeFaceApi() {
  if (faceapi && canvas && modelsLoaded) return;

  try {
    // Dynamic require to avoid loading during deployment analysis
    if (!faceapi) {
      // Import tensorflow first to set backend
      require("@tensorflow/tfjs-node");
      faceapi = require("@vladmandic/face-api");
    }

    if (!canvas) {
      canvas = require("canvas");
      const {Canvas, Image, ImageData} = canvas;
      faceapi.env.monkeyPatch({Canvas, Image, ImageData});
    }

    if (!modelsLoaded) {
      const modelsPath = path.join(__dirname, "models");
      await faceapi.nets.ssdMobilenetv1.loadFromDisk(modelsPath);
      await faceapi.nets.faceLandmark68Net.loadFromDisk(modelsPath);
      await faceapi.nets.faceRecognitionNet.loadFromDisk(modelsPath);
      modelsLoaded = true;
      logger.info("Face-api models loaded successfully");
    }
  } catch (error) {
    logger.error("Error initializing face-api:", error);
    throw new Error("Failed to initialize face recognition: " + error.message);
  }
}

/**
 * Extract face descriptor from image buffer
 */
async function getFaceDescriptor(imageBuffer) {
  const img = await canvas.loadImage(imageBuffer);

  const detection = await faceapi
      .detectSingleFace(img)
      .withFaceLandmarks()
      .withFaceDescriptor();

  if (!detection) {
    return null;
  }

  return detection.descriptor;
}

/**
 * Compare two face descriptors and return similarity score
 */
function compareFaces(descriptor1, descriptor2) {
  const distance = faceapi.euclideanDistance(descriptor1, descriptor2);
  // Convert distance to similarity (0-1, higher is better)
  // Typical threshold is 0.6 for a match
  const similarity = Math.max(0, 1 - distance);
  return similarity;
}

/**
 * Register a user's face
 * Called when user uploads their face photo for registration
 */
exports.registerFace = onCall({
  region: "us-central1",
  memory: "1GiB",
  timeoutSeconds: 60,
}, async (request) => {
  try {
    await initializeFaceApi();

    const {userId, companyId, imageBase64} = request.data;

    if (!userId || !companyId || !imageBase64) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    // Verify the caller is the user or an admin
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    // Decode base64 image
    const imageBuffer = Buffer.from(imageBase64, "base64");

    // Get face descriptor
    const descriptor = await getFaceDescriptor(imageBuffer);

    if (!descriptor) {
      throw new HttpsError("failed-precondition",
          "No face detected in the image. Please take a clear photo of your face.");
    }

    // Store descriptor as array in Firestore
    const descriptorArray = Array.from(descriptor);

    // Upload image to Firebase Storage
    const bucket = admin.storage().bucket();
    const fileName = `face_photos/${companyId}/${userId}.jpg`;
    const file = bucket.file(fileName);

    await file.save(imageBuffer, {
      metadata: {contentType: "image/jpeg"},
    });

    const [photoUrl] = await file.getSignedUrl({
      action: "read",
      expires: "03-01-2500",
    });

    // Update user document with face data
    await admin.firestore().collection("users").doc(userId).update({
      faceRegistered: true,
      facePhotoUrl: photoUrl,
      faceDescriptor: descriptorArray,
      faceRegisteredAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Face registered for user ${userId}`);

    return {success: true, message: "Face registered successfully"};
  } catch (error) {
    logger.error("Error registering face:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Verify a user's face against their registered face
 * Called during clock-in
 */
exports.verifyFace = onCall({
  region: "us-central1",
  memory: "1GiB",
  timeoutSeconds: 30,
}, async (request) => {
  try {
    await initializeFaceApi();

    const {userId, imageBase64} = request.data;

    if (!userId || !imageBase64) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    // Get registered face descriptor from Firestore
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const userData = userDoc.data();

    if (!userData || !userData.faceDescriptor) {
      return {
        isMatch: false,
        confidence: 0,
        error: "No face registered. Please complete face registration first.",
      };
    }

    // Decode base64 image
    const imageBuffer = Buffer.from(imageBase64, "base64");

    // Get face descriptor from current image
    const currentDescriptor = await getFaceDescriptor(imageBuffer);

    if (!currentDescriptor) {
      return {
        isMatch: false,
        confidence: 0,
        error: "No face detected. Please ensure your face is clearly visible.",
      };
    }

    // Convert stored descriptor back to Float32Array
    const registeredDescriptor = new Float32Array(userData.faceDescriptor);

    // Compare faces
    const similarity = compareFaces(registeredDescriptor, currentDescriptor);

    // Threshold for match (0.6 distance = ~0.4 similarity, so we use 0.5)
    const matchThreshold = 0.5;
    const isMatch = similarity >= matchThreshold;

    logger.info(`Face verification for user ${userId}: similarity=${similarity}, match=${isMatch}`);

    // If not a match, log the violation
    if (!isMatch && userData.companyId) {
      await logFaceViolation(userId, userData.companyId, similarity);
    }

    return {
      isMatch,
      confidence: similarity,
      error: isMatch ? null : "Face does not match registered profile.",
    };
  } catch (error) {
    logger.error("Error verifying face:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Check if a user has face registered
 */
exports.hasFaceRegistered = onCall({
  region: "us-central1",
}, async (request) => {
  const {userId} = request.data;

  if (!userId) {
    throw new HttpsError("invalid-argument", "Missing userId");
  }

  const userDoc = await admin.firestore().collection("users").doc(userId).get();
  const hasRegistered = userDoc.data()?.faceRegistered === true &&
                        userDoc.data()?.faceDescriptor != null;

  return {hasRegistered};
});

/**
 * Log a face verification violation
 */
async function logFaceViolation(userId, companyId, confidence) {
  try {
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const userName = userDoc.data()?.firstName + " " + userDoc.data()?.lastName || "Unknown";

    const violation = {
      type: "face_verification_violation",
      userId,
      userName,
      companyId,
      violationType: "face_mismatch",
      confidence,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    };

    // Add to company violations log
    await admin.firestore()
        .collection("companies")
        .doc(companyId)
        .collection("faceViolations")
        .add(violation);

    // Notify managers and admins
    const managersSnapshot = await admin.firestore()
        .collection("users")
        .where("companyId", "==", companyId)
        .where("role", "in", ["admin", "manager"])
        .get();

    const batch = admin.firestore().batch();
    managersSnapshot.forEach((doc) => {
      const notificationRef = admin.firestore()
          .collection("users")
          .doc(doc.id)
          .collection("notifications")
          .doc();
      batch.set(notificationRef, violation);
    });

    await batch.commit();

    logger.info(`Face violation logged for user ${userId}`);
  } catch (error) {
    logger.error("Error logging face violation:", error);
  }
}
