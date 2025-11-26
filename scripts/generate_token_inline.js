const admin = require('firebase-admin');
const crypto = require('crypto');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function generateToken() {
  console.log('\n=== GENERATING TOKEN INLINE ===\n');

  try {
    // Get exalt video company
    const companiesSnapshot = await admin.firestore()
      .collection('companies')
      .where('businessName', '==', 'exalt video')
      .limit(1)
      .get();

    if (companiesSnapshot.empty) {
      console.error('Company not found');
      process.exit(1);
    }

    const companyDoc = companiesSnapshot.docs[0];
    const company = companyDoc.data();

    console.log('Company:', company.businessName);
    console.log('Company ID:', companyDoc.id);
    console.log('Owner ID:', company.ownerId);
    console.log('');

    // Generate token (inline logic)
    const token = crypto.randomBytes(32).toString('hex');
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + (72 * 60 * 60 * 1000)
    );

    const tokenData = {
      token,
      companyId: companyDoc.id,
      userId: company.ownerId,
      purpose: 'subscription_management',
      createdAt: now,
      expiresAt,
      used: false,
      usedAt: null,
    };

    console.log('Saving token to Firestore...');
    await admin.firestore()
      .collection('subscriptionChangeTokens')
      .doc(token)
      .set(tokenData);

    console.log('\n✅ Token created successfully!');
    console.log('');
    console.log('Token ID:', token);
    console.log('Token:', token);
    console.log('Expires:', expiresAt.toDate().toLocaleString());
    console.log('');
    console.log('Test URL:');
    console.log(`https://chronoworks.co/subscription/manage?token=${token}`);
    console.log('');

  } catch (error) {
    console.error('\n❌ Error:', error);
  }

  process.exit(0);
}

generateToken();
