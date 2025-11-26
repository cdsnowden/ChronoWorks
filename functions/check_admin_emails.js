// Check admin email addresses
const admin = require('firebase-admin');

admin.initializeApp({
  projectId: 'chronoworks-dcfd6'
});

const db = admin.firestore();

async function checkAdminEmails() {
  console.log('\n=== Checking Admin User Emails ===\n');

  try {
    // Get all admin users
    const admins = await db.collection('users')
      .where('role', '==', 'admin')
      .get();

    console.log(`Found ${admins.size} admin users:\n`);

    if (admins.empty) {
      console.log('No admin users found in the system');
    } else {
      admins.forEach(doc => {
        const data = doc.data();
        console.log(`- Name: ${data.fullName || data.firstName + ' ' + data.lastName}`);
        console.log(`  Email: ${data.email}`);
        console.log(`  ID: ${doc.id}\n`);
      });
    }

    // Also check John Smith's email
    console.log('\n=== Checking John Smith\'s Email ===\n');
    const users = await db.collection('users')
      .where('firstName', '==', 'John')
      .where('lastName', '==', 'Smith')
      .get();

    if (!users.empty) {
      users.forEach(doc => {
        const data = doc.data();
        console.log(`- Name: ${data.firstName} ${data.lastName}`);
        console.log(`  Email: ${data.email}`);
        console.log(`  Role: ${data.role}`);
        console.log(`  ID: ${doc.id}\n`);
      });
    } else {
      console.log('John Smith not found');
    }

  } catch (error) {
    console.error('Error:', error);
  }

  process.exit(0);
}

checkAdminEmails();
