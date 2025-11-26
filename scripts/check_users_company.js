const admin = require('firebase-admin');

// Initialize Firebase Admin with project ID
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'chronoworks-dcfd6'
});

const db = admin.firestore();

async function checkUsers() {
  try {
    console.log('Fetching all users...\n');

    const usersSnapshot = await db.collection('users').get();

    console.log(`Total users found: ${usersSnapshot.size}\n`);

    const companyGroups = {};

    usersSnapshot.forEach(doc => {
      const data = doc.data();
      const companyId = data.companyId || 'NO_COMPANY_ID';

      if (!companyGroups[companyId]) {
        companyGroups[companyId] = [];
      }

      companyGroups[companyId].push({
        id: doc.id,
        email: data.email,
        firstName: data.firstName,
        lastName: data.lastName,
        role: data.role,
        companyId: data.companyId
      });
    });

    console.log('Users grouped by companyId:\n');

    for (const [companyId, users] of Object.entries(companyGroups)) {
      console.log(`\n============================================`);
      console.log(`Company ID: ${companyId}`);
      console.log(`User count: ${users.length}`);
      console.log(`============================================`);

      users.forEach(user => {
        console.log(`  - ${user.email} (${user.firstName} ${user.lastName}) - Role: ${user.role}`);
      });
    }

    // Also check companies
    console.log('\n\n============================================');
    console.log('Companies in database:');
    console.log('============================================\n');

    const companiesSnapshot = await db.collection('companies').get();
    companiesSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`Company ID: ${doc.id}`);
      console.log(`  Business Name: ${data.businessName}`);
      console.log(`  Owner: ${data.ownerName} (${data.ownerId})`);
      console.log(`  Status: ${data.status}`);
      console.log(`  Plan: ${data.subscriptionPlan}`);
      console.log('');
    });

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

checkUsers();
