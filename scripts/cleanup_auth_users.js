const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const KEEP_EMAILS = [
  'chris.s@snowdensjewelers.com',
  'cdsnowden@aol.com'
];

async function cleanupAuthUsers() {
  console.log('\n=== CLEANING UP FIREBASE AUTH USERS ===\n');
  console.log('Keeping these emails:');
  KEEP_EMAILS.forEach(email => console.log(`  - ${email}`));
  console.log('');

  let deletedCount = 0;
  let keptCount = 0;

  // List all users
  const listAllUsers = async (nextPageToken) => {
    const result = await admin.auth().listUsers(1000, nextPageToken);

    for (const user of result.users) {
      const email = user.email || 'no-email';

      if (KEEP_EMAILS.includes(email)) {
        console.log(`✓ Keeping: ${email} (${user.uid})`);
        keptCount++;
      } else {
        console.log(`✗ Deleting: ${email} (${user.uid})`);
        try {
          await admin.auth().deleteUser(user.uid);

          // Also delete from Firestore users collection
          await admin.firestore().collection('users').doc(user.uid).delete();

          deletedCount++;
        } catch (error) {
          console.error(`  Error deleting ${email}:`, error.message);
        }
      }
    }

    if (result.pageToken) {
      await listAllUsers(result.pageToken);
    }
  };

  await listAllUsers();

  console.log('\n=== CLEANUP COMPLETE ===');
  console.log(`Kept: ${keptCount} users`);
  console.log(`Deleted: ${deletedCount} users`);
  console.log('');

  process.exit(0);
}

cleanupAuthUsers().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
