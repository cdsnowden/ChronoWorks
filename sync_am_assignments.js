const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'chronoworks-dcfd6'
});

const db = admin.firestore();

async function syncAccountManagerAssignments() {
  try {
    console.log('Starting Account Manager assignment sync...\n');

    // Get all Account Managers
    const amSnapshot = await db.collection('accountManagers').get();

    if (amSnapshot.empty) {
      console.log('No Account Managers found.');
      return;
    }

    console.log(`Found ${amSnapshot.docs.length} Account Manager(s)\n`);

    // Process each Account Manager
    for (const amDoc of amSnapshot.docs) {
      const amId = amDoc.id;
      const amData = amDoc.data();
      console.log(`Processing: ${amData.name || amData.email} (${amId})`);

      // Get current assignedCompanies array
      const currentAssignedCompanies = amData.assignedCompanies || [];
      console.log(`  Current assigned companies: ${currentAssignedCompanies.length}`);

      // Find all companies that have this AM assigned
      const companiesQuery = await db.collection('companies')
        .where('assignedAccountManager.id', '==', amId)
        .get();

      console.log(`  Companies with this AM in assignedAccountManager.id: ${companiesQuery.docs.length}`);

      const actualCompanyIds = companiesQuery.docs.map(doc => doc.id);

      // Find mismatches
      const missingFromArray = actualCompanyIds.filter(id => !currentAssignedCompanies.includes(id));
      const extraInArray = currentAssignedCompanies.filter(id => !actualCompanyIds.includes(id));

      if (missingFromArray.length === 0 && extraInArray.length === 0) {
        console.log('  ✓ Data is in sync!\n');
        continue;
      }

      // Report mismatches
      if (missingFromArray.length > 0) {
        console.log(`  ⚠ Missing from assignedCompanies array: ${missingFromArray.length} companies`);
        for (const companyId of missingFromArray) {
          const companyDoc = await db.collection('companies').doc(companyId).get();
          if (companyDoc.exists) {
            console.log(`    - ${companyDoc.data().businessName} (${companyId})`);
          }
        }
      }

      if (extraInArray.length > 0) {
        console.log(`  ⚠ Extra in assignedCompanies array (no longer assigned): ${extraInArray.length} companies`);
        for (const companyId of extraInArray) {
          console.log(`    - ${companyId}`);
        }
      }

      // Fix the assignedCompanies array
      console.log('  Updating assignedCompanies array to match actual assignments...');
      await db.collection('accountManagers').doc(amId).update({
        assignedCompanies: actualCompanyIds,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log('  ✓ Fixed!\n');
    }

    console.log('=== Sync Complete ===');
    console.log('All Account Manager assignments are now in sync.');

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

syncAccountManagerAssignments();
