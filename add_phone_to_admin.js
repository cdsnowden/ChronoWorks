const admin = require('firebase-admin');
const serviceAccount = require('./flutter_app/chronoworks-dcfd6-firebase-adminsdk.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function addPhoneToAdmin() {
  try {
    // Find all admin users
    const adminsSnapshot = await db.collection('users')
      .where('role', '==', 'admin')
      .get();

    if (adminsSnapshot.empty) {
      console.log('No admin users found!');
      return;
    }

    console.log(`\nFound ${adminsSnapshot.size} admin user(s):\n`);

    adminsSnapshot.forEach((doc) => {
      const user = doc.data();
      console.log(`ID: ${doc.id}`);
      console.log(`Name: ${user.firstName} ${user.lastName}`);
      console.log(`Email: ${user.email}`);
      console.log(`Phone: ${user.phoneNumber || 'NOT SET'}`);
      console.log('---');
    });

    // Uncomment and modify this section to add a phone number to a specific admin
    /*
    const adminUserId = 'YOUR_ADMIN_USER_ID_HERE'; // Replace with actual ID from above
    const phoneNumber = '+19102188902'; // Replace with your phone number in E.164 format

    await db.collection('users').doc(adminUserId).update({
      phoneNumber: phoneNumber
    });

    console.log(`\nPhone number ${phoneNumber} added to admin user ${adminUserId}`);
    */

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

addPhoneToAdmin();
