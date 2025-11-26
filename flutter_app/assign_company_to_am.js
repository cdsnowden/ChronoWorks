const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'chronoworks-dcfd6'
});

const db = admin.firestore();

async function assignCompanyToAccountManager() {
  try {
    const amId = 'i2tVFKOQdRgIGhetg2CbgNWll2W2'; // cdsnowden@aol.com
    const amEmail = 'cdsnowden@aol.com';
    const amName = 'Christopher Snowden';

    console.log('Step 1: Creating test company...');

    // Create a test company
    const testCompanyRef = db.collection('companies').doc();
    const testCompanyId = testCompanyRef.id;

    const companyData = {
      businessName: 'Test Company for AM',
      subscriptionTier: 'professional',
      subscriptionStatus: 'active',
      billingEmail: 'test@testcompany.com',
      phoneNumber: '555-0100',
      address: '123 Test Street',
      city: 'Test City',
      state: 'TS',
      zipCode: '12345',
      industry: 'Technology',
      companySize: '10-50',
      timezone: 'America/New_York',
      assignedAccountManager: {
        id: amId,
        name: amName,
        email: amEmail
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await testCompanyRef.set(companyData);
    console.log(`✓ Test company created with ID: ${testCompanyId}`);

    console.log('\nStep 2: Updating Account Manager profile...');

    // Update Account Manager's assignedCompanies array
    await db.collection('accountManagers').doc(amId).update({
      assignedCompanies: admin.firestore.FieldValue.arrayUnion(testCompanyId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('✓ Account Manager profile updated');

    console.log('\n=== SUCCESS ===');
    console.log(`Company ID: ${testCompanyId}`);
    console.log(`Company Name: ${companyData.businessName}`);
    console.log(`Assigned to: ${amName} (${amEmail})`);
    console.log('\nThe Account Manager can now view this company!');

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

assignCompanyToAccountManager();
