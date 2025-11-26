const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function cleanup() {
  console.log('\n=== CLEANING UP TEST DATA ===\n');

  // Delete all companies
  const companiesSnapshot = await admin.firestore().collection('companies').get();
  console.log(`Found ${companiesSnapshot.size} companies to delete...`);

  const batch = admin.firestore().batch();
  companiesSnapshot.docs.forEach(doc => {
    console.log(`  - Deleting company: ${doc.data().name || doc.id}`);
    batch.delete(doc.ref);
  });

  // Delete all registration requests
  const registrationsSnapshot = await admin.firestore().collection('registrationRequests').get();
  console.log(`\nFound ${registrationsSnapshot.size} registration requests to delete...`);

  registrationsSnapshot.docs.forEach(doc => {
    console.log(`  - Deleting registration: ${doc.data().companyName || doc.id}`);
    batch.delete(doc.ref);
  });

  // Delete all subscription tokens
  const tokensSnapshot = await admin.firestore().collection('subscriptionTokens').get();
  console.log(`\nFound ${tokensSnapshot.size} subscription tokens to delete...`);

  tokensSnapshot.docs.forEach(doc => {
    batch.delete(doc.ref);
  });

  // Commit all deletes
  await batch.commit();

  console.log('\n✅ Cleanup complete!');
  console.log('\nKept:');
  console.log('  - Super Admin (chris.s@snowdensjewelers.com)');
  console.log('  - Account Managers (if any exist)');
  console.log('\nDeleted:');
  console.log(`  - ${companiesSnapshot.size} companies`);
  console.log(`  - ${registrationsSnapshot.size} registration requests`);
  console.log(`  - ${tokensSnapshot.size} subscription tokens`);
  console.log('\n');

  process.exit(0);
}

cleanup().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
