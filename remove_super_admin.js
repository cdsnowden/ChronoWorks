const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});
const db = admin.firestore();

async function removeSuperAdmin() {
  const uidToRemove = 'Z1eL0Hz4pcdqYk1GJKbr0OWGOKv2';

  console.log('Removing super admin: Chris Snowden');
  console.log('UID:', uidToRemove);
  console.log('');

  // Check if exists first
  const doc = await db.collection('superAdmins').doc(uidToRemove).get();

  if (!doc.exists) {
    console.log('❌ Super admin document not found');
    return;
  }

  console.log('Found super admin:', doc.data());
  console.log('');

  // Delete from superAdmins collection
  await db.collection('superAdmins').doc(uidToRemove).delete();
  console.log('✅ Removed from superAdmins collection');

  // Verify deletion
  const verify = await db.collection('superAdmins').doc(uidToRemove).get();
  if (!verify.exists) {
    console.log('✅ Deletion confirmed');
  }

  console.log('');
  console.log('Remaining super admins:');
  const remaining = await db.collection('superAdmins').get();
  remaining.forEach(doc => {
    const data = doc.data();
    console.log('  -', data.displayName || data.name || 'Unknown');
    console.log('    Email:', data.email);
    console.log('    UID:', doc.id);
  });
}

removeSuperAdmin().then(() => process.exit()).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
