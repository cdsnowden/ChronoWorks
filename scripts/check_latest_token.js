const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function checkLatestToken() {
  console.log('\n=== CHECKING LATEST SUBSCRIPTION TOKEN ===\n');

  // Get the most recent token (including used ones)
  const tokensSnapshot = await admin.firestore()
    .collection('subscriptionChangeTokens')
    .orderBy('createdAt', 'desc')
    .limit(5)
    .get();

  if (tokensSnapshot.empty) {
    console.log('No tokens found!');
    process.exit(0);
  }

  console.log(`Found ${tokensSnapshot.size} recent tokens:\n`);

  for (const tokenDoc of tokensSnapshot.docs) {
    const tokenData = tokenDoc.data();

    console.log('---');
    console.log('Token ID:', tokenDoc.id);
    console.log('Token:', tokenData.token);
    console.log('Company ID:', tokenData.companyId);
    console.log('Created At:', tokenData.createdAt ? tokenData.createdAt.toDate().toLocaleString() : 'N/A');
    console.log('Expires At:', tokenData.expiresAt ? tokenData.expiresAt.toDate().toLocaleString() : 'N/A');
    console.log('Used:', tokenData.used);
    console.log('Purpose:', tokenData.purpose || 'N/A');
    console.log('\nGenerated URL:');
    console.log(`https://chronoworks.co/subscription/manage?token=${tokenData.token}`);
    console.log('');
  }

  process.exit(0);
}

checkLatestToken().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
