// Test script to generate a subscription management token
// Run with: node test_subscription_token.js

const admin = require('firebase-admin');
const crypto = require('crypto');

// Initialize Firebase Admin
const serviceAccount = require('./functions/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

function generateSecureToken() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let token = "";
  const randomValues = new Uint8Array(32);
  crypto.randomFillSync(randomValues);
  for (let i = 0; i < 32; i++) {
    token += chars[randomValues[i] % chars.length];
  }
  return token;
}

async function createTestToken() {
  try {
    // Get the first company
    const companiesSnapshot = await db.collection('companies').limit(1).get();

    if (companiesSnapshot.empty) {
      console.log('No companies found. Please create a test company first.');
      process.exit(1);
    }

    const companyDoc = companiesSnapshot.docs[0];
    const companyId = companyDoc.id;
    const companyData = companyDoc.data();

    console.log('Creating token for company:', companyData.businessName);

    // Generate token
    const token = generateSecureToken();
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + (72 * 60 * 60 * 1000) // 72 hours
    );

    // Save token to Firestore
    await db.collection('subscriptionChangeTokens').doc(token).set({
      token: token,
      companyId: companyId,
      createdBy: 'test_script',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: expiresAt,
      used: false,
      usedAt: null,
      usedBy: null,
    });

    console.log('\n✅ Test token created successfully!\n');
    console.log('Token:', token);
    console.log('Company ID:', companyId);
    console.log('Company Name:', companyData.businessName);
    console.log('Expires:', expiresAt.toDate().toISOString());
    console.log('\n📝 Test URL:');
    console.log(`http://localhost:XXXX/#/subscription/manage?token=${token}`);
    console.log('\n(Replace XXXX with your Flutter web server port)');
    console.log('\nOr in production:');
    console.log(`https://chronoworks.com/subscription/manage?token=${token}`);

    process.exit(0);
  } catch (error) {
    console.error('Error creating test token:', error);
    process.exit(1);
  }
}

createTestToken();
