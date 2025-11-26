const {onCall} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const {sendUpgradeConfirmationEmail, sendDowngradeScheduledEmail} = require("./emailService");

const db = admin.firestore();

// Plan definitions with pricing and features
// Prices must match seed_subscription_plans.js
const PLANS = {
  free: {
    name: "Free",
    monthlyPrice: 0,
    yearlyPrice: 0,
    maxEmployees: 10,
    level: 0,
  },
  starter: {
    name: "Starter",
    monthlyPrice: 24.99,
    yearlyPrice: 249.99, // Save ~17%
    maxEmployees: 12,
    level: 1,
  },
  bronze: {
    name: "Bronze",
    monthlyPrice: 49.99,
    yearlyPrice: 499.99, // Save ~17%
    maxEmployees: 25,
    level: 2,
  },
  silver: {
    name: "Silver",
    monthlyPrice: 89.99,
    yearlyPrice: 899.99, // Save ~17%
    maxEmployees: 50,
    level: 3,
  },
  gold: {
    name: "Gold",
    monthlyPrice: 149.99,
    yearlyPrice: 1499.99, // Save ~17%
    maxEmployees: 100,
    level: 4,
  },
  platinum: {
    name: "Platinum",
    monthlyPrice: 249.99,
    yearlyPrice: 2499.99, // Save ~17%
    maxEmployees: 250,
    level: 5,
  },
  diamond: {
    name: "Diamond",
    monthlyPrice: 499.99,
    yearlyPrice: 4999.99, // Save ~17%
    maxEmployees: 999999, // unlimited
    level: 6,
  },
};

/**
 * Changes a company's subscription plan
 * Handles upgrades (immediate) and downgrades (scheduled)
 */
exports.changePlan = onCall({region: "us-central1"}, async (request) => {
  try {
    // Verify authentication
    if (!request.auth) {
      throw new Error("Unauthorized: Authentication required");
    }

    const userId = request.auth.uid;
    const {newPlan, newBillingCycle = "monthly", immediate = null} = request.data;

    // Validate inputs
    if (!newPlan || !PLANS[newPlan]) {
      throw new Error(`Invalid plan: ${newPlan}`);
    }

    if (!["monthly", "yearly"].includes(newBillingCycle)) {
      throw new Error(`Invalid billing cycle: ${newBillingCycle}`);
    }

    // Get user's company
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new Error("User not found");
    }

    const userData = userDoc.data();
    const companyId = userData.companyId;

    if (!companyId) {
      throw new Error("User is not associated with a company");
    }

    // Get company data
    const companyDoc = await db.collection("companies").doc(companyId).get();
    if (!companyDoc.exists) {
      throw new Error("Company not found");
    }

    const companyData = companyDoc.data();
    const currentPlan = companyData.currentPlan || "free";
    const currentBillingCycle = companyData.billingCycle || null;

    // Check if user has permission to change plan
    const userRole = userData.role || "user";
    const allowedRoles = ["admin", "owner", "superadmin"];
    if (!allowedRoles.includes(userRole)) {
      throw new Error("Insufficient permissions to change subscription plan");
    }

    // Prevent no-op changes
    if (currentPlan === newPlan && currentBillingCycle === newBillingCycle) {
      throw new Error("You are already on this plan and billing cycle");
    }

    // Determine if upgrade or downgrade
    const currentPlanLevel = PLANS[currentPlan].level;
    const newPlanLevel = PLANS[newPlan].level;
    const isUpgrade = newPlanLevel > currentPlanLevel;
    const isDowngrade = newPlanLevel < currentPlanLevel;
    const isBillingCycleChange = currentPlan === newPlan && currentBillingCycle !== newBillingCycle;

    // Business rules
    let effectiveImmediately = false;
    let effectiveDate = null;

    if (isUpgrade) {
      // Upgrades are always immediate
      effectiveImmediately = true;
      effectiveDate = admin.firestore.Timestamp.now();

      // Check if payment method required for free → paid transition
      if (currentPlan === "free" && newPlan !== "free") {
        if (!companyData.hasPaymentMethod) {
          throw new Error("Payment method required. Please add a payment method before upgrading.");
        }
      }
    } else if (isDowngrade || isBillingCycleChange) {
      // Downgrades and billing cycle changes happen at next renewal
      effectiveImmediately = false;

      // Calculate next billing date (end of current period)
      const nextBillingDate = companyData.nextBillingDate;
      if (!nextBillingDate) {
        // If no next billing date, default to 30 days from now
        effectiveDate = admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        );
      } else {
        effectiveDate = nextBillingDate;
      }
    }

    // Allow explicit immediate parameter for testing/admin overrides
    if (immediate !== null) {
      effectiveImmediately = immediate;
      if (immediate) {
        effectiveDate = admin.firestore.Timestamp.now();
      }
    }

    // Calculate prorated amounts for immediate upgrades
    let proratedCredit = 0;
    let proratedCharge = 0;
    let totalDueToday = 0;

    if (effectiveImmediately && isUpgrade && currentPlan !== "free") {
      // Calculate prorated credit and charge
      const now = new Date();
      const nextBilling = companyData.nextBillingDate?.toDate() || new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
      const lastBilling = companyData.lastBillingDate?.toDate() || new Date(now.getTime() - 1 * 24 * 60 * 60 * 1000);

      const totalPeriodDays = Math.ceil((nextBilling - lastBilling) / (1000 * 60 * 60 * 24));
      const remainingDays = Math.ceil((nextBilling - now) / (1000 * 60 * 60 * 24));

      // Credit for unused time on current plan
      const currentPrice = currentBillingCycle === "yearly" ?
        PLANS[currentPlan].yearlyPrice :
        PLANS[currentPlan].monthlyPrice;

      proratedCredit = (currentPrice * remainingDays) / totalPeriodDays;

      // Charge for new plan
      const newPrice = newBillingCycle === "yearly" ?
        PLANS[newPlan].yearlyPrice :
        PLANS[newPlan].monthlyPrice;

      proratedCharge = newPrice;
      totalDueToday = Math.max(0, proratedCharge - proratedCredit);

      // Round to 2 decimals
      proratedCredit = Math.round(proratedCredit * 100) / 100;
      proratedCharge = Math.round(proratedCharge * 100) / 100;
      totalDueToday = Math.round(totalDueToday * 100) / 100;
    } else if (effectiveImmediately && currentPlan === "free") {
      // Free to paid - charge full amount
      totalDueToday = newBillingCycle === "yearly" ?
        PLANS[newPlan].yearlyPrice :
        PLANS[newPlan].monthlyPrice;
      proratedCharge = totalDueToday;
    }

    // Prepare update data
    const updateData = {};
    const changeType = isUpgrade ? "upgrade" : (isDowngrade ? "downgrade" : "billing_cycle_change");

    if (effectiveImmediately) {
      // Apply change immediately
      updateData.currentPlan = newPlan;
      updateData.billingCycle = newBillingCycle;
      updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();

      // Update billing dates
      if (currentPlan === "free") {
        // Starting paid subscription
        updateData.lastBillingDate = admin.firestore.Timestamp.now();
        const nextBilling = new Date();
        if (newBillingCycle === "monthly") {
          nextBilling.setMonth(nextBilling.getMonth() + 1);
        } else {
          nextBilling.setFullYear(nextBilling.getFullYear() + 1);
        }
        updateData.nextBillingDate = admin.firestore.Timestamp.fromDate(nextBilling);
        updateData.billingStatus = "active";
      }

      // Add to plan history
      updateData.planHistory = admin.firestore.FieldValue.arrayUnion({
        plan: newPlan,
        billingCycle: newBillingCycle,
        startDate: admin.firestore.Timestamp.now(),
        endDate: null,
        reason: changeType,
      });

      // Clear any scheduled changes
      updateData.scheduledPlanChange = admin.firestore.FieldValue.delete();
    } else {
      // Schedule change for future
      updateData.scheduledPlanChange = {
        newPlan: newPlan,
        newBillingCycle: newBillingCycle,
        effectiveDate: effectiveDate,
        scheduledAt: admin.firestore.Timestamp.now(),
        scheduledBy: userId,
        reason: changeType,
      };
      updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    }

    // Update company document
    await db.collection("companies").doc(companyId).update(updateData);

    // Create audit log in subscriptionChanges collection
    await db.collection("subscriptionChanges").add({
      companyId: companyId,
      companyName: companyData.companyName || "Unknown",
      userId: userId,
      userName: userData.name || "Unknown",
      userEmail: userData.email || "",

      changeType: changeType,

      fromPlan: currentPlan,
      toPlan: newPlan,
      fromBillingCycle: currentBillingCycle,
      toBillingCycle: newBillingCycle,

      effectiveDate: effectiveDate,
      scheduledDate: admin.firestore.Timestamp.now(),
      immediate: effectiveImmediately,

      reason: "customer_initiated",
      notes: effectiveImmediately ?
        `${changeType} from ${currentPlan} to ${newPlan}` :
        `Scheduled ${changeType} from ${currentPlan} to ${newPlan} for ${effectiveDate.toDate().toDateString()}`,

      // Financial
      proratedCredit: proratedCredit,
      proratedCharge: proratedCharge,
      totalDueToday: totalDueToday,

      // Status
      status: effectiveImmediately ? "completed" : "pending",
      completedAt: effectiveImmediately ? admin.firestore.Timestamp.now() : null,

      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send confirmation email
    try {
      const ownerEmail = companyData.ownerEmail || userData.email;
      const ownerName = companyData.ownerName || userData.name;

      if (effectiveImmediately && isUpgrade) {
        await sendUpgradeConfirmationEmail({
          toEmail: ownerEmail,
          toName: ownerName,
          companyName: companyData.companyName || "Your Company",
          planName: PLANS[newPlan].name,
          billingCycle: newBillingCycle,
          amount: newBillingCycle === "yearly" ? PLANS[newPlan].yearlyPrice : PLANS[newPlan].monthlyPrice,
          nextChargeDate: updateData.nextBillingDate?.toDate() || new Date(),
          proratedAmount: totalDueToday,
        });
      } else if (!effectiveImmediately && isDowngrade) {
        await sendDowngradeScheduledEmail({
          toEmail: ownerEmail,
          toName: ownerName,
          companyName: companyData.companyName || "Your Company",
          currentPlan: PLANS[currentPlan].name,
          newPlan: PLANS[newPlan].name,
          currentAmount: currentBillingCycle === "yearly" ? PLANS[currentPlan].yearlyPrice : PLANS[currentPlan].monthlyPrice,
          newAmount: newBillingCycle === "yearly" ? PLANS[newPlan].yearlyPrice : PLANS[newPlan].monthlyPrice,
          effectiveDate: effectiveDate.toDate(),
          billingCycle: newBillingCycle,
        });
      }
    } catch (emailError) {
      logger.error("Failed to send subscription change email:", emailError);
      // Don't fail the entire operation if email fails
    }

    // Build response
    const response = {
      success: true,
      effectiveDate: effectiveDate.toDate().toISOString(),
      immediate: effectiveImmediately,
      changeType: changeType,
      message: effectiveImmediately ?
        `Successfully ${changeType}d to ${PLANS[newPlan].name} plan` :
        `${changeType} to ${PLANS[newPlan].name} scheduled for ${effectiveDate.toDate().toDateString()}`,
    };

    if (effectiveImmediately) {
      response.proratedCredit = proratedCredit;
      response.proratedCharge = proratedCharge;
      response.totalDueToday = totalDueToday;
      response.nextBillingDate = updateData.nextBillingDate?.toDate().toISOString();
    }

    logger.info(`Subscription change: ${changeType} for company ${companyId} from ${currentPlan} to ${newPlan}`);

    return response;
  } catch (error) {
    logger.error("Error in changePlan:", error);
    throw new Error(error.message || "Failed to change subscription plan");
  }
});

/**
 * Cancels a scheduled plan change
 */
exports.cancelScheduledChange = onCall({region: "us-central1"}, async (request) => {
  try {
    // Verify authentication
    if (!request.auth) {
      throw new Error("Unauthorized: Authentication required");
    }

    const userId = request.auth.uid;

    // Get user's company
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new Error("User not found");
    }

    const userData = userDoc.data();
    const companyId = userData.companyId;

    if (!companyId) {
      throw new Error("User is not associated with a company");
    }

    // Check permissions
    const userRole = userData.role || "user";
    const allowedRoles = ["admin", "owner", "superadmin"];
    if (!allowedRoles.includes(userRole)) {
      throw new Error("Insufficient permissions to cancel scheduled changes");
    }

    // Get company data
    const companyDoc = await db.collection("companies").doc(companyId).get();
    if (!companyDoc.exists) {
      throw new Error("Company not found");
    }

    const companyData = companyDoc.data();

    // Check if there's a scheduled change
    if (!companyData.scheduledPlanChange) {
      throw new Error("No scheduled plan change found");
    }

    const scheduledChange = companyData.scheduledPlanChange;

    // Remove scheduled change
    await db.collection("companies").doc(companyId).update({
      scheduledPlanChange: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log the cancellation
    await db.collection("subscriptionChanges").add({
      companyId: companyId,
      companyName: companyData.companyName || "Unknown",
      userId: userId,
      userName: userData.name || "Unknown",
      userEmail: userData.email || "",

      changeType: "cancellation",

      fromPlan: scheduledChange.newPlan,
      toPlan: companyData.currentPlan,
      fromBillingCycle: scheduledChange.newBillingCycle,
      toBillingCycle: companyData.billingCycle,

      effectiveDate: admin.firestore.Timestamp.now(),
      scheduledDate: admin.firestore.Timestamp.now(),
      immediate: true,

      reason: "customer_cancelled_scheduled_change",
      notes: `Cancelled scheduled ${scheduledChange.reason} from ${companyData.currentPlan} to ${scheduledChange.newPlan}`,

      proratedCredit: 0,
      proratedCharge: 0,
      totalDueToday: 0,

      status: "completed",
      completedAt: admin.firestore.Timestamp.now(),

      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Cancelled scheduled plan change for company ${companyId}`);

    return {
      success: true,
      message: "Scheduled plan change has been cancelled",
    };
  } catch (error) {
    logger.error("Error in cancelScheduledChange:", error);
    throw new Error(error.message || "Failed to cancel scheduled change");
  }
});

/**
 * Gets a preview of what an upgrade/downgrade would cost
 */
exports.getUpgradePreview = onCall({region: "us-central1"}, async (request) => {
  try {
    // Verify authentication
    if (!request.auth) {
      throw new Error("Unauthorized: Authentication required");
    }

    const userId = request.auth.uid;
    const {newPlan, newBillingCycle = "monthly"} = request.data;

    // Validate inputs
    if (!newPlan || !PLANS[newPlan]) {
      throw new Error(`Invalid plan: ${newPlan}`);
    }

    if (!["monthly", "yearly"].includes(newBillingCycle)) {
      throw new Error(`Invalid billing cycle: ${newBillingCycle}`);
    }

    // Get user's company
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new Error("User not found");
    }

    const userData = userDoc.data();
    const companyId = userData.companyId;

    if (!companyId) {
      throw new Error("User is not associated with a company");
    }

    // Get company data
    const companyDoc = await db.collection("companies").doc(companyId).get();
    if (!companyDoc.exists) {
      throw new Error("Company not found");
    }

    const companyData = companyDoc.data();
    const currentPlan = companyData.currentPlan || "free";
    const currentBillingCycle = companyData.billingCycle || null;

    // Calculate costs
    const currentPlanLevel = PLANS[currentPlan].level;
    const newPlanLevel = PLANS[newPlan].level;
    const isUpgrade = newPlanLevel > currentPlanLevel;

    let proratedCredit = 0;
    let newPlanCharge = 0;
    let totalDueToday = 0;
    let savings = 0;

    // Calculate new plan charge
    newPlanCharge = newBillingCycle === "yearly" ?
      PLANS[newPlan].yearlyPrice :
      PLANS[newPlan].monthlyPrice;

    if (isUpgrade && currentPlan !== "free") {
      // Calculate prorated credit
      const now = new Date();
      const nextBilling = companyData.nextBillingDate?.toDate() || new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
      const lastBilling = companyData.lastBillingDate?.toDate() || new Date(now.getTime() - 1 * 24 * 60 * 60 * 1000);

      const totalPeriodDays = Math.ceil((nextBilling - lastBilling) / (1000 * 60 * 60 * 24));
      const remainingDays = Math.ceil((nextBilling - now) / (1000 * 60 * 60 * 24));

      const currentPrice = currentBillingCycle === "yearly" ?
        PLANS[currentPlan].yearlyPrice :
        PLANS[currentPlan].monthlyPrice;

      proratedCredit = (currentPrice * remainingDays) / totalPeriodDays;
      totalDueToday = Math.max(0, newPlanCharge - proratedCredit);

      // Round to 2 decimals
      proratedCredit = Math.round(proratedCredit * 100) / 100;
      totalDueToday = Math.round(totalDueToday * 100) / 100;
    } else if (currentPlan === "free") {
      totalDueToday = newPlanCharge;
    }

    // Calculate annual savings
    if (newBillingCycle === "yearly") {
      const monthlyEquivalent = PLANS[newPlan].monthlyPrice * 12;
      savings = monthlyEquivalent - PLANS[newPlan].yearlyPrice;
    }

    const response = {
      success: true,
      currentPlan: currentPlan,
      currentPlanName: PLANS[currentPlan].name,
      currentBillingCycle: currentBillingCycle,
      newPlan: newPlan,
      newPlanName: PLANS[newPlan].name,
      newBillingCycle: newBillingCycle,
      isUpgrade: isUpgrade,
      immediate: isUpgrade,
      proratedCredit: proratedCredit,
      newPlanCharge: newPlanCharge,
      totalDueToday: totalDueToday,
      savings: savings,
      nextBillingDate: companyData.nextBillingDate?.toDate().toISOString() || null,
      hasPaymentMethod: companyData.hasPaymentMethod || false,
    };

    return response;
  } catch (error) {
    logger.error("Error in getUpgradePreview:", error);
    throw new Error(error.message || "Failed to get upgrade preview");
  }
});
