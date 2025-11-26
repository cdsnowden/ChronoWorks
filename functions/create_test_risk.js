const admin = require('firebase-admin');

// Initialize with application default credentials
// This will use GOOGLE_APPLICATION_CREDENTIALS environment variable if set,
// or the Firebase CLI credentials
admin.initializeApp({
  projectId: 'chronoworks-1f0b7',
});

const db = admin.firestore();

async function createTestRisk() {
  try {
    // Get John Smith's user ID
    const usersSnapshot = await db.collection('users')
      .where('firstName', '==', 'John')
      .where('lastName', '==', 'Smith')
      .get();

    if (usersSnapshot.empty) {
      console.log('John Smith not found');
      return;
    }

    const johnSmith = usersSnapshot.docs[0];
    const userId = johnSmith.id;
    const userData = johnSmith.data();

    console.log(`Found John Smith: ${userId}`);

    // Create overtime risk notification with today's date
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const riskData = {
      employeeId: userId,
      employeeName: `${userData.firstName} ${userData.lastName}`,
      riskLevel: 'critical',
      projectedHours: 42.5,
      overtimeHours: 2.5,
      date: admin.firestore.Timestamp.fromDate(today),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection('overtimeRiskNotifications').add(riskData);

    console.log('Created overtime risk notification:', docRef.id);
    console.log('Risk data:', riskData);

    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

createTestRisk();
