const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

// Initialize with service account
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'chronoworks-dcfd6'
});

const auth = admin.auth();
const firestore = admin.firestore();

const KEEP_EMAIL = 'chris.s@snowdensjewelers.com';

async function deleteAllUsersExcept() {
  try {
    console.log(`🔍 Fetching all users...`);
    console.log(`⚠️  Will keep: ${KEEP_EMAIL}`);
    console.log('');

    const listUsersResult = await auth.listUsers(1000);
    const users = listUsersResult.users;

    console.log(`📊 Found ${users.length} total users`);

    // Filter out the user to keep
    const usersToDelete = users.filter(user => user.email !== KEEP_EMAIL);

    console.log(`🗑️  Will delete ${usersToDelete.length} users`);
    console.log('');

    if (usersToDelete.length === 0) {
      console.log('✅ No users to delete');
      process.exit(0);
    }

    // Show which users will be deleted
    console.log('Users to be deleted:');
    usersToDelete.forEach(user => {
      console.log(`  - ${user.email || 'No email'} (${user.uid})`);
    });
    console.log('');

    // Delete users
    let deletedCount = 0;
    for (const user of usersToDelete) {
      try {
        // Delete from Firebase Auth
        await auth.deleteUser(user.uid);

        // Also delete from Firestore collections if they exist
        await Promise.all([
          firestore.collection('users').doc(user.uid).delete().catch(() => {}),
          firestore.collection('accountManagers').doc(user.uid).delete().catch(() => {}),
          firestore.collection('superAdmins').doc(user.uid).delete().catch(() => {})
        ]);

        deletedCount++;
        console.log(`✅ Deleted: ${user.email || user.uid}`);
      } catch (error) {
        console.error(`❌ Failed to delete ${user.email || user.uid}: ${error.message}`);
      }
    }

    console.log('');
    console.log(`🎉 Deleted ${deletedCount} out of ${usersToDelete.length} users`);
    console.log(`✅ Kept: ${KEEP_EMAIL}`);

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

deleteAllUsersExcept();
