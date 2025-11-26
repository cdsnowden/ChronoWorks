const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function checkOwner() {
  const companyId = 'rvjFhXgsvmyjgJv2ECoh';

  // Get company details
  const companyDoc = await admin.firestore()
    .collection('companies')
    .doc(companyId)
    .get();

  const company = companyDoc.data();

  console.log('\n=== Test Company - Day 27 Owner Details ===\n');
  console.log(`Company Name: ${company.name}`);
  console.log(`Company ID: ${companyId}`);
  console.log(`Owner Email: ${company.ownerEmail}`);
  console.log(`Owner Name: ${company.ownerName || 'Not set'}`);
  console.log(`Business Name: ${company.businessName || company.name}`);
  console.log(`Trial Ends: ${company.trialEndsAt.toDate().toLocaleDateString()}`);
  console.log('');

  process.exit(0);
}

checkOwner().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
