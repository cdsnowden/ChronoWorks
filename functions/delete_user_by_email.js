const admin = require('firebase-admin');

// Initialize Firebase Admin
process.env.GCLOUD_PROJECT = 'chronoworks-dcfd6';
admin.initializeApp({
  projectId: 'chronoworks-dcfd6'
});

const auth = admin.auth();

async function deleteUserByEmail(email) {
  try {
    // Get user by email
    const userRecord = await auth.getUserByEmail(email);
    console.log(`Found user: ${userRecord.uid}`);

    // Delete the user
    await auth.deleteUser(userRecord.uid);
    console.log(`✅ Successfully deleted user: ${email}`);

    process.exit(0);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      console.log(`ℹ️  User not found: ${email}`);
      process.exit(0);
    } else {
      console.error('❌ Error:', error.message);
      process.exit(1);
    }
  }
}

const email = process.argv[2];
if (!email) {
  console.error('Usage: node delete_user_by_email.js <email>');
  process.exit(1);
}

deleteUserByEmail(email);
