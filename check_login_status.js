const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

async function checkLoginStatus() {
  try {
    console.log('=== Checking Login Status for cdsnowden@aol.com ===\n');

    const email = 'cdsnowden@aol.com';

    // Get the Firebase Auth user by email
    let authUser;
    try {
      authUser = await auth.getUserByEmail(email);
      console.log('✅ Firebase Auth User Found:');
      console.log(`   UID: ${authUser.uid}`);
      console.log(`   Email: ${authUser.email}`);
      console.log(`   Email Verified: ${authUser.emailVerified}`);
      console.log();
    } catch (error) {
      console.log('❌ No Firebase Auth user found with that email');
      return;
    }

    // Check users collection
    const userDoc = await db.collection('users').doc(authUser.uid).get();

    if (userDoc.exists) {
      console.log('⚠️  FOUND IN USERS COLLECTION:');
      console.log(`   ID: ${userDoc.id}`);
      const userData = userDoc.data();
      console.log(`   Email: ${userData.email}`);
      console.log(`   Name: ${userData.firstName} ${userData.lastName}`);
      console.log(`   Role: ${userData.role}`);
      console.log(`   Company ID: ${userData.companyId || 'N/A'}`);
      console.log(`   Is Active: ${userData.isActive}`);
      console.log('\n   👉 THIS IS WHY YOU\'RE LOGGING IN AS A CUSTOMER!');
      console.log('   The auth_service.dart finds this document first.\n');
    } else {
      console.log('✅ NOT found in users collection\n');
    }

    // Check accountManagers collection
    const amDoc = await db.collection('accountManagers').doc(authUser.uid).get();

    if (amDoc.exists) {
      console.log('✅ FOUND IN ACCOUNT MANAGERS COLLECTION:');
      console.log(`   ID: ${amDoc.id}`);
      const amData = amDoc.data();
      console.log(`   Email: ${amData.email}`);
      console.log(`   Name: ${amData.displayName}`);
      console.log(`   Status: ${amData.status}`);
      console.log();
    } else {
      console.log('❌ NOT found in accountManagers collection\n');
    }

    // Provide solution
    if (userDoc.exists && amDoc.exists) {
      console.log('🔧 SOLUTION:');
      console.log('   Delete the duplicate user document:');
      console.log(`   db.collection('users').doc('${authUser.uid}').delete()\n`);
      console.log('   Run this script with --delete flag to fix:\n');
      console.log('   node check_login_status.js --delete\n');

      if (process.argv.includes('--delete')) {
        await db.collection('users').doc(authUser.uid).delete();
        console.log('✅ Duplicate user document deleted!');
        console.log('   Please log out and log back in.\n');
      }
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error);
  }
}

checkLoginStatus().then(() => {
  console.log('=== Check Complete ===');
  process.exit(0);
});
