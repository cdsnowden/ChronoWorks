const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function findAndDeleteUser() {
  try {
    const email = 'exaltvid@gmail.com';
    console.log(`Looking for user: ${email}`);

    // Find user by email
    let user;
    try {
      user = await admin.auth().getUserByEmail(email);
      console.log('Found user:', user.uid);
    } catch (error) {
      console.log('User not found in Auth:', error.message);
    }

    if (user) {
      // Get user document to find companyId
      const userDoc = await admin.firestore().collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        console.log('User data:', JSON.stringify(userData, null, 2));

        const companyId = userData?.companyId;

        // Delete user from Firestore
        await admin.firestore().collection('users').doc(user.uid).delete();
        console.log('Deleted user document from Firestore');

        // Delete company if found
        if (companyId) {
          await admin.firestore().collection('companies').doc(companyId).delete();
          console.log('Deleted company:', companyId);
        }
      } else {
        console.log('No user document found in Firestore');
      }

      // Delete user from Auth
      await admin.auth().deleteUser(user.uid);
      console.log('Deleted user from Firebase Auth');
    }

    // Find and delete registration request by email
    const regSnapshot = await admin.firestore()
      .collection('registrationRequests')
      .where('ownerEmail', '==', email)
      .get();

    if (!regSnapshot.empty) {
      for (const doc of regSnapshot.docs) {
        const data = doc.data();
        console.log('Found registration request:', doc.id, 'Status:', data.status);
        await doc.ref.delete();
        console.log('Deleted registration request:', doc.id);
      }
    } else {
      console.log('No registration requests found');
    }

    console.log(`\nCleanup complete for ${email}`);
    console.log('You can now resubmit a new registration for this email.');
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

findAndDeleteUser();
