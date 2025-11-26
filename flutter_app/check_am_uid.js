const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'territory-manager-71c07'
});

const db = admin.firestore();

async function checkAccountManagerUID() {
  try {
    console.log('Checking Account Manager UIDs...\n');

    // Get all Account Managers
    const amSnapshot = await db.collection('accountManagers').get();

    if (amSnapshot.empty) {
      console.log('No Account Managers found in database');
      return;
    }

    console.log(`Found ${amSnapshot.docs.length} Account Manager(s):\n`);

    for (const doc of amSnapshot.docs) {
      const data = doc.data();
      console.log(`Document ID (UID): ${doc.id}`);
      console.log(`  Email: ${data.email}`);
      console.log(`  Display Name: ${data.displayName}`);
      console.log(`  Status: ${data.status}`);
      console.log('');
    }

    // Check Firebase Auth for cdsnowden@aol.com
    console.log('Checking Firebase Auth for cdsnowden@aol.com...');
    try {
      const userRecord = await admin.auth().getUserByEmail('cdsnowden@aol.com');
      console.log(`Firebase Auth UID: ${userRecord.uid}`);
      console.log(`Email: ${userRecord.email}`);
      console.log(`Display Name: ${userRecord.displayName || 'Not set'}`);
      console.log('');

      // Check if Account Manager document exists with this UID
      const amDoc = await db.collection('accountManagers').doc(userRecord.uid).get();
      if (amDoc.exists) {
        console.log('✓ Account Manager document EXISTS for this UID');
      } else {
        console.log('✗ Account Manager document DOES NOT EXIST for this UID');
        console.log('  This is the problem - the UID mismatch!');
      }
    } catch (error) {
      console.log(`Error checking Firebase Auth: ${error.message}`);
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

checkAccountManagerUID();
