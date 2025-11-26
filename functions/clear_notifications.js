// Clear overtime notification records to allow re-testing
const admin = require('firebase-admin');

admin.initializeApp({
  projectId: 'chronoworks-app'
});

const db = admin.firestore();

async function clearNotifications() {
  console.log('\n=== Clearing Overtime Notification Records ===\n');

  try {
    const notificationsSnapshot = await db.collection('overtimeRiskNotifications').get();

    console.log(`Found ${notificationsSnapshot.size} notification records`);

    if (notificationsSnapshot.empty) {
      console.log('No notification records to delete');
      process.exit(0);
      return;
    }

    const deletePromises = notificationsSnapshot.docs.map(doc => {
      const data = doc.data();
      console.log(`Deleting: ${doc.id} - Employee: ${data.employeeId}, Date: ${data.notificationDate?.toDate()}`);
      return doc.ref.delete();
    });

    await Promise.all(deletePromises);
    console.log(`\n✅ Deleted ${notificationsSnapshot.size} notification records`);
    console.log('You can now trigger new notifications!\n');

  } catch (error) {
    console.error('Error:', error);
  }

  process.exit(0);
}

clearNotifications();
