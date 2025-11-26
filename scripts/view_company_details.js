const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function viewCompany() {
  const companiesSnapshot = await admin.firestore().collection('companies').get();

  for (const doc of companiesSnapshot.docs) {
    const data = doc.data();
    console.log('\n=== COMPANY ===');
    console.log(`ID: ${doc.id}`);
    console.log('Data:', JSON.stringify(data, null, 2));
  }

  process.exit(0);
}

viewCompany().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
