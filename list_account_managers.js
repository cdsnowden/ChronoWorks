const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function listAccountManagers() {
  try {
    const snapshot = await db.collection('accountManagers').get();

    console.log(`Found ${snapshot.size} Account Manager(s):\n`);

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      console.log(`ID: ${doc.id}`);
      console.log(`Name: ${data.displayName}`);
      console.log(`Email: ${data.email}`);
      console.log(`Status: ${data.status}`);
      console.log('---\n');
    });

    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

listAccountManagers();
