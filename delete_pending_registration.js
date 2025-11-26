const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});
const db = admin.firestore();

async function deletePendingRegistration() {
  const requestId = 'jkMyRL6FM0btzYMi5Vxq';

  console.log('Deleting pending registration for exaltvid@gmail.com...');
  console.log(`Request ID: ${requestId}\n`);

  try {
    // Get the registration to confirm it exists
    const regDoc = await db.collection('registrationRequests').doc(requestId).get();

    if (!regDoc.exists) {
      console.log('❌ Registration not found');
      return;
    }

    const data = regDoc.data();
    console.log('Found registration:');
    console.log(`  Business: ${data.businessName}`);
    console.log(`  Owner: ${data.ownerName} (${data.ownerEmail})`);
    console.log(`  Status: ${data.status}\n`);

    // Delete it
    await db.collection('registrationRequests').doc(requestId).delete();
    console.log('✅ Registration request deleted successfully\n');

    // Verify deletion
    const verify = await db.collection('registrationRequests').doc(requestId).get();
    if (!verify.exists) {
      console.log('✅ Deletion confirmed');
      console.log('\nYou can now submit a fresh registration with exaltvid@gmail.com');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    throw error;
  }
}

deletePendingRegistration().then(() => process.exit(0)).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
