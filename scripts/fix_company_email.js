const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function fixCompanyEmail() {
  console.log('\n=== FIXING COMPANY EMAIL ===\n');

  // Get the company
  const companyDoc = await admin.firestore().collection('companies').doc('mKwa7lZfbG3wxrh5MBww').get();
  const company = companyDoc.data();

  console.log('Company:', company.businessName);
  console.log('Owner ID:', company.ownerId);

  // Get user email from Firebase Auth
  try {
    const userRecord = await admin.auth().getUser(company.ownerId);
    console.log('Owner Email:', userRecord.email);

    // Update company with owner email
    await companyDoc.ref.update({
      ownerEmail: userRecord.email
    });

    console.log('\n✅ Company updated with ownerEmail:', userRecord.email);
    console.log('\nNow sending trial warning email...\n');

    // Trigger trial warning
    const https = require('https');
    https.get('https://testtrialexpirations-4i2x6khbwq-uc.a.run.app', (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        console.log('Trial check response:', data);
        console.log(`\n✅ Check ${userRecord.email} for the trial warning email!`);
        console.log('');
        process.exit(0);
      });
    });
  } catch (error) {
    console.error('Error getting user:', error.message);
    process.exit(1);
  }
}

fixCompanyEmail().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
