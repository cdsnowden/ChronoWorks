// Debug script to check employee overtime status
const admin = require('firebase-admin');

// Initialize with project ID (uses Application Default Credentials from Firebase CLI)
admin.initializeApp({
  projectId: 'chronoworks-app'
});

const db = admin.firestore();

async function debugEmployee(employeeEmail) {
  console.log(`\n=== Debugging Overtime for: ${employeeEmail} ===\n`);

  try {
    // Get user by email
    const usersSnapshot = await db.collection('users')
      .where('email', '==', employeeEmail)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.log('❌ Employee not found in Firestore users collection');
      return;
    }

    const employeeDoc = usersSnapshot.docs[0];
    const employee = employeeDoc.data();
    const employeeId = employeeDoc.id;

    console.log('✅ Employee found:');
    console.log(`   UID: ${employeeId}`);
    console.log(`   Name: ${employee.firstName} ${employee.lastName}`);
    console.log(`   Role: ${employee.role}`);
    console.log(`   Email: ${employee.email}\n`);

    // Get current week boundaries (Sunday to Saturday)
    const now = new Date();
    const dayOfWeek = now.getDay();
    const weekStart = new Date(now);
    weekStart.setDate(now.getDate() - dayOfWeek);
    weekStart.setHours(0, 0, 0, 0);

    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekStart.getDate() + 6);
    weekEnd.setHours(23, 59, 59, 999);

    console.log(`📅 Current Week: ${weekStart.toLocaleDateString()} - ${weekEnd.toLocaleDateString()}\n`);

    // Check shifts this week
    const shiftsSnapshot = await db.collection('shifts')
      .where('employeeId', '==', employeeId)
      .where('startTime', '>=', admin.firestore.Timestamp.fromDate(weekStart))
      .where('startTime', '<=', admin.firestore.Timestamp.fromDate(weekEnd))
      .get();

    console.log(`📋 Shifts this week: ${shiftsSnapshot.size}`);
    let totalScheduledHours = 0;
    shiftsSnapshot.forEach(doc => {
      const shift = doc.data();
      const start = shift.startTime.toDate();
      const end = shift.endTime.toDate();
      const hours = (end - start) / (1000 * 60 * 60);
      totalScheduledHours += hours;
      console.log(`   - ${start.toLocaleString()}: ${hours.toFixed(1)} hours`);
    });
    console.log(`   Total Scheduled: ${totalScheduledHours.toFixed(1)} hours\n`);

    // Check time entries this week
    const timeEntriesSnapshot = await db.collection('timeEntries')
      .where('employeeId', '==', employeeId)
      .where('clockInTime', '>=', admin.firestore.Timestamp.fromDate(weekStart))
      .where('clockInTime', '<=', admin.firestore.Timestamp.fromDate(weekEnd))
      .get();

    console.log(`⏰ Time entries this week: ${timeEntriesSnapshot.size}`);
    let totalWorkedHours = 0;
    let violations = [];

    for (const doc of timeEntriesSnapshot.docs) {
      const entry = doc.data();
      const clockIn = entry.clockInTime.toDate();
      const clockOut = entry.clockOutTime ? entry.clockOutTime.toDate() : null;

      if (!clockOut) {
        console.log(`   - ${clockIn.toLocaleString()}: Still clocked in`);
        continue;
      }

      let workedMs = clockOut - clockIn;

      // Get breaks for this entry
      const breaksSnapshot = await db.collection('breakEntries')
        .where('timeEntryId', '==', doc.id)
        .get();

      let totalBreakMinutes = 0;
      breaksSnapshot.forEach(breakDoc => {
        const breakEntry = breakDoc.data();
        if (breakEntry.endTime) {
          const breakStart = breakEntry.startTime.toDate();
          const breakEnd = breakEntry.endTime.toDate();
          const breakMinutes = (breakEnd - breakStart) / (1000 * 60);
          totalBreakMinutes += breakMinutes;
        }
      });

      // Subtract breaks
      workedMs -= totalBreakMinutes * 60 * 1000;
      const workedHours = workedMs / (1000 * 60 * 60);
      totalWorkedHours += workedHours;

      console.log(`   - ${clockIn.toLocaleString()} → ${clockOut.toLocaleString()}`);
      console.log(`     Worked: ${workedHours.toFixed(2)} hours (${totalBreakMinutes.toFixed(0)} min break)`);

      // Check for violations
      // Find matching shift
      const matchingShift = shiftsSnapshot.docs.find(shiftDoc => {
        const shift = shiftDoc.data();
        const shiftStart = shift.startTime.toDate();
        const timeDiff = Math.abs(clockIn - shiftStart) / (1000 * 60);
        return timeDiff < 120; // Within 2 hours
      });

      if (matchingShift) {
        const shift = matchingShift.data();
        const scheduledStart = shift.startTime.toDate();
        const scheduledEnd = shift.endTime.toDate();

        // Early clock-in
        const earlyMinutes = (scheduledStart - clockIn) / (1000 * 60);
        if (earlyMinutes > 10) {
          violations.push(`Early clock-in: ${earlyMinutes.toFixed(0)} minutes early`);
          console.log(`     ⚠️  Clocked in ${earlyMinutes.toFixed(0)} minutes early`);
        }

        // Late clock-out
        const lateMinutes = (clockOut - scheduledEnd) / (1000 * 60);
        if (lateMinutes > 10) {
          violations.push(`Late clock-out: ${lateMinutes.toFixed(0)} minutes late`);
          console.log(`     ⚠️  Clocked out ${lateMinutes.toFixed(0)} minutes late`);
        }

        // Short break
        const expectedBreakMinutes = 30;
        if (totalBreakMinutes < expectedBreakMinutes && workedHours > 5) {
          violations.push(`Short break: ${totalBreakMinutes.toFixed(0)} minutes (expected ${expectedBreakMinutes})`);
          console.log(`     ⚠️  Short break: ${totalBreakMinutes.toFixed(0)} minutes`);
        }
      }
    }

    console.log(`   Total Worked: ${totalWorkedHours.toFixed(1)} hours\n`);

    // Check active clock-in
    const activeClockInSnapshot = await db.collection('activeClockIns')
      .where('employeeId', '==', employeeId)
      .limit(1)
      .get();

    let currentShiftProjected = 0;
    if (!activeClockInSnapshot.empty) {
      const activeClockIn = activeClockInSnapshot.docs[0].data();
      const clockInTime = activeClockIn.clockInTime.toDate();
      const currentTime = new Date();
      const hoursElapsed = (currentTime - clockInTime) / (1000 * 60 * 60);
      currentShiftProjected = hoursElapsed;
      console.log(`🔵 Currently clocked in: ${hoursElapsed.toFixed(1)} hours elapsed\n`);
    } else {
      console.log(`⚪ Not currently clocked in\n`);
    }

    // Calculate remaining scheduled hours
    const remainingShifts = shiftsSnapshot.docs.filter(doc => {
      const shift = doc.data();
      const shiftStart = shift.startTime.toDate();
      return shiftStart > now;
    });

    let remainingScheduledHours = 0;
    console.log(`📅 Remaining shifts: ${remainingShifts.length}`);
    remainingShifts.forEach(doc => {
      const shift = doc.data();
      const start = shift.startTime.toDate();
      const end = shift.endTime.toDate();
      const hours = (end - start) / (1000 * 60 * 60);
      remainingScheduledHours += hours;
      console.log(`   - ${start.toLocaleString()}: ${hours.toFixed(1)} hours`);
    });
    console.log(`   Total Remaining: ${remainingScheduledHours.toFixed(1)} hours\n`);

    // Calculate projected total
    const projectedTotal = totalWorkedHours + currentShiftProjected + remainingScheduledHours;
    const overtimeHours = Math.max(0, projectedTotal - 40);

    console.log(`\n=== OVERTIME ANALYSIS ===`);
    console.log(`Actual Hours Worked: ${totalWorkedHours.toFixed(1)} hours`);
    console.log(`Current Shift Projected: ${currentShiftProjected.toFixed(1)} hours`);
    console.log(`Remaining Scheduled: ${remainingScheduledHours.toFixed(1)} hours`);
    console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    console.log(`PROJECTED TOTAL: ${projectedTotal.toFixed(1)} hours`);
    console.log(`OVERTIME: ${overtimeHours.toFixed(1)} hours`);

    let riskLevel;
    if (projectedTotal >= 42) riskLevel = 'CRITICAL';
    else if (projectedTotal >= 40) riskLevel = 'HIGH';
    else if (projectedTotal >= 38) riskLevel = 'MEDIUM';
    else riskLevel = 'LOW';

    console.log(`RISK LEVEL: ${riskLevel}`);
    console.log(`\n⚠️  Violations found: ${violations.length}`);
    violations.forEach(v => console.log(`   - ${v}`));

    console.log(`\n=== VISIBILITY CHECK ===`);
    if (riskLevel === 'LOW') {
      console.log('❌ Warning card will NOT show (risk level is LOW)');
      console.log('   Card only shows for MEDIUM, HIGH, or CRITICAL risk');
    } else {
      console.log('✅ Warning card SHOULD show on employee dashboard');
    }

    if (projectedTotal >= 38) {
      console.log('✅ Email notifications SHOULD be sent');
    } else {
      console.log('❌ Email notifications will NOT be sent (threshold not met)');
    }

  } catch (error) {
    console.error('Error:', error);
  }

  process.exit(0);
}

// Get employee email from command line or use default
const employeeEmail = process.argv[2] || 'john.smith@example.com';
debugEmployee(employeeEmail);
