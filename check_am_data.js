const admin = require('firebase-admin');

// Initialize with default credentials
admin.initializeApp({
  projectId: 'chronoworks-dcfd6'
});

const db = admin.firestore();

async function checkAccountManagerData() {
  try {
    const amId = 'i2tVFKOQdRgIGhetg2CbgNWll2W2';

    console.log('Checking Account Manager data...\n');

    // Get AM document
    const amDoc = await db.collection('accountManagers').doc(amId).get();
    if (!amDoc.exists) {
      console.log('ERROR: Account Manager document not found!');
      return;
    }

    const amData = amDoc.data();
    console.log('Account Manager:', amData.name);
    console.log('Email:', amData.email);
    console.log('Assigned Companies:', amData.assignedCompanies || []);
    console.log('Number of assigned companies:', (amData.assignedCompanies || []).length);

    console.log('\n--- Checking Companies ---\n');

    // Check companies with assignedAccountManager.id
    const companiesQuery = await db.collection('companies')
      .where('assignedAccountManager.id', '==', amId)
      .get();

    console.log(`Found ${companiesQuery.docs.length} companies with assignedAccountManager.id = ${amId}\n`);

    for (const doc of companiesQuery.docs) {
      const data = doc.data();
      const inArray = (amData.assignedCompanies || []).includes(doc.id);
      console.log(`Company: ${data.businessName}`);
      console.log(`  ID: ${doc.id}`);
      console.log(`  In assignedCompanies array: ${inArray ? 'YES ✓' : 'NO ✗'}`);
      console.log(`  assignedAccountManager:`, data.assignedAccountManager);
      console.log('');
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

checkAccountManagerData();
