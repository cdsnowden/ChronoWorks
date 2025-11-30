/**
 * Compliance Rules Update Functions
 *
 * Automatically checks for and applies compliance rule updates every 30 days.
 * Also provides manual update triggers for super admins.
 */

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const sgMail = require('@sendgrid/mail');

// Initialize SendGrid
if (process.env.SENDGRID_API_KEY) {
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);
}

const db = getFirestore();

// Current rules version - Update this when labor laws change
const CURRENT_RULES_VERSION = '2024.1.0';
const RULES_SOURCE_URL = 'https://chronoworks.co/compliance-rules.json'; // Future: external source

/**
 * Scheduled function - Runs every 30 days to check for compliance rule updates
 * Schedule: At 3:00 AM on day 1 of every month
 */
exports.checkComplianceUpdates = onSchedule({
  schedule: '0 3 1 * *', // 3 AM on the 1st of each month
  timeZone: 'America/New_York',
  memory: '512MiB',
  timeoutSeconds: 300,
}, async (event) => {
  console.log('Starting monthly compliance rules check...');

  try {
    const result = await performComplianceCheck();
    console.log('Compliance check completed:', result);
    return result;
  } catch (error) {
    console.error('Error during compliance check:', error);
    await notifyAdminsOfError(error);
    throw error;
  }
});

/**
 * Manual trigger for compliance update check (Super Admin only)
 */
exports.triggerComplianceCheck = onCall({
  memory: '512MiB',
  timeoutSeconds: 300,
}, async (request) => {
  // Verify super admin
  const { auth } = request;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }

  const userDoc = await db.collection('superAdmins').doc(auth.uid).get();
  if (!userDoc.exists) {
    throw new HttpsError('permission-denied', 'Only super admins can trigger compliance checks');
  }

  console.log(`Manual compliance check triggered by ${auth.uid}`);

  try {
    const result = await performComplianceCheck();
    return { success: true, result };
  } catch (error) {
    console.error('Error during manual compliance check:', error);
    throw new HttpsError('internal', error.message);
  }
});

/**
 * Get compliance rules status
 */
exports.getComplianceStatus = onCall({
  memory: '256MiB',
}, async (request) => {
  const { auth } = request;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }

  try {
    const metadataDoc = await db.collection('complianceMetadata').doc('rulesInfo').get();
    const updateLogSnapshot = await db.collection('complianceUpdateLog')
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();

    const updateLog = updateLogSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toDate?.() || null,
    }));

    return {
      currentVersion: CURRENT_RULES_VERSION,
      metadata: metadataDoc.exists ? {
        ...metadataDoc.data(),
        lastUpdated: metadataDoc.data().lastUpdated?.toDate?.() || null,
      } : null,
      recentUpdates: updateLog,
    };
  } catch (error) {
    console.error('Error getting compliance status:', error);
    throw new HttpsError('internal', error.message);
  }
});

/**
 * Main compliance check function
 */
async function performComplianceCheck() {
  const startTime = Date.now();
  const results = {
    checked: true,
    timestamp: new Date().toISOString(),
    currentVersion: CURRENT_RULES_VERSION,
    rulesUpdated: 0,
    rulesAdded: 0,
    rulesDeactivated: 0,
    errors: [],
  };

  // Get current metadata
  const metadataDoc = await db.collection('complianceMetadata').doc('rulesInfo').get();
  const currentMetadata = metadataDoc.exists ? metadataDoc.data() : null;

  // Check if update is needed
  if (currentMetadata && currentMetadata.version === CURRENT_RULES_VERSION) {
    console.log('Rules are already at current version:', CURRENT_RULES_VERSION);
    results.message = 'Rules are up to date';

    // Log the check
    await logComplianceUpdate({
      action: 'CHECK',
      version: CURRENT_RULES_VERSION,
      result: 'No updates needed',
      duration: Date.now() - startTime,
    });

    return results;
  }

  // Get current rules from Firestore
  const existingRulesSnapshot = await db.collection('complianceRules').get();
  const existingRules = new Map();
  existingRulesSnapshot.forEach(doc => {
    existingRules.set(doc.id, doc.data());
  });

  console.log(`Found ${existingRules.size} existing rules`);

  // Generate current rules
  const currentRules = generateAllRules();
  console.log(`Generated ${currentRules.length} current rules`);

  // Compare and update
  const batch = db.batch();
  let operationsInBatch = 0;
  const batchLimit = 400;

  for (const rule of currentRules) {
    const existing = existingRules.get(rule.id);

    if (!existing) {
      // New rule
      const docRef = db.collection('complianceRules').doc(rule.id);
      batch.set(docRef, rule);
      results.rulesAdded++;
      operationsInBatch++;
      console.log(`Adding new rule: ${rule.id}`);
    } else if (hasRuleChanged(existing, rule)) {
      // Updated rule
      const docRef = db.collection('complianceRules').doc(rule.id);
      batch.set(docRef, {
        ...rule,
        previousVersion: existing.version,
        updatedAt: Timestamp.now(),
      }, { merge: true });
      results.rulesUpdated++;
      operationsInBatch++;
      console.log(`Updating rule: ${rule.id}`);
    }

    // Remove from existing map (to track deactivated rules)
    existingRules.delete(rule.id);

    // Commit batch if approaching limit
    if (operationsInBatch >= batchLimit) {
      await batch.commit();
      operationsInBatch = 0;
    }
  }

  // Handle removed rules (mark as inactive, don't delete)
  for (const [ruleId, rule] of existingRules) {
    if (rule.isActive !== false) {
      const docRef = db.collection('complianceRules').doc(ruleId);
      batch.update(docRef, {
        isActive: false,
        deactivatedAt: Timestamp.now(),
        deactivationReason: 'Rule removed in version ' + CURRENT_RULES_VERSION,
      });
      results.rulesDeactivated++;
      operationsInBatch++;
      console.log(`Deactivating rule: ${ruleId}`);
    }
  }

  // Final batch commit
  if (operationsInBatch > 0) {
    await batch.commit();
  }

  // Update metadata
  await db.collection('complianceMetadata').doc('rulesInfo').set({
    version: CURRENT_RULES_VERSION,
    lastUpdated: Timestamp.now(),
    lastCheckTimestamp: Timestamp.now(),
    totalRules: currentRules.length,
    federalRules: currentRules.filter(r => r.jurisdiction === 'federal').length,
    stateRules: currentRules.filter(r => r.jurisdiction === 'state').length,
    cityRules: currentRules.filter(r => r.jurisdiction === 'city').length,
  });

  // Log the update
  await logComplianceUpdate({
    action: 'UPDATE',
    version: CURRENT_RULES_VERSION,
    previousVersion: currentMetadata?.version || 'none',
    rulesAdded: results.rulesAdded,
    rulesUpdated: results.rulesUpdated,
    rulesDeactivated: results.rulesDeactivated,
    duration: Date.now() - startTime,
  });

  // Notify admins if significant changes
  if (results.rulesAdded > 0 || results.rulesUpdated > 0 || results.rulesDeactivated > 0) {
    await notifyAdminsOfUpdate(results);
  }

  results.message = `Update complete. Added: ${results.rulesAdded}, Updated: ${results.rulesUpdated}, Deactivated: ${results.rulesDeactivated}`;
  console.log(results.message);

  return results;
}

/**
 * Check if a rule has changed
 */
function hasRuleChanged(existing, current) {
  // Compare key fields
  const fieldsToCompare = [
    'name', 'description', 'hoursThreshold', 'durationMinutes',
    'overtimeThreshold', 'overtimeMultiplier', 'advanceNoticeDays',
    'enforcementAction', 'isWaivable', 'waiverRequirements', 'legalReference'
  ];

  for (const field of fieldsToCompare) {
    if (existing[field] !== current[field]) {
      return true;
    }
  }

  // Check version
  if (existing.version !== current.version) {
    return true;
  }

  return false;
}

/**
 * Log compliance update activity
 */
async function logComplianceUpdate(data) {
  await db.collection('complianceUpdateLog').add({
    ...data,
    timestamp: Timestamp.now(),
  });
}

/**
 * Notify super admins of compliance update
 */
async function notifyAdminsOfUpdate(results) {
  if (!process.env.SENDGRID_API_KEY) {
    console.log('SendGrid not configured, skipping admin notification');
    return;
  }

  try {
    // Get super admin emails
    const adminsSnapshot = await db.collection('superAdmins').get();
    const adminEmails = adminsSnapshot.docs
      .map(doc => doc.data().email)
      .filter(email => email);

    if (adminEmails.length === 0) {
      console.log('No super admin emails found');
      return;
    }

    const fromEmail = process.env.SENDGRID_FROM_EMAIL || 'support@chronoworks.com';

    await sgMail.send({
      to: adminEmails,
      from: { email: fromEmail, name: 'ChronoWorks Compliance' },
      subject: `Compliance Rules Updated - Version ${CURRENT_RULES_VERSION}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #2563eb;">Compliance Rules Update</h2>
          <p>The ChronoWorks compliance rules database has been updated.</p>

          <div style="background: #f3f4f6; padding: 16px; border-radius: 8px; margin: 16px 0;">
            <p style="margin: 0;"><strong>Version:</strong> ${CURRENT_RULES_VERSION}</p>
            <p style="margin: 8px 0 0;"><strong>Date:</strong> ${new Date().toLocaleDateString()}</p>
          </div>

          <h3>Changes:</h3>
          <ul>
            <li><strong>Rules Added:</strong> ${results.rulesAdded}</li>
            <li><strong>Rules Updated:</strong> ${results.rulesUpdated}</li>
            <li><strong>Rules Deactivated:</strong> ${results.rulesDeactivated}</li>
          </ul>

          <p style="color: #6b7280; font-size: 14px;">
            These updates reflect the latest federal, state, and local labor law requirements.
            Please review any significant changes that may affect your customers.
          </p>

          <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 24px 0;">
          <p style="color: #9ca3af; font-size: 12px;">
            ChronoWorks Compliance System - Automated notification
          </p>
        </div>
      `,
    });

    console.log(`Notified ${adminEmails.length} super admins of compliance update`);
  } catch (error) {
    console.error('Error sending admin notification:', error);
  }
}

/**
 * Notify admins of errors
 */
async function notifyAdminsOfError(error) {
  if (!process.env.SENDGRID_API_KEY) {
    return;
  }

  try {
    const adminsSnapshot = await db.collection('superAdmins').get();
    const adminEmails = adminsSnapshot.docs
      .map(doc => doc.data().email)
      .filter(email => email);

    if (adminEmails.length === 0) return;

    const fromEmail = process.env.SENDGRID_FROM_EMAIL || 'support@chronoworks.com';

    await sgMail.send({
      to: adminEmails,
      from: { email: fromEmail, name: 'ChronoWorks System' },
      subject: 'Compliance Update Error - Action Required',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #dc2626;">Compliance Update Error</h2>
          <p>An error occurred during the scheduled compliance rules update.</p>

          <div style="background: #fef2f2; padding: 16px; border-radius: 8px; margin: 16px 0; border-left: 4px solid #dc2626;">
            <p style="margin: 0; color: #991b1b;"><strong>Error:</strong></p>
            <pre style="margin: 8px 0 0; white-space: pre-wrap;">${error.message}</pre>
          </div>

          <p>Please investigate and manually trigger an update if needed.</p>

          <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 24px 0;">
          <p style="color: #9ca3af; font-size: 12px;">
            ChronoWorks System Alert
          </p>
        </div>
      `,
    });
  } catch (err) {
    console.error('Error sending error notification:', err);
  }
}

/**
 * Generate all compliance rules
 * This is the same as the seed script but embedded for the update function
 */
function generateAllRules() {
  const now = Timestamp.now();
  const rules = [];

  // Helper function to create rule
  const createRule = (data) => ({
    ...data,
    version: CURRENT_RULES_VERSION,
    createdAt: now,
    updatedAt: now,
    isActive: true,
  });

  // ============================================================
  // FEDERAL RULES
  // ============================================================
  rules.push(createRule({
    id: 'fed_weekly_ot',
    name: 'Federal Weekly Overtime',
    description: 'Non-exempt employees must receive 1.5x pay for hours over 40 per week',
    category: 'weeklyOvertime',
    jurisdiction: 'federal',
    state: null,
    overtimeThreshold: 40,
    overtimeMultiplier: 1.5,
    warningMinutesBefore: 60,
    enforcementAction: 'warnManager',
    legalReference: 'FLSA Section 7(a)',
  }));

  rules.push(createRule({
    id: 'fed_minor_hours',
    name: 'Federal Minor Work Hours',
    description: 'Minors 14-15: max 3 hours on school days, 8 hours non-school days',
    category: 'minorHours',
    jurisdiction: 'federal',
    state: null,
    maxHoursSchoolDay: 3,
    maxHoursNonSchoolDay: 8,
    warningMinutesBefore: 30,
    enforcementAction: 'blockAction',
    legalReference: 'FLSA Child Labor Provisions',
  }));

  // ============================================================
  // STATE RULES - All 50 States
  // ============================================================

  // States with specific meal/rest break requirements
  const statesWithBreakLaws = {
    'CA': {
      mealBreak: { threshold: 5, duration: 30, waivable: true, reference: 'California Labor Code Section 512' },
      restBreak: { threshold: 4, duration: 10, reference: 'California Labor Code Section 226.7' },
      dailyOT: { threshold: 8, multiplier: 1.5, reference: 'California Labor Code Section 510' },
      doubleTime: { threshold: 12, multiplier: 2.0, reference: 'California Labor Code Section 510' },
    },
    'CO': {
      mealBreak: { threshold: 5, duration: 30, waivable: true, reference: 'Colorado COMPS Order #38' },
      restBreak: { threshold: 4, duration: 10, reference: 'Colorado COMPS Order #38' },
      dailyOT: { threshold: 12, multiplier: 1.5, reference: 'Colorado COMPS Order #38' },
    },
    'CT': {
      mealBreak: { threshold: 7.5, duration: 30, waivable: true, reference: 'Connecticut General Statutes Section 31-51ii' },
    },
    'DE': {
      mealBreak: { threshold: 7.5, duration: 30, reference: 'Delaware Code Title 19, Section 707' },
    },
    'IL': {
      mealBreak: { threshold: 7.5, duration: 20, reference: 'Illinois One Day Rest in Seven Act' },
    },
    'KY': {
      mealBreak: { threshold: 5, duration: 30, reference: 'Kentucky Revised Statutes 337.355' },
      restBreak: { threshold: 4, duration: 10, reference: 'Kentucky Revised Statutes 337.365' },
    },
    'ME': {
      mealBreak: { threshold: 6, duration: 30, reference: 'Maine Revised Statutes Title 26, Section 601' },
    },
    'MA': {
      mealBreak: { threshold: 6, duration: 30, waivable: true, reference: 'Massachusetts General Laws Chapter 149, Section 100' },
    },
    'MN': {
      mealBreak: { threshold: 8, duration: 30, reference: 'Minnesota Statutes Section 177.254' },
      restBreak: { threshold: 4, duration: 10, reference: 'Minnesota Statutes Section 177.253' },
    },
    'NV': {
      mealBreak: { threshold: 8, duration: 30, waivable: true, reference: 'Nevada Revised Statutes 608.019' },
      restBreak: { threshold: 4, duration: 10, reference: 'Nevada Revised Statutes 608.019' },
      dailyOT: { threshold: 8, multiplier: 1.5, reference: 'Nevada Constitution Article 15' },
    },
    'NH': {
      mealBreak: { threshold: 5, duration: 30, waivable: true, reference: 'New Hampshire RSA 275:30-a' },
    },
    'NY': {
      mealBreak: { threshold: 6, duration: 30, reference: 'New York Labor Law Section 162' },
    },
    'ND': {
      mealBreak: { threshold: 5, duration: 30, waivable: true, reference: 'North Dakota Admin Code 46-02-07-02' },
    },
    'OR': {
      mealBreak: { threshold: 6, duration: 30, waivable: true, reference: 'Oregon ORS 653.261' },
      restBreak: { threshold: 4, duration: 10, reference: 'Oregon ORS 653.261' },
    },
    'RI': {
      mealBreak: { threshold: 8, duration: 20, reference: 'Rhode Island General Laws Section 28-3-14' },
    },
    'TN': {
      mealBreak: { threshold: 6, duration: 30, reference: 'Tennessee Code Annotated Section 50-2-103' },
    },
    'VT': {
      mealBreak: { threshold: 6, duration: 30, reference: 'Vermont Statutes Title 21, Section 304' },
    },
    'WA': {
      mealBreak: { threshold: 5, duration: 30, waivable: true, reference: 'Washington WAC 296-126-092' },
      restBreak: { threshold: 4, duration: 10, reference: 'Washington WAC 296-126-092' },
    },
    'WV': {
      mealBreak: { threshold: 6, duration: 20, reference: 'West Virginia Code Section 21-3-10a' },
    },
    'AK': {
      dailyOT: { threshold: 8, multiplier: 1.5, reference: 'Alaska Statute 23.10.060' },
    },
  };

  // States that follow federal only
  const federalOnlyStates = [
    'AL', 'AZ', 'AR', 'FL', 'GA', 'HI', 'ID', 'IN', 'IA', 'KS',
    'LA', 'MI', 'MS', 'MO', 'MT', 'NE', 'NJ', 'NM', 'NC', 'OH',
    'OK', 'PA', 'SC', 'SD', 'TX', 'UT', 'VA', 'WI', 'WY'
  ];

  // Generate rules for states with specific requirements
  for (const [state, laws] of Object.entries(statesWithBreakLaws)) {
    if (laws.mealBreak) {
      rules.push(createRule({
        id: `${state.toLowerCase()}_meal_break`,
        name: `${state} Meal Break`,
        description: `Employees must receive a ${laws.mealBreak.duration}-minute meal break for shifts over ${laws.mealBreak.threshold} hours`,
        category: 'mealBreak',
        jurisdiction: 'state',
        state: state,
        hoursThreshold: laws.mealBreak.threshold,
        durationMinutes: laws.mealBreak.duration,
        warningMinutesBefore: 30,
        enforcementAction: 'warnEmployee',
        isWaivable: laws.mealBreak.waivable || false,
        legalReference: laws.mealBreak.reference,
      }));
    }

    if (laws.restBreak) {
      rules.push(createRule({
        id: `${state.toLowerCase()}_rest_break`,
        name: `${state} Rest Break`,
        description: `Employees must receive a paid ${laws.restBreak.duration}-minute rest break for every ${laws.restBreak.threshold} hours worked`,
        category: 'restBreak',
        jurisdiction: 'state',
        state: state,
        hoursThreshold: laws.restBreak.threshold,
        durationMinutes: laws.restBreak.duration,
        warningMinutesBefore: 15,
        enforcementAction: 'notify',
        legalReference: laws.restBreak.reference,
      }));
    }

    if (laws.dailyOT) {
      rules.push(createRule({
        id: `${state.toLowerCase()}_daily_ot`,
        name: `${state} Daily Overtime`,
        description: `Employees must receive ${laws.dailyOT.multiplier}x pay for hours over ${laws.dailyOT.threshold} per day`,
        category: 'dailyOvertime',
        jurisdiction: 'state',
        state: state,
        overtimeThreshold: laws.dailyOT.threshold,
        overtimeMultiplier: laws.dailyOT.multiplier,
        warningMinutesBefore: 60,
        enforcementAction: 'warnManager',
        legalReference: laws.dailyOT.reference,
      }));
    }

    if (laws.doubleTime) {
      rules.push(createRule({
        id: `${state.toLowerCase()}_double_time`,
        name: `${state} Double Time`,
        description: `Employees must receive ${laws.doubleTime.multiplier}x pay for hours over ${laws.doubleTime.threshold} per day`,
        category: 'doubleTime',
        jurisdiction: 'state',
        state: state,
        overtimeThreshold: laws.doubleTime.threshold,
        overtimeMultiplier: laws.doubleTime.multiplier,
        warningMinutesBefore: 30,
        enforcementAction: 'warnManager',
        legalReference: laws.doubleTime.reference,
      }));
    }
  }

  // Generate rules for federal-only states
  for (const state of federalOnlyStates) {
    rules.push(createRule({
      id: `${state.toLowerCase()}_federal`,
      name: `${state} - Federal Standards Apply`,
      description: `${state} has no state-specific meal or rest break requirements. Federal FLSA standards apply.`,
      category: 'weeklyOvertime',
      jurisdiction: 'state',
      state: state,
      overtimeThreshold: 40,
      overtimeMultiplier: 1.5,
      warningMinutesBefore: 60,
      enforcementAction: 'warnManager',
      legalReference: `${state} follows federal FLSA`,
    }));
  }

  return rules;
}
