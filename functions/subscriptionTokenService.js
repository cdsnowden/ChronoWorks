/**
 * Subscription Token Service
 * Generates and validates secure tokens for email-based subscription management
 */

const admin = require('firebase-admin');
const crypto = require('crypto');
const {logger} = require('firebase-functions');

/**
 * Generates a secure token for subscription management
 * @param {string} companyId - Company ID
 * @param {string} userId - User ID (owner)
 * @param {number} expiresInHours - Token validity in hours (default: 72)
 * @return {Promise<Object>} Token data with id and url
 */
async function generateSubscriptionToken(companyId, userId, expiresInHours = 72) {
  try {
    // Generate a secure random token
    const token = crypto.randomBytes(32).toString('hex');

    // Calculate expiration time
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + (expiresInHours * 60 * 60 * 1000)
    );

    // Store token in Firestore
    const tokenData = {
      token,
      companyId,
      userId,
      purpose: 'subscription_management',
      createdAt: now,
      expiresAt,
      used: false,
      usedAt: null,
    };

    // Use token as document ID so Flutter can find it easily
    await admin.firestore()
      .collection('subscriptionChangeTokens')
      .doc(token)
      .set(tokenData);

    logger.info(`Generated subscription token ${token} for company ${companyId}`);

    return {
      tokenId: token,
      token,
      expiresAt,
      managementUrl: `https://chronoworks.co/subscription/manage?token=${token}`,
    };
  } catch (error) {
    logger.error('Error generating subscription token:', error);
    throw error;
  }
}

/**
 * Validates a subscription token
 * @param {string} token - Token string
 * @return {Promise<Object|null>} Token data if valid, null if invalid
 */
async function validateSubscriptionToken(token) {
  try {
    const now = admin.firestore.Timestamp.now();

    // Find the token
    const tokensSnapshot = await admin.firestore()
      .collection('subscriptionChangeTokens')
      .where('token', '==', token)
      .where('used', '==', false)
      .where('expiresAt', '>', now)
      .limit(1)
      .get();

    if (tokensSnapshot.empty) {
      logger.warn(`Invalid or expired token: ${token.substring(0, 10)}...`);
      return null;
    }

    const tokenDoc = tokensSnapshot.docs[0];
    const tokenData = tokenDoc.data();

    // Mark token as used (one-time use)
    await tokenDoc.ref.update({
      used: true,
      usedAt: now,
    });

    logger.info(`Token ${tokenDoc.id} validated and marked as used`);

    return {
      tokenId: tokenDoc.id,
      companyId: tokenData.companyId,
      userId: tokenData.userId,
      ...tokenData,
    };
  } catch (error) {
    logger.error('Error validating subscription token:', error);
    return null;
  }
}

/**
 * Cleans up expired tokens (call this periodically)
 * @return {Promise<number>} Number of tokens deleted
 */
async function cleanupExpiredTokens() {
  try {
    const now = admin.firestore.Timestamp.now();

    const expiredTokensSnapshot = await admin.firestore()
      .collection('subscriptionChangeTokens')
      .where('expiresAt', '<', now)
      .get();

    const batch = admin.firestore().batch();
    expiredTokensSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();

    logger.info(`Cleaned up ${expiredTokensSnapshot.size} expired tokens`);
    return expiredTokensSnapshot.size;
  } catch (error) {
    logger.error('Error cleaning up expired tokens:', error);
    return 0;
  }
}

module.exports = {
  generateSubscriptionToken,
  validateSubscriptionToken,
  cleanupExpiredTokens,
};
