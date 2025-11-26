const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});
const db = admin.firestore();

async function cleanupTestAccounts() {
  console.log('=== CLEANING UP TEST ACCOUNTS ===\n');

  const testCompanyId = 'mKwa7lZfbG3wxrh5MBww';
  const testUserEmail = 'exaltvid@gmail.com';

  try {
    // 1. Find and delete user by email from Firebase Auth
    console.log('1. Deleting Firebase Auth user...');
    try {
      const userRecord = await admin.auth().getUserByEmail(testUserEmail);
      await admin.auth().deleteUser(userRecord.uid);
      console.log(`   ✅ Deleted Auth user: ${testUserEmail} (UID: ${userRecord.uid})`);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.log('   ℹ️  Auth user not found (already deleted or never existed)');
      } else {
        console.log(`   ⚠️  Error deleting Auth user: ${error.message}`);
      }
    }

    // 2. Delete user document from Firestore
    console.log('\n2. Deleting user documents...');
    const usersSnapshot = await db.collection('users')
      .where('companyId', '==', testCompanyId)
      .get();

    if (usersSnapshot.empty) {
      console.log('   ℹ️  No user documents found');
    } else {
      for (const doc of usersSnapshot.docs) {
        await doc.ref.delete();
        console.log(`   ✅ Deleted user: ${doc.data().email || doc.id}`);
      }
    }

    // 3. Delete company-related data
    const collections = [
      'shifts',
      'timeEntries',
      'activeClockIns',
      'overtimeRiskNotifications',
      'shiftTemplates',
      'overtimeRequests',
      'timeOffRequests',
      'shiftSwapRequests'
    ];

    console.log('\n3. Deleting company data from collections...');
    for (const collectionName of collections) {
      try {
        const snapshot = await db.collection(collectionName)
          .where('companyId', '==', testCompanyId)
          .get();

        if (!snapshot.empty) {
          for (const doc of snapshot.docs) {
            await doc.ref.delete();
          }
          console.log(`   ✅ Deleted ${snapshot.size} documents from ${collectionName}`);
        } else {
          console.log(`   ℹ️  No documents in ${collectionName}`);
        }
      } catch (error) {
        console.log(`   ⚠️  Error with ${collectionName}: ${error.message}`);
      }
    }

    // 4. Delete company document
    console.log('\n4. Deleting company document...');
    const companyDoc = await db.collection('companies').doc(testCompanyId).get();
    if (companyDoc.exists) {
      await companyDoc.ref.delete();
      console.log(`   ✅ Deleted company: ${companyDoc.data().businessName}`);
    } else {
      console.log('   ℹ️  Company document not found');
    }

    // 5. Verify cleanup
    console.log('\n=== VERIFICATION ===\n');

    const remainingCompanies = await db.collection('companies').get();
    console.log(`Remaining companies: ${remainingCompanies.size}`);

    const remainingUsers = await db.collection('users').get();
    console.log(`Remaining users: ${remainingUsers.size}`);

    const superAdmins = await db.collection('superAdmins').get();
    console.log(`Super admins: ${superAdmins.size}`);

    console.log('\n✅ CLEANUP COMPLETE!\n');
    console.log('The system is now clean and ready for production use.');

  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    throw error;
  }
}

cleanupTestAccounts().then(() => process.exit()).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
