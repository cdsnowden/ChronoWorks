const admin = require('firebase-admin');

// Initialize Firebase Admin with application default credentials
admin.initializeApp({
  projectId: 'territory-manager-71c07'
});

const db = admin.firestore();

async function deleteChronoWorksCompany() {
  try {
    console.log('Searching for ChronoWorks company...');

    // Find company with businessName "ChronoWorks"
    const companiesSnapshot = await db.collection('companies')
      .where('businessName', '==', 'ChronoWorks')
      .get();

    if (companiesSnapshot.empty) {
      console.log('No company found with name "ChronoWorks"');
      process.exit(0);
    }

    console.log(`Found ${companiesSnapshot.size} company(ies) with name "ChronoWorks"`);

    for (const doc of companiesSnapshot.docs) {
      const companyId = doc.id;
      const companyData = doc.data();

      console.log('\nCompany Details:');
      console.log(`  ID: ${companyId}`);
      console.log(`  Business Name: ${companyData.businessName}`);
      console.log(`  Owner: ${companyData.ownerName}`);
      console.log(`  Email: ${companyData.ownerEmail}`);
      console.log(`  Status: ${companyData.status}`);

      // Check if it has an assigned Account Manager
      if (companyData.assignedAccountManager) {
        console.log(`  Assigned AM: ${companyData.assignedAccountManager.name}`);
        const amId = companyData.assignedAccountManager.id;

        // Remove this company from the Account Manager's assignedCompanies array
        console.log(`\nRemoving company from Account Manager's list...`);
        await db.collection('accountManagers').doc(amId).update({
          assignedCompanies: admin.firestore.FieldValue.arrayRemove(companyId),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('✓ Removed from Account Manager');
      }

      // Delete the company
      console.log('\nDeleting company document...');
      await db.collection('companies').doc(companyId).delete();
      console.log('✓ Company deleted successfully');

      // Find and delete associated users
      console.log('\nSearching for associated users...');
      const usersSnapshot = await db.collection('users')
        .where('companyId', '==', companyId)
        .get();

      if (!usersSnapshot.empty) {
        console.log(`Found ${usersSnapshot.size} associated user(s)`);

        for (const userDoc of usersSnapshot.docs) {
          const userId = userDoc.id;
          const userData = userDoc.data();
          console.log(`  Deleting user: ${userData.firstName} ${userData.lastName} (${userData.email})`);

          // Delete from Firestore
          await db.collection('users').doc(userId).delete();

          // Optionally delete from Firebase Auth (commented out for safety)
          // await admin.auth().deleteUser(userId);

          console.log(`  ✓ User deleted from Firestore`);
        }
      } else {
        console.log('No associated users found');
      }
    }

    console.log('\n=== Cleanup Complete ===');
    console.log('ChronoWorks company and associated data have been deleted.');

  } catch (error) {
    console.error('Error deleting company:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

// Run the script
deleteChronoWorksCompany();
