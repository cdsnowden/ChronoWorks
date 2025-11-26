// Script to add test shifts to John Smith to trigger overtime warnings
const admin = require('firebase-admin');

// Initialize with project ID
admin.initializeApp({
  projectId: 'chronoworks-app'
});

const db = admin.firestore();

async function addTestShifts() {
  const employeeEmail = 'john.smith@example.com';

  console.log(`\n=== Adding Test Shifts for ${employeeEmail} ===\n`);

  try {
    // Get John Smith's user ID
    const usersSnapshot = await db.collection('users')
      .where('email', '==', employeeEmail)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.log('❌ Employee not found');
      return;
    }

    const employeeDoc = usersSnapshot.docs[0];
    const employee = employeeDoc.data();
    const employeeId = employeeDoc.id;

    console.log('✅ Employee found:');
    console.log(`   UID: ${employeeId}`);
    console.log(`   Name: ${employee.firstName} ${employee.lastName}\n`);

    // Get current week boundaries (Sunday to Saturday)
    const now = new Date();
    const dayOfWeek = now.getDay(); // 0 = Sunday, 1 = Monday, etc.

    const weekStart = new Date(now);
    weekStart.setDate(now.getDate() - dayOfWeek);
    weekStart.setHours(0, 0, 0, 0);

    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekStart.getDate() + 6);
    weekEnd.setHours(23, 59, 59, 999);

    console.log(`📅 Current Week: ${weekStart.toLocaleDateString()} - ${weekEnd.toLocaleDateString()}`);
    console.log(`   Today: ${now.toLocaleDateString()} (${['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][dayOfWeek]})\n`);

    // Delete existing shifts for this week to start fresh
    console.log('🗑️  Deleting existing shifts for this week...');
    const existingShifts = await db.collection('shifts')
      .where('employeeId', '==', employeeId)
      .where('startTime', '>=', admin.firestore.Timestamp.fromDate(weekStart))
      .where('startTime', '<=', admin.firestore.Timestamp.fromDate(weekEnd))
      .get();

    const deletePromises = existingShifts.docs.map(doc => doc.ref.delete());
    await Promise.all(deletePromises);
    console.log(`   Deleted ${existingShifts.size} existing shifts\n`);

    // Add test shifts
    // Scenario: Employee worked Monday-Thursday (8 hours each = 32 hours)
    // Still scheduled Friday (10 hours)
    // Total projected: 42 hours = CRITICAL RISK

    const shifts = [];

    // Past shifts (Monday-Thursday) - These have already "happened"
    for (let i = 1; i <= 4; i++) {
      const shiftDate = new Date(weekStart);
      shiftDate.setDate(weekStart.getDate() + i); // Monday = day 1
      shiftDate.setHours(9, 0, 0, 0);

      const shiftEnd = new Date(shiftDate);
      shiftEnd.setHours(17, 0, 0, 0); // 9 AM - 5 PM = 8 hours

      shifts.push({
        employeeId: employeeId,
        employeeName: `${employee.firstName} ${employee.lastName}`,
        startTime: admin.firestore.Timestamp.fromDate(shiftDate),
        endTime: admin.firestore.Timestamp.fromDate(shiftEnd),
        isDayOff: false,
        createdAt: admin.firestore.Timestamp.now(),
      });
    }

    // Future shift (Friday) - This is upcoming
    const fridayShift = new Date(weekStart);
    fridayShift.setDate(weekStart.getDate() + 5); // Friday
    fridayShift.setHours(8, 0, 0, 0);

    const fridayEnd = new Date(fridayShift);
    fridayEnd.setHours(18, 0, 0, 0); // 8 AM - 6 PM = 10 hours

    shifts.push({
      employeeId: employeeId,
      employeeName: `${employee.firstName} ${employee.lastName}`,
      startTime: admin.firestore.Timestamp.fromDate(fridayShift),
      endTime: admin.firestore.Timestamp.fromDate(fridayEnd),
      isDayOff: false,
      createdAt: admin.firestore.Timestamp.now(),
    });

    console.log('➕ Adding test shifts:');
    for (const shift of shifts) {
      const shiftRef = await db.collection('shifts').add(shift);
      const start = shift.startTime.toDate();
      const end = shift.endTime.toDate();
      const hours = (end - start) / (1000 * 60 * 60);
      const dayName = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][start.getDay()];
      console.log(`   ✓ ${dayName} ${start.toLocaleString()}: ${hours} hours`);
    }

    // Add time entries for Monday-Thursday to simulate that they've already worked
    console.log('\n⏰ Adding completed time entries (simulating past work):');
    for (let i = 1; i <= 4; i++) {
      const workDate = new Date(weekStart);
      workDate.setDate(weekStart.getDate() + i);

      // Clock in at 8:45 AM (15 minutes early)
      const clockIn = new Date(workDate);
      clockIn.setHours(8, 45, 0, 0);

      // Clock out at 5:10 PM (10 minutes late)
      const clockOut = new Date(workDate);
      clockOut.setHours(17, 10, 0, 0);

      const timeEntry = {
        userId: employeeId,
        employeeId: employeeId,
        clockInTime: admin.firestore.Timestamp.fromDate(clockIn),
        clockOutTime: admin.firestore.Timestamp.fromDate(clockOut),
        createdAt: admin.firestore.Timestamp.now(),
      };

      const entryRef = await db.collection('timeEntries').add(timeEntry);
      const dayName = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][workDate.getDay()];

      // Add a 25-minute break (short break - should trigger violation)
      const breakEntry = {
        timeEntryId: entryRef.id,
        userId: employeeId,
        startTime: admin.firestore.Timestamp.fromDate(new Date(clockIn.getTime() + 4 * 60 * 60 * 1000)), // 4 hours after clock in
        endTime: admin.firestore.Timestamp.fromDate(new Date(clockIn.getTime() + 4 * 60 * 60 * 1000 + 25 * 60 * 1000)), // 25 minute break
        createdAt: admin.firestore.Timestamp.now(),
      };

      await db.collection('breakEntries').add(breakEntry);

      const workedHours = ((clockOut - clockIn) - (25 * 60 * 1000)) / (1000 * 60 * 60);
      console.log(`   ✓ ${dayName}: ${clockIn.toLocaleTimeString()} - ${clockOut.toLocaleTimeString()} (${workedHours.toFixed(2)}h worked, 25 min break)`);
      console.log(`      ⚠️  Early clock-in: 15 min, Late clock-out: 10 min, Short break: 5 min`);
    }

    console.log('\n=== TEST DATA CREATED ===');
    console.log('📊 Expected Results:');
    console.log('   - Actual Hours Worked: ~32.6 hours (4 days × ~8.15h)');
    console.log('   - Remaining Scheduled: 10 hours (Friday shift)');
    console.log('   - Total Projected: ~42.6 hours');
    console.log('   - Overtime: ~2.6 hours');
    console.log('   - Risk Level: CRITICAL (RED)');
    console.log('\n   - Violations Detected:');
    console.log('     * Early clock-ins: 4 instances (15 min each)');
    console.log('     * Late clock-outs: 4 instances (10 min each)');
    console.log('     * Short breaks: 4 instances (25 min instead of 30 min)');
    console.log('\n✅ Log in as John Smith to see the CRITICAL overtime warning!\n');

  } catch (error) {
    console.error('Error:', error);
  }

  process.exit(0);
}

addTestShifts();
