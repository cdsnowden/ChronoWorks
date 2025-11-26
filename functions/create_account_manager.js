const admin = require('firebase-admin');

// Use application default credentials (from gcloud/Firebase CLI)
process.env.GOOGLE_APPLICATION_CREDENTIALS = process.env.GOOGLE_APPLICATION_CREDENTIALS || '';
process.env.GCLOUD_PROJECT = 'chronoworks-dcfd6';

admin.initializeApp({
  projectId: 'chronoworks-dcfd6'
});

const auth = admin.auth();
const firestore = admin.firestore();

async function createAccountManager() {
  const email = process.argv[2];
  const displayName = process.argv[3];
  const password = process.argv[4];
  const maxCustomers = parseInt(process.argv[5]) || 100;

  if (!email || !displayName || !password) {
    console.error('Usage: node create_account_manager.js <email> <displayName> <password> [maxCustomers]');
    console.error('Example: node create_account_manager.js test@example.com "John Doe" "password123" 100');
    process.exit(1);
  }

  try {
    console.log(`Creating Account Manager: ${displayName} (${email})`);

    // 1. Create Firebase Auth user
    const userRecord = await auth.createUser({
      email: email,
      password: password,
      displayName: displayName,
      disabled: false
    });

    console.log('✓ Created Auth user:', userRecord.uid);

    // 2. Create Account Manager document
    const accountManagerData = {
      id: userRecord.uid,
      uid: userRecord.uid,
      email: email,
      displayName: displayName,
      phoneNumber: null,
      photoURL: null,
      role: 'account_manager',
      permissions: [
        'view_assigned_customers',
        'edit_customer_settings',
        'manage_support_tickets',
        'view_analytics'
      ],
      assignedCompanies: [],
      maxAssignedCompanies: maxCustomers,
      metrics: {
        totalAssignedCustomers: 0,
        activeCustomers: 0,
        trialCustomers: 0,
        paidCustomers: 0,
        averageResponseTime: 0,
        customerSatisfactionScore: 0,
        monthlyUpsellRevenue: 0
      },
      status: 'active',
      hireDate: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: 'admin-script'
    };

    await firestore.collection('accountManagers').doc(userRecord.uid).set(accountManagerData);
    console.log('✓ Created accountManagers document');

    // 3. Create users document
    const userData = {
      email: email,
      displayName: displayName,
      phoneNumber: null,
      role: 'account_manager',
      isAccountManager: true,
      accountManagerProfile: userRecord.uid,
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await firestore.collection('users').doc(userRecord.uid).set(userData);
    console.log('✓ Created users document');

    console.log('\n✅ Account Manager created successfully!');
    console.log(`   Email: ${email}`);
    console.log(`   UID: ${userRecord.uid}`);
    console.log(`   Max Customers: ${maxCustomers}`);

    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating Account Manager:', error.message);
    process.exit(1);
  }
}

createAccountManager();
