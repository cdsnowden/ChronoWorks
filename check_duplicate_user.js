const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkDuplicateUser() {
  try {
    console.log('=== Checking for Duplicate User Documents ===\n');

    const accountManagerId = 'i2tVFKOQdRgIGhetg2CbgNWll2W2';
    const email = 'cdsnowden@aol.com';

    // Check accountManagers collection
    const amDoc = await db.collection('accountManagers').doc(accountManagerId).get();

    if (amDoc.exists) {
      console.log('✅ Account Manager document exists:');
      console.log(`   ID: ${amDoc.id}`);
      console.log(`   Email: ${amDoc.data().email}`);
      console.log(`   Name: ${amDoc.data().displayName}`);
      console.log(`   Status: ${amDoc.data().status}\n`);
    } else {
      console.log('❌ No Account Manager document found\n');
    }

    // Check users collection for the same UID
    const userDoc = await db.collection('users').doc(accountManagerId).get();

    if (userDoc.exists) {
      console.log('⚠️  DUPLICATE FOUND: User document exists with same UID:');
      console.log(`   ID: ${userDoc.id}`);
      const userData = userDoc.data();
      console.log(`   Email: ${userData.email}`);
      console.log(`   Name: ${userData.firstName} ${userData.lastName}`);
      console.log(`   Role: ${userData.role}`);
      console.log(`   Company ID: ${userData.companyId || 'N/A'}`);
      console.log('\n❌ THIS IS THE PROBLEM!');
      console.log('   The auth service checks the users collection first.');
      console.log('   It finds this document and treats you as a customer.\n');

      console.log('🔧 SOLUTION: Delete this duplicate user document');
      console.log(`   Command: db.collection('users').doc('${accountManagerId}').delete()\n`);

      // Ask if we should delete it
      console.log('Would you like to delete this duplicate user document? (Run with --delete flag)');

      if (process.argv.includes('--delete')) {
        await db.collection('users').doc(accountManagerId).delete();
        console.log('\n✅ Duplicate user document deleted!');
        console.log('   You should now be able to log in as an Account Manager.\n');
      }
    } else {
      console.log('✅ No duplicate user document found');
      console.log('   This is not the issue.\n');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error);
  }
}

checkDuplicateUser().then(() => {
  console.log('=== Check Complete ===');
  process.exit(0);
});
