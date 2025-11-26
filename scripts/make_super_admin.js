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

const db = admin.firestore();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

async function listAllUsers() {
  console.log('\n📋 All users in the system:\n');

  const usersSnapshot = await db.collection('users').get();

  if (usersSnapshot.empty) {
    console.log('   ❌ No users found. Please create your account first through the First Admin Setup.\n');
    process.exit(1);
  }

  const users = [];
  usersSnapshot.forEach((doc) => {
    const data = doc.data();
    users.push({
      uid: doc.id,
      name: `${data.firstName} ${data.lastName}`,
      email: data.email,
      role: data.role
    });
    console.log(`   ${users.length}. ${data.firstName} ${data.lastName} (${data.email})`);
    console.log(`      UID: ${doc.id}`);
    console.log(`      Role: ${data.role}\n`);
  });

  return users;
}

async function checkSuperAdmins() {
  const superAdminsSnapshot = await db.collection('superAdmins').get();

  if (!superAdminsSnapshot.empty) {
    console.log('⚠️  WARNING: Super admin(s) already exist:\n');
    superAdminsSnapshot.forEach((doc) => {
      const data = doc.data();
      console.log(`   - ${data.displayName || 'Unknown'} (${data.email || doc.id})`);
    });
    console.log('');
  }

  return superAdminsSnapshot.size;
}

async function makeSuperAdmin(userId) {
  // Get user data
  const userDoc = await db.collection('users').doc(userId).get();

  if (!userDoc.exists) {
    throw new Error('User not found');
  }

  const userData = userDoc.data();

  // Create super admin entry
  await db.collection('superAdmins').doc(userId).set({
    email: userData.email,
    displayName: `${userData.firstName} ${userData.lastName}`,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    permissions: {
      approveRegistrations: true,
      manageSubscriptionPlans: true,
      viewAllCompanies: true,
      manageAllUsers: true
    }
  });

  console.log('\n✅ SUCCESS! Super admin created:\n');
  console.log(`   Name: ${userData.firstName} ${userData.lastName}`);
  console.log(`   Email: ${userData.email}`);
  console.log(`   UID: ${userId}\n`);
  console.log('🎉 You now have super admin privileges!\n');
}

async function promptForUser(users) {
  return new Promise((resolve) => {
    rl.question('\nEnter the number of the user to make super admin (or "q" to quit): ', (answer) => {
      if (answer.toLowerCase() === 'q') {
        console.log('Cancelled.\n');
        process.exit(0);
      }

      const index = parseInt(answer) - 1;
      if (isNaN(index) || index < 0 || index >= users.length) {
        console.log('Invalid selection. Please try again.');
        resolve(promptForUser(users));
      } else {
        resolve(users[index].uid);
      }
    });
  });
}

async function main() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('           CHRONOWORKS SUPER ADMIN SETUP');
  console.log('═══════════════════════════════════════════════════════\n');

  try {
    // Check if super admins already exist
    const existingSuperAdminCount = await checkSuperAdmins();

    if (existingSuperAdminCount > 0) {
      rl.question('Do you want to add another super admin? (yes/no): ', async (answer) => {
        if (answer.toLowerCase() !== 'yes' && answer.toLowerCase() !== 'y') {
          console.log('Cancelled.\n');
          process.exit(0);
        }

        // Continue with the process
        const users = await listAllUsers();
        const userId = await promptForUser(users);
        await makeSuperAdmin(userId);
        rl.close();
        process.exit(0);
      });
    } else {
      // No super admins exist yet
      const users = await listAllUsers();
      const userId = await promptForUser(users);
      await makeSuperAdmin(userId);
      rl.close();
      process.exit(0);
    }

  } catch (error) {
    console.error('💥 Error:', error.message);
    rl.close();
    process.exit(1);
  }
}

main();
