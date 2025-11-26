const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function checkAllTokens() {
  console.log('\n=== CHECKING ALL SUBSCRIPTION TOKENS ===\n');

  // Get all tokens (no ordering to avoid index issues)
  const tokensSnapshot = await admin.firestore()
    .collection('subscriptionChangeTokens')
    .get();

  if (tokensSnapshot.empty) {
    console.log('No tokens found!');
    process.exit(0);
  }

  console.log(`Found ${tokensSnapshot.size} total tokens:\n`);

  const tokens = [];
  for (const tokenDoc of tokensSnapshot.docs) {
    const tokenData = tokenDoc.data();
    tokens.push({
      id: tokenDoc.id,
      data: tokenData,
      created: tokenData.createdAt ? tokenData.createdAt.toDate() : null
    });
  }

  // Sort by creation date (newest first)
  tokens.sort((a, b) => {
    if (!a.created) return 1;
    if (!b.created) return -1;
    return b.created - a.created;
  });

  // Show the 5 most recent
  for (const {id, data, created} of tokens.slice(0, 5)) {
    console.log('---');
    console.log('Token ID:', id);
    console.log('Token:', data.token || 'N/A');
    console.log('Company ID:', data.companyId || 'N/A');
    console.log('Created At:', created ? created.toLocaleString() : 'N/A');
    console.log('Expires At:', data.expiresAt ? data.expiresAt.toDate().toLocaleString() : 'N/A');
    console.log('Used:', data.used || false);
    console.log('');
  }

  process.exit(0);
}

checkAllTokens().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
