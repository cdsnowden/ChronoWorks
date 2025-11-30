const admin = require('firebase-admin');
const fs = require('fs');
const readline = require('readline');

// Initialize Firebase Admin
const serviceAccount = JSON.parse(
  fs.readFileSync('../functions/serviceAccountKey.json', 'utf8')
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();
const db = admin.firestore();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(prompt) {
  return new Promise((resolve) => {
    rl.question(prompt, resolve);
  });
}

async function createSuperAdmin() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('       CREATE CHRONOWORKS SUPER ADMIN ACCOUNT');
  console.log('═══════════════════════════════════════════════════════\n');

  try {
    // Check if any users exist
    const usersSnapshot = await db.collection('users').limit(1).get();
    if (!usersSnapshot.empty) {
      console.log('⚠️  WARNING: Users already exist in the system.');
      const proceed = await question('Do you want to create another super admin? (yes/no): ');
      if (proceed.toLowerCase() !== 'yes' && proceed.toLowerCase() !== 'y') {
        console.log('Cancelled.\n');
        rl.close();
        process.exit(0);
      }
    }

    // Collect user information
    console.log('\n📝 Enter super admin details:\n');
    const email = await question('Email: ');
    const password = await question('Password (min 6 characters): ');
    const firstName = await question('First Name: ');
    const lastName = await question('Last Name: ');
    const phoneNumber = await question('Phone Number (optional, press Enter to skip): ');

    console.log('\n🔄 Creating super admin account...\n');

    // Create Firebase Auth user
    const userRecord = await auth.createUser({
      email: email.trim(),
      password: password,
      displayName: `${firstName.trim()} ${lastName.trim()}`,
    });

    const uid = userRecord.uid;
    console.log(`✓ Firebase Auth user created: ${uid}`);

    // Create user document in Firestore
    const userData = {
      id: uid,
      email: email.trim(),
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      role: 'admin',
      phoneNumber: phoneNumber.trim() || null,
      profileImageUrl: null,
      faceImageUrl: null,
      employmentType: 'full-time',
      hourlyRate: 0.0,
      isActive: true,
      isKeyholder: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: null,
      managerId: null,
      workLocation: null,
    };

    await db.collection('users').doc(uid).set(userData);
    console.log('✓ User document created in Firestore');

    // Create super admin entry
    await db.collection('superAdmins').doc(uid).set({
      email: email.trim(),
      displayName: `${firstName.trim()} ${lastName.trim()}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      permissions: {
        approveRegistrations: true,
        manageSubscriptionPlans: true,
        viewAllCompanies: true,
        manageAllUsers: true
      }
    });
    console.log('✓ Super admin entry created');

    console.log('\n╔═══════════════════════════════════════════════════════╗');
    console.log('║              ✅ SUCCESS!                              ║');
    console.log('╚═══════════════════════════════════════════════════════╝\n');
    console.log('Super Admin Account Created:');
    console.log(`   Name: ${firstName} ${lastName}`);
    console.log(`   Email: ${email}`);
    console.log(`   UID: ${uid}\n`);
    console.log('🌐 You can now log in at: https://chronoworks.co\n');

  } catch (error) {
    console.error('\n💥 Error:', error.message);

    if (error.code === 'auth/email-already-exists') {
      console.log('\n📌 This email is already registered.');
      console.log('If you want to make an existing user a super admin, use:');
      console.log('   node make_super_admin.js\n');
    }
  } finally {
    rl.close();
    process.exit(0);
  }
}

createSuperAdmin();
