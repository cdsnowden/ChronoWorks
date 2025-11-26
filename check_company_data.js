const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function checkCompanyData() {
  try {
    const companiesSnapshot = await admin.firestore()
      .collection('companies')
      .get();

    console.log(`Found ${companiesSnapshot.size} companies\n`);

    companiesSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.businessName && data.businessName.toLowerCase().includes('exalt')) {
        console.log(`\n=== Company: ${data.businessName} ===`);
        console.log(`Company ID: ${doc.id}`);
        console.log('\nAll fields:');
        Object.entries(data).forEach(([key, value]) => {
          if (value === null || value === undefined) {
            console.log(`  ${key}: NULL/UNDEFINED ⚠️`);
          } else if (typeof value === 'object' && !Array.isArray(value)) {
            console.log(`  ${key}: ${JSON.stringify(value)}`);
          } else {
            console.log(`  ${key}: ${value}`);
          }
        });
      }
    });

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkCompanyData();
