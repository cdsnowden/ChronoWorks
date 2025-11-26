const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function checkStatus() {
  console.log('\n=== CHRONOWORKS SYSTEM STATUS ===\n');

  // Check companies
  const companies = await admin.firestore().collection('companies').limit(10).get();
  console.log(`Companies: ${companies.size}`);
  companies.forEach(doc => {
    const c = doc.data();
    console.log(`\n  - ${c.name || 'Unnamed'}`);
    console.log(`    Plan: ${c.currentPlan || 'none'}`);
    console.log(`    Status: ${c.status || 'unknown'}`);
    if (c.trialEndsAt) {
      const daysLeft = Math.ceil((c.trialEndsAt.toDate() - new Date()) / (1000 * 60 * 60 * 24));
      console.log(`    Trial: ${daysLeft} days left`);
    }
  });

  // Check pending registrations
  const pendingRegs = await admin.firestore()
    .collection('registrationRequests')
    .where('status', '==', 'pending')
    .get();
  console.log(`\n\nPending Registrations: ${pendingRegs.size}`);

  // Check subscription plans
  const plans = await admin.firestore().collection('subscriptionPlans').get();
  console.log(`Subscription Plans: ${plans.size}\n`);

  console.log('=== END STATUS ===\n');
  process.exit(0);
}

checkStatus().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
