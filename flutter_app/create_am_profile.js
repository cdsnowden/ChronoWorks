const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'territory-manager-71c07'
});

const db = admin.firestore();

async function createAccountManagerProfile() {
  try {
    // UID from auth_users.json for cdsnowden@aol.com
    const uid = 'i2tVFKOQdRgIGhetg2CbgNWll2W2';
    const email = 'cdsnowden@aol.com';
    const name = 'Christopher Snowden';

    console.log(`Creating Account Manager profile for ${email} (${uid})...`);

    const accountManagerData = {
      name: name,
      email: email,
      status: 'active',
      assignedCompanies: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await db.collection('accountManagers').doc(uid).set(accountManagerData);

    console.log('✓ Account Manager profile created successfully!');
    console.log('\nProfile Details:');
    console.log(`  UID: ${uid}`);
    console.log(`  Name: ${name}`);
    console.log(`  Email: ${email}`);
    console.log(`  Status: active`);
    console.log(`  Assigned Companies: 0`);

  } catch (error) {
    console.error('Error creating Account Manager profile:', error);
  } finally {
    process.exit(0);
  }
}

createAccountManagerProfile();
