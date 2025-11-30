const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccount = JSON.parse(
  fs.readFileSync('../functions/serviceAccountKey.json', 'utf8')
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkFaceRegistration() {
  console.log('Checking face registration status for all users...\n');

  const usersSnapshot = await db.collection('users').get();

  console.log('User ID                              | Name                    | Role      | Face Registered');
  console.log('-------------------------------------|-------------------------|-----------|----------------');

  usersSnapshot.forEach(doc => {
    const data = doc.data();
    const name = `${data.firstName || ''} ${data.lastName || ''}`.trim().padEnd(23);
    const role = (data.role || 'unknown').padEnd(9);
    const faceRegistered = data.faceRegistered === true ? 'YES' : 'NO';

    console.log(`${doc.id} | ${name} | ${role} | ${faceRegistered}`);
  });

  console.log('\n');
  process.exit(0);
}

checkFaceRegistration().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
