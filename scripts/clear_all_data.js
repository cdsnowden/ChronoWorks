const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccount = JSON.parse(
  fs.readFileSync('../functions/serviceAccountKey.json', 'utf8')
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();
const db = admin.firestore();

async function clearAllData() {
  console.log('🗑️  Starting data cleanup...\n');

  // 1. Delete all Firebase Auth users
  console.log('1️⃣  Deleting Firebase Auth users...');
  let authUsersDeleted = 0;

  try {
    const listUsersResult = await auth.listUsers();
    const uids = listUsersResult.users.map(user => user.uid);

    for (const uid of uids) {
      await auth.deleteUser(uid);
      authUsersDeleted++;
      console.log(`   ✓ Deleted auth user: ${uid}`);
    }
    console.log(`   ✅ Deleted ${authUsersDeleted} Firebase Auth users\n`);
  } catch (error) {
    console.error('   ❌ Error deleting auth users:', error.message);
  }

  // 2. Delete all users from Firestore
  console.log('2️⃣  Deleting Firestore users collection...');
  let firestoreUsersDeleted = 0;

  try {
    const usersSnapshot = await db.collection('users').get();
    const batch = db.batch();

    usersSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
      firestoreUsersDeleted++;
      console.log(`   ✓ Queued deletion: users/${doc.id}`);
    });

    await batch.commit();
    console.log(`   ✅ Deleted ${firestoreUsersDeleted} user documents\n`);
  } catch (error) {
    console.error('   ❌ Error deleting Firestore users:', error.message);
  }

  // 3. Delete all companies
  console.log('3️⃣  Deleting companies collection...');
  let companiesDeleted = 0;

  try {
    const companiesSnapshot = await db.collection('companies').get();
    const batch = db.batch();

    companiesSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
      companiesDeleted++;
      console.log(`   ✓ Queued deletion: companies/${doc.id}`);
    });

    await batch.commit();
    console.log(`   ✅ Deleted ${companiesDeleted} company documents\n`);
  } catch (error) {
    console.error('   ❌ Error deleting companies:', error.message);
  }

  // 4. Delete subscription changes log
  console.log('4️⃣  Deleting subscription changes log...');
  let subscriptionChangesDeleted = 0;

  try {
    const subChangesSnapshot = await db.collection('subscriptionChanges').get();

    if (!subChangesSnapshot.empty) {
      const batch = db.batch();
      subChangesSnapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
        subscriptionChangesDeleted++;
      });
      await batch.commit();
      console.log(`   ✅ Deleted ${subscriptionChangesDeleted} subscription change logs\n`);
    } else {
      console.log(`   ℹ️  No subscription changes to delete\n`);
    }
  } catch (error) {
    console.error('   ❌ Error deleting subscription changes:', error.message);
  }

  // Summary
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('✅ CLEANUP COMPLETE!');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`   Auth users deleted: ${authUsersDeleted}`);
  console.log(`   Firestore users deleted: ${firestoreUsersDeleted}`);
  console.log(`   Companies deleted: ${companiesDeleted}`);
  console.log(`   Subscription logs deleted: ${subscriptionChangesDeleted}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.log('📝 NOTE: Subscription plans were NOT deleted (they are reusable)');
  console.log('\n🎯 NEXT STEPS:');
  console.log('   1. Go to https://chronoworks-dcfd6.web.app');
  console.log('   2. You will be redirected to First Admin setup');
  console.log('   3. Create your super admin account\n');

  process.exit(0);
}

// Run the cleanup
clearAllData().catch(error => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});
