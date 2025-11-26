const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const {generateSubscriptionToken} = require('../functions/subscriptionTokenService');

async function testTokenGeneration() {
  console.log('\n=== TESTING TOKEN GENERATION ===\n');

  try {
    // Get the exalt video company
    const companiesSnapshot = await admin.firestore()
      .collection('companies')
      .where('businessName', '==', 'exalt video')
      .limit(1)
      .get();

    if (companiesSnapshot.empty) {
      console.error('No company found with name "exalt video"');
      process.exit(1);
    }

    const companyDoc = companiesSnapshot.docs[0];
    const company = companyDoc.data();

    console.log('Found company:');
    console.log('  ID:', companyDoc.id);
    console.log('  Name:', company.businessName);
    console.log('  Owner ID:', company.ownerId);
    console.log('');

    console.log('Generating token...');
    const tokenData = await generateSubscriptionToken(
      companyDoc.id,
      company.ownerId,
      72
    );

    console.log('\n✅ Token generated successfully!');
    console.log('');
    console.log('Token ID:', tokenData.tokenId);
    console.log('Token:', tokenData.token);
    console.log('Expires:', tokenData.expiresAt.toDate().toLocaleString());
    console.log('');
    console.log('Management URL:');
    console.log(tokenData.managementUrl);
    console.log('');

  } catch (error) {
    console.error('\n❌ Error generating token:');
    console.error(error);
    console.error('');
  }

  process.exit(0);
}

testTokenGeneration();
