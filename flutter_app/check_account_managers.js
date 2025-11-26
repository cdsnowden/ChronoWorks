const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'territory-manager-71c07'
});

const db = admin.firestore();

async function checkAccountManagers() {
  try {
    console.log('Checking Account Managers in the database...\n');

    const amsSnapshot = await db.collection('accountManagers').get();

    if (amsSnapshot.empty) {
      console.log('No Account Managers found in the database.');
      console.log('\nYou need to create an Account Manager first.');
    } else {
      console.log(`Found ${amsSnapshot.size} Account Manager(s):\n`);

      amsSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`ID: ${doc.id}`);
        console.log(`  Name: ${data.name}`);
        console.log(`  Email: ${data.email}`);
        console.log(`  Status: ${data.status}`);
        console.log(`  Created: ${data.createdAt?.toDate()}`);
        console.log(`  Assigned Companies: ${data.assignedCompanies?.length || 0}`);
        console.log('');
      });
    }

  } catch (error) {
    console.error('Error checking Account Managers:', error);
  } finally {
    process.exit(0);
  }
}

checkAccountManagers();
