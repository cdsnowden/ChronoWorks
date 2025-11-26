const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./chronoworks-4a552-firebase-adminsdk-rrqix-4d8e2d0ccf.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();
const db = admin.firestore();

async function createTestCompany() {
  try {
    console.log('Creating test company and accounts...\n');

    // Step 1: Create company document
    const companyRef = db.collection('companies').doc();
    const companyId = companyRef.id;

    const companyData = {
      id: companyId,
      businessName: 'Test Restaurant Co.',
      ownerName: 'John Admin',
      ownerId: '', // Will be set after creating admin
      status: 'active',
      subscriptionPlan: 'trial',
      trialStartDate: admin.firestore.Timestamp.now(),
      trialEndDate: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days from now
      ),
      createdAt: admin.firestore.Timestamp.now(),
    };

    await companyRef.set(companyData);
    console.log('✓ Company created:', companyData.businessName);
    console.log('  Company ID:', companyId);

    // Step 2: Create Admin user
    const adminUser = await auth.createUser({
      email: 'admin@testrestaurant.com',
      password: 'TestAdmin123',
      displayName: 'John Admin',
    });

    await db.collection('users').doc(adminUser.uid).set({
      id: adminUser.uid,
      email: 'admin@testrestaurant.com',
      firstName: 'John',
      lastName: 'Admin',
      role: 'admin',
      companyId: companyId,
      phoneNumber: '555-0100',
      employmentType: 'full-time',
      hourlyRate: 0.0,
      isActive: true,
      isKeyholder: true,
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    // Update company with ownerId
    await companyRef.update({ ownerId: adminUser.uid });

    console.log('✓ Admin created: admin@testrestaurant.com (password: TestAdmin123)');

    // Step 3: Create Manager user
    const managerUser = await auth.createUser({
      email: 'manager@testrestaurant.com',
      password: 'TestManager123',
      displayName: 'Jane Manager',
    });

    await db.collection('users').doc(managerUser.uid).set({
      id: managerUser.uid,
      email: 'manager@testrestaurant.com',
      firstName: 'Jane',
      lastName: 'Manager',
      role: 'manager',
      companyId: companyId,
      phoneNumber: '555-0101',
      employmentType: 'full-time',
      hourlyRate: 25.0,
      isActive: true,
      isKeyholder: true,
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    console.log('✓ Manager created: manager@testrestaurant.com (password: TestManager123)');

    // Step 4: Create Employee user
    const employeeUser = await auth.createUser({
      email: 'employee@testrestaurant.com',
      password: 'TestEmployee123',
      displayName: 'Bob Employee',
    });

    await db.collection('users').doc(employeeUser.uid).set({
      id: employeeUser.uid,
      email: 'employee@testrestaurant.com',
      firstName: 'Bob',
      lastName: 'Employee',
      role: 'employee',
      companyId: companyId,
      phoneNumber: '555-0102',
      employmentType: 'full-time',
      hourlyRate: 15.0,
      isActive: true,
      isKeyholder: false,
      managerId: managerUser.uid,
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    console.log('✓ Employee created: employee@testrestaurant.com (password: TestEmployee123)');

    console.log('\n═══════════════════════════════════════════════════════');
    console.log('✓ Test company setup complete!');
    console.log('═══════════════════════════════════════════════════════');
    console.log('\nCompany: Test Restaurant Co.');
    console.log('Company ID:', companyId);
    console.log('\nAccounts created:');
    console.log('  Admin:    admin@testrestaurant.com    / TestAdmin123');
    console.log('  Manager:  manager@testrestaurant.com  / TestManager123');
    console.log('  Employee: employee@testrestaurant.com / TestEmployee123');
    console.log('\nTo test the time clock:');
    console.log('  1. Log in as: employee@testrestaurant.com');
    console.log('  2. Navigate to the Clock screen');
    console.log('  3. Test: Clock In → Start Break → End Break → Clock Out');
    console.log('═══════════════════════════════════════════════════════\n');

  } catch (error) {
    console.error('Error creating test company:', error);
    process.exit(1);
  }

  process.exit(0);
}

createTestCompany();
