const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function checkPlans() {
  try {
    const plansSnapshot = await admin.firestore()
      .collection('subscriptionPlans')
      .orderBy('displayOrder')
      .get();

    console.log(`Found ${plansSnapshot.size} plans:\n`);

    plansSnapshot.forEach(doc => {
      const plan = doc.data();
      console.log(`\n=== ${plan.name.toUpperCase()} ===`);
      console.log(`Plan ID: ${plan.planId}`);
      console.log(`Description: ${plan.description}`);
      console.log(`Max Employees: ${plan.maxEmployees}`);
      console.log(`Max Locations: ${plan.maxLocations}`);
      console.log(`Monthly Price: $${plan.priceMonthly}`);
      console.log(`Yearly Price: $${plan.priceYearly}`);
      console.log(`\nFeatures:`);

      Object.entries(plan.features || {}).forEach(([feature, enabled]) => {
        console.log(`  ${enabled ? '✓' : '✗'} ${feature}`);
      });
      console.log('---');
    });

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkPlans();
