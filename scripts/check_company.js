const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function checkCompany() {
  const companiesSnapshot = await admin.firestore()
    .collection('companies')
    .where('businessName', '==', 'exalt video')
    .limit(1)
    .get();

  if (!companiesSnapshot.empty) {
    const doc = companiesSnapshot.docs[0];
    const data = doc.data();
    console.log('\n=== COMPANY DETAILS ===\n');
    console.log('Company:', data.businessName);
    console.log('Current Plan:', data.currentPlan);
    console.log('Billing Cycle:', data.billingCycle || 'N/A');
    console.log('Status:', data.status);
    console.log('');
  } else {
    console.log('Company not found');
  }

  process.exit(0);
}

checkCompany();
