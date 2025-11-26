const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkNotesPermission() {
  try {
    console.log('=== Checking Customer Notes Permission Setup ===\n');

    // Get the current Account Manager (assuming first one for testing)
    const amSnapshot = await db.collection('accountManagers').limit(1).get();

    if (amSnapshot.empty) {
      console.log('❌ No Account Managers found in database!');
      return;
    }

    const accountManager = amSnapshot.docs[0];
    const amData = accountManager.data();
    const amId = accountManager.id;

    console.log('✅ Account Manager Found:');
    console.log(`   ID: ${amId}`);
    console.log(`   Name: ${amData.displayName}`);
    console.log(`   Email: ${amData.email}`);
    console.log(`   Status: ${amData.status}\n`);

    // Get companies assigned to this Account Manager
    const companiesSnapshot = await db.collection('companies')
      .where('assignedAccountManager.id', '==', amId)
      .get();

    console.log(`✅ Found ${companiesSnapshot.size} companies assigned to this Account Manager:\n`);

    if (companiesSnapshot.empty) {
      console.log('❌ No companies assigned to this Account Manager!');
      console.log('   This is why the permission check is failing.\n');

      // Check if there are any companies at all
      const allCompaniesSnapshot = await db.collection('companies').limit(5).get();
      console.log(`   Total companies in database: ${allCompaniesSnapshot.size}`);

      if (!allCompaniesSnapshot.empty) {
        console.log('\n   Sample company structure:');
        const sampleCompany = allCompaniesSnapshot.docs[0];
        const sampleData = sampleCompany.data();
        console.log(`   Company ID: ${sampleCompany.id}`);
        console.log(`   Business Name: ${sampleData.businessName}`);
        console.log(`   Has assignedAccountManager: ${!!sampleData.assignedAccountManager}`);
        if (sampleData.assignedAccountManager) {
          console.log(`   assignedAccountManager.id: ${sampleData.assignedAccountManager.id}`);
          console.log(`   assignedAccountManager.name: ${sampleData.assignedAccountManager.name}`);
        }
      }
      return;
    }

    companiesSnapshot.forEach(doc => {
      const company = doc.data();
      console.log(`   📊 Company: ${company.businessName}`);
      console.log(`      ID: ${doc.id}`);
      console.log(`      Status: ${company.status}`);
      console.log(`      Assigned AM ID: ${company.assignedAccountManager?.id}`);
      console.log(`      Assigned AM Name: ${company.assignedAccountManager?.name}\n`);
    });

    // Now check existing customer notes
    const notesSnapshot = await db.collection('customerNotes')
      .where('createdBy', '==', amId)
      .limit(5)
      .get();

    console.log(`\n✅ Existing notes created by this Account Manager: ${notesSnapshot.size}`);
    if (!notesSnapshot.empty) {
      notesSnapshot.forEach(doc => {
        const note = doc.data();
        console.log(`   📝 Note: ${note.note.substring(0, 50)}...`);
        console.log(`      Company: ${note.companyName}`);
        console.log(`      Created: ${note.createdAt?.toDate()}\n`);
      });
    }

    // Test creating a note for the first assigned company
    if (!companiesSnapshot.empty) {
      const testCompany = companiesSnapshot.docs[0];
      const testCompanyData = testCompany.data();

      console.log('\n=== Testing Note Creation ===');
      console.log(`Attempting to create a test note for: ${testCompanyData.businessName}`);
      console.log(`Company ID: ${testCompany.id}`);
      console.log(`Account Manager ID: ${amId}\n`);

      const testNoteData = {
        companyId: testCompany.id,
        companyName: testCompanyData.businessName,
        note: 'Test note to verify permissions',
        noteType: 'interaction',
        createdBy: amId,
        createdByName: amData.displayName,
        createdByRole: 'account_manager',
        tags: ['test'],
        sentiment: 'neutral',
        followUpRequired: false,
        followUpCompleted: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      console.log('Test note data:', JSON.stringify(testNoteData, null, 2));

      // Check if the security rule conditions would pass
      console.log('\n=== Security Rule Check ===');
      console.log(`✓ companyId in note: ${testNoteData.companyId}`);
      console.log(`✓ Company exists: Yes`);
      console.log(`✓ Company has assignedAccountManager: ${!!testCompanyData.assignedAccountManager}`);
      console.log(`✓ assignedAccountManager.id: ${testCompanyData.assignedAccountManager?.id}`);
      console.log(`✓ Matches current user ID: ${testCompanyData.assignedAccountManager?.id === amId}`);
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error);
  }
}

checkNotesPermission().then(() => {
  console.log('\n=== Check Complete ===');
  process.exit(0);
});
