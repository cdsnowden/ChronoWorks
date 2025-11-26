const admin = require('firebase-admin');

// Initialize with application default credentials
admin.initializeApp({
  projectId: 'chronoworks-dcfd6',
});

const db = admin.firestore();

async function testQuery() {
  try {
    console.log('Testing Firestore query...\n');

    // Calculate week start exactly like the Dart code
    const now = new Date();
    console.log('Current date:', now.toISOString());
    console.log('Day of week:', now.getDay()); // 0 = Sunday, 1 = Monday
    console.log('Weekday (Dart equivalent):', now.getDay() === 0 ? 7 : now.getDay());

    // Dart uses weekday (1=Monday, 7=Sunday), JavaScript uses getDay (0=Sunday, 6=Saturday)
    // Dart: now.weekday % 7
    // For Monday: weekday=1, 1%7 = 1
    // For Sunday: weekday=7, 7%7 = 0
    const dartWeekday = now.getDay() === 0 ? 7 : now.getDay();
    const daysToSubtract = dartWeekday % 7;

    const weekStart = new Date(now);
    weekStart.setDate(now.getDate() - daysToSubtract);
    weekStart.setHours(0, 0, 0, 0);

    console.log('\nCalculated week start:', weekStart.toISOString());
    console.log('Days subtracted:', daysToSubtract);

    // Query Firestore
    const snapshot = await db.collection('overtimeRiskNotifications')
      .where('date', '>=', admin.firestore.Timestamp.fromDate(weekStart))
      .get();

    console.log('\nQuery result:', snapshot.size, 'documents found');

    if (snapshot.empty) {
      console.log('\nNo documents match the query!');

      // Get all documents to see what's there
      const allDocs = await db.collection('overtimeRiskNotifications').get();
      console.log('\nTotal documents in collection:', allDocs.size);

      allDocs.forEach(doc => {
        const data = doc.data();
        console.log('\nDocument:', doc.id);
        console.log('  Employee:', data.employeeName);
        console.log('  Date:', data.date?.toDate().toISOString());
        console.log('  Matches query?', data.date?.toDate() >= weekStart);
      });
    } else {
      snapshot.forEach(doc => {
        const data = doc.data();
        console.log('\nMatched document:', doc.id);
        console.log('  Employee:', data.employeeName);
        console.log('  Risk Level:', data.riskLevel);
        console.log('  Projected Hours:', data.projectedHours);
        console.log('  Overtime Hours:', data.overtimeHours);
        console.log('  Date:', data.date?.toDate().toISOString());
      });
    }

    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

testQuery();
