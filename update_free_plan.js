const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function updateFreePlan() {
  try {
    // Get the free plan
    const plansSnapshot = await admin.firestore()
      .collection('subscriptionPlans')
      .where('planId', '==', 'free')
      .get();

    if (plansSnapshot.empty) {
      console.log('Free plan not found');
      process.exit(1);
    }

    const freePlanDoc = plansSnapshot.docs[0];

    // Enable ALL features for free plan
    const allFeatures = {
      scheduleManagement: true,
      clockInOut: true,
      basicReporting: true,
      breakTracking: true,
      shiftTemplates: true,
      photoVerification: true,
      departmentManagement: true,
      roleBasedPermissions: true,
      overtimeTracking: true,
      missedClockoutAlerts: true,
      lateClockInAlerts: true,
      gpsTracking: true,
      advancedReporting: true,
      exportData: true,
      shiftSwapping: true,
      autoScheduling: true,
      payrollIntegration: true,
      laborCostTracking: true,
      paidTimeOff: true,
      customDashboards: true,
      historicalTrends: true,
      apiAccess: true,
      customIntegrations: true,
      biometricClockIn: true,
      teamMessaging: true,
      complianceReports: true,
      emailSupport: true,
      prioritySupport: true,
      phoneSupport: true,
      dedicatedManager: true,
    };

    // Update the free plan with all features and new tagline
    await freePlanDoc.ref.update({
      features: allFeatures,
      tagline: 'Enjoy all functions for 30 days',
      description: 'Full access to all features for the first 30 days, then limited features for days 31-60'
    });

    console.log('✓ Free plan updated successfully!');
    console.log('✓ All features enabled');
    console.log('✓ Tagline set to: "Enjoy all functions for 30 days"');
    console.log('✓ Description updated');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

updateFreePlan();
