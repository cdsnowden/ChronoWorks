const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');
const twilio = require('twilio');
// Note: Firebase Functions automatically loads .env files, no dotenv package needed

// Configuration
const OVERTIME_THRESHOLD = 40.0;
const FULL_BREAK_MINUTES = 30;
const EARLY_CLOCK_IN_THRESHOLD_MINUTES = 10;
const LATE_CLOCK_OUT_THRESHOLD_MINUTES = 10;
const TIMEZONE = 'America/New_York';

/**
 * Scheduled function to monitor overtime risk for all employees
 * Runs every 2 hours during business hours
 */
exports.monitorOvertimeRisk = functions
  .runWith({ timeoutSeconds: 540, memory: '512MB' })
  .region('us-central1')
  .pubsub.schedule('0 */2 * * *') // Every 2 hours
  .timeZone(TIMEZONE)
  .onRun(async (context) => {
    console.log('Starting overtime risk monitoring...');

    try {
      // Get all employees
      const employees = await admin.firestore()
        .collection('users')
        .where('role', '==', 'employee')
        .get();

      console.log(`Checking ${employees.size} employees for overtime risk`);

      const atRiskEmployees = [];

      // Check each employee
      for (const employeeDoc of employees.docs) {
        const employeeId = employeeDoc.id;
        const employeeData = employeeDoc.data();

        const analysis = await analyzeEmployeeOvertimeRisk(employeeId);

        // Only notify if medium risk or higher
        if (analysis && analysis.riskLevel !== 'low') {
          // Check if we've already sent a notification today
          const alreadyNotified = await checkIfNotifiedToday(employeeId);

          if (!alreadyNotified) {
            atRiskEmployees.push({
              ...analysis,
              employeeName: employeeData.fullName,
              employeeEmail: employeeData.email,
              managerId: employeeData.managerId,
            });
          }
        }
      }

      console.log(`Found ${atRiskEmployees.length} at-risk employees requiring notification`);

      // Send notifications for at-risk employees
      for (const employee of atRiskEmployees) {
        await sendOvertimeRiskEmail(employee);
        await sendOvertimeRiskSMS(employee);
        await recordNotification(employee.employeeId, employee);
      }

      console.log('Overtime risk monitoring completed successfully');
      return null;
    } catch (error) {
      console.error('Error in monitorOvertimeRisk:', error);
      throw error;
    }
  });

/**
 * Firestore trigger when an employee clocks in or out
 * Immediately checks for overtime risk
 */
exports.checkOvertimeOnClockEvent = functions
  .runWith({ memory: '256MB' })
  .region('us-central1')
  .firestore.document('timeEntries/{timeEntryId}')
  .onCreate(async (snap, context) => {
    const timeEntry = snap.data();
    const employeeId = timeEntry.userId;

    console.log(`Clock event for employee ${employeeId}, checking overtime risk...`);

    try {
      const analysis = await analyzeEmployeeOvertimeRisk(employeeId);

      console.log(`[${employeeId}] Analysis result:`, analysis ? `Risk: ${analysis.riskLevel}, Projected: ${analysis.projectedTotal}h` : 'null');

      // Send immediate warning if high or critical risk
      if (analysis && (analysis.riskLevel === 'high' || analysis.riskLevel === 'critical')) {
        console.log(`[${employeeId}] High/Critical risk detected, checking if already notified today...`);
        const alreadyNotified = await checkIfNotifiedToday(employeeId);
        console.log(`[${employeeId}] Already notified today: ${alreadyNotified}`);

        if (!alreadyNotified) {
          console.log(`[${employeeId}] Fetching employee data for notification...`);
          const employeeDoc = await admin.firestore().collection('users').doc(employeeId).get();
          const employeeData = employeeDoc.data();
          console.log(`[${employeeId}] Employee name: ${employeeData.fullName}, email: ${employeeData.email}`);

          const notificationData = {
            ...analysis,
            employeeName: employeeData.fullName,
            employeeEmail: employeeData.email,
            managerId: employeeData.managerId,
          };

          console.log(`[${employeeId}] Sending overtime risk email...`);
          await sendOvertimeRiskEmail(notificationData);
          console.log(`[${employeeId}] Email sent successfully`);

          console.log(`[${employeeId}] Sending overtime risk SMS...`);
          await sendOvertimeRiskSMS(notificationData);
          console.log(`[${employeeId}] SMS sent successfully`);

          console.log(`[${employeeId}] Recording notification...`);
          await recordNotification(employeeId, analysis);
          console.log(`[${employeeId}] Notification recorded`);
        } else {
          console.log(`[${employeeId}] Skipping notification - already notified today`);
        }
      } else {
        console.log(`[${employeeId}] No high/critical risk detected, skipping notification`);
      }

      return null;
    } catch (error) {
      console.error('Error in checkOvertimeOnClockEvent:', error);
      return null; // Don't fail the clock-in/out operation
    }
  });

/**
 * Analyze overtime risk for a single employee
 */
async function analyzeEmployeeOvertimeRisk(employeeId) {
  try {
    const now = new Date();
    const weekStart = getWeekStart(now);
    const weekEnd = getWeekEnd(now);

    console.log(`[${employeeId}] Analyzing overtime risk...`);
    console.log(`[${employeeId}] Week: ${weekStart.toISOString()} to ${weekEnd.toISOString()}`);

    // 1. Calculate actual hours worked this week
    const actualHours = await calculateActualWeeklyHours(employeeId, weekStart, weekEnd);
    console.log(`[${employeeId}] Actual hours worked: ${actualHours.toFixed(2)}h`);

    // 2. Calculate remaining scheduled hours
    const remainingScheduled = await calculateRemainingScheduledHours(employeeId, now, weekEnd);
    console.log(`[${employeeId}] Remaining scheduled hours: ${remainingScheduled.toFixed(2)}h`);

    // 3. Check if currently clocked in and project hours
    const currentShiftHours = await projectCurrentShiftHours(employeeId);
    console.log(`[${employeeId}] Current shift hours: ${currentShiftHours.toFixed(2)}h`);

    // 4. Calculate total projected hours
    const projectedTotal = actualHours + currentShiftHours + remainingScheduled;
    console.log(`[${employeeId}] Projected total: ${projectedTotal.toFixed(2)}h (${actualHours.toFixed(2)} + ${currentShiftHours.toFixed(2)} + ${remainingScheduled.toFixed(2)})`);

    // 5. Determine risk level
    const riskLevel = calculateRiskLevel(projectedTotal);
    console.log(`[${employeeId}] Risk level: ${riskLevel}`);

    // Only return analysis if there's a risk
    if (riskLevel === 'low') {
      console.log(`[${employeeId}] Risk level is LOW, skipping notification`);
      return null;
    }

    // 6. Analyze violations
    const violations = await analyzeWeeklyViolations(employeeId, weekStart, weekEnd);

    // 7. Generate remediation strategies
    const strategies = await generateRemediationStrategies(
      employeeId,
      actualHours,
      projectedTotal,
      violations,
      weekStart,
      weekEnd
    );

    return {
      employeeId,
      weekStart,
      weekEnd,
      actualHours: actualHours.toFixed(1),
      currentShiftHours: currentShiftHours.toFixed(1),
      remainingScheduled: remainingScheduled.toFixed(1),
      projectedTotal: projectedTotal.toFixed(1),
      overtimeHours: Math.max(0, projectedTotal - OVERTIME_THRESHOLD).toFixed(1),
      riskLevel,
      violations,
      strategies,
    };
  } catch (error) {
    console.error(`Error analyzing employee ${employeeId}:`, error);
    return null;
  }
}

/**
 * Calculate actual hours worked this week
 */
async function calculateActualWeeklyHours(employeeId, weekStart, weekEnd) {
  const timeEntries = await admin.firestore()
    .collection('timeEntries')
    .where('userId', '==', employeeId)
    .where('clockInTime', '>=', weekStart)
    .where('clockInTime', '<=', weekEnd)
    .get();

  console.log(`[${employeeId}] Found ${timeEntries.size} time entries between ${weekStart.toISOString()} and ${weekEnd.toISOString()}`);

  let totalHours = 0;

  for (const doc of timeEntries.docs) {
    const entry = doc.data();

    // Only count completed entries
    if (entry.clockOutTime) {
      const clockIn = entry.clockInTime.toDate();
      const clockOut = entry.clockOutTime.toDate();

      // Get break time
      const breakMinutes = await getBreakMinutesForEntry(doc.id);

      // Calculate work time = total time - break time
      const totalMinutes = (clockOut - clockIn) / (1000 * 60);
      const workMinutes = totalMinutes - breakMinutes;

      const entryHours = workMinutes / 60.0;
      console.log(`[${employeeId}] Entry ${doc.id}: ${clockIn.toISOString()} to ${clockOut.toISOString()}, ${totalMinutes.toFixed(2)} total min - ${breakMinutes.toFixed(2)} break min = ${entryHours.toFixed(2)}h`);

      totalHours += entryHours;
    } else {
      console.log(`[${employeeId}] Entry ${doc.id}: Still clocked in (started ${entry.clockInTime.toDate().toISOString()}), skipping from actual hours`);
    }
  }

  console.log(`[${employeeId}] Total actual hours: ${totalHours.toFixed(2)}h from ${timeEntries.docs.filter(d => d.data().clockOutTime).length} completed entries`);
  return totalHours;
}

/**
 * Get break minutes for a time entry
 */
async function getBreakMinutesForEntry(timeEntryId) {
  const breaks = await admin.firestore()
    .collection('breakEntries')
    .where('timeEntryId', '==', timeEntryId)
    .get();

  let totalBreakMinutes = 0;

  for (const doc of breaks.docs) {
    const breakEntry = doc.data();
    if (breakEntry.breakEndTime) {
      const start = breakEntry.breakStartTime.toDate();
      const end = breakEntry.breakEndTime.toDate();
      totalBreakMinutes += (end - start) / (1000 * 60);
    }
  }

  return totalBreakMinutes;
}

/**
 * Calculate remaining scheduled hours
 */
async function calculateRemainingScheduledHours(employeeId, startTime, weekEnd) {
  const shifts = await admin.firestore()
    .collection('shifts')
    .where('employeeId', '==', employeeId)
    .where('startTime', '>=', startTime)
    .where('startTime', '<=', weekEnd)
    .where('isDayOff', '==', false)
    .get();

  let totalHours = 0;

  for (const doc of shifts.docs) {
    const shift = doc.data();
    if (shift.startTime && shift.endTime) {
      const start = shift.startTime.toDate();
      const end = shift.endTime.toDate();
      totalHours += (end - start) / (1000 * 60 * 60);
    }
  }

  return totalHours;
}

/**
 * Project hours for current active shift
 */
async function projectCurrentShiftHours(employeeId) {
  const activeClockIn = await admin.firestore()
    .collection('activeClockIns')
    .doc(employeeId)
    .get();

  if (!activeClockIn.exists) {
    return 0;
  }

  const timeEntryId = activeClockIn.data().timeEntryId;

  const timeEntry = await admin.firestore()
    .collection('timeEntries')
    .doc(timeEntryId)
    .get();

  if (!timeEntry.exists) {
    return 0;
  }

  const clockInTime = timeEntry.data().clockInTime.toDate();

  // Get today's scheduled shift
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const todayEnd = new Date(todayStart);
  todayEnd.setDate(todayEnd.getDate() + 1);

  const shifts = await admin.firestore()
    .collection('shifts')
    .where('employeeId', '==', employeeId)
    .where('startTime', '>=', todayStart)
    .where('startTime', '<', todayEnd)
    .where('isDayOff', '==', false)
    .limit(1)
    .get();

  let projectedEndTime = now;

  if (!shifts.empty) {
    const shift = shifts.docs[0].data();
    if (shift.endTime) {
      const scheduledEnd = shift.endTime.toDate();
      projectedEndTime = scheduledEnd > now ? scheduledEnd : now;
    }
  }

  // Get current break time
  const breakMinutes = await getBreakMinutesForEntry(timeEntryId);

  // Calculate projected work time
  const projectedMinutes = (projectedEndTime - clockInTime) / (1000 * 60);
  const projectedWorkMinutes = projectedMinutes - breakMinutes;

  return projectedWorkMinutes / 60.0;
}

/**
 * Calculate risk level
 */
function calculateRiskLevel(projectedHours) {
  if (projectedHours >= OVERTIME_THRESHOLD) {
    return 'critical';
  } else if (projectedHours >= 38.0) {
    return 'high';
  } else if (projectedHours >= 35.0) {
    return 'medium';
  } else {
    return 'low';
  }
}

/**
 * Analyze weekly violations
 */
async function analyzeWeeklyViolations(employeeId, weekStart, weekEnd) {
  const violations = [];

  const timeEntries = await admin.firestore()
    .collection('timeEntries')
    .where('userId', '==', employeeId)
    .where('clockInTime', '>=', weekStart)
    .where('clockInTime', '<=', weekEnd)
    .get();

  for (const doc of timeEntries.docs) {
    const timeEntry = doc.data();
    const clockIn = timeEntry.clockInTime.toDate();

    // Get corresponding shift
    const shift = await getShiftForDate(employeeId, clockIn);

    if (shift) {
      const scheduledStart = shift.startTime.toDate();

      // Check early clock-in
      const earlyMinutes = (scheduledStart - clockIn) / (1000 * 60);
      if (earlyMinutes >= EARLY_CLOCK_IN_THRESHOLD_MINUTES) {
        violations.push({
          type: 'earlyClockIn',
          date: formatDate(clockIn),
          minutes: Math.round(earlyMinutes),
          description: `Clocked in ${Math.round(earlyMinutes)} minutes early`,
        });
      }

      // Check late clock-out
      if (timeEntry.clockOutTime && shift.endTime) {
        const clockOut = timeEntry.clockOutTime.toDate();
        const scheduledEnd = shift.endTime.toDate();
        const lateMinutes = (clockOut - scheduledEnd) / (1000 * 60);

        if (lateMinutes >= LATE_CLOCK_OUT_THRESHOLD_MINUTES) {
          violations.push({
            type: 'lateClockOut',
            date: formatDate(clockOut),
            minutes: Math.round(lateMinutes),
            description: `Clocked out ${Math.round(lateMinutes)} minutes late`,
          });
        }
      }

      // Check for short break
      if (timeEntry.clockOutTime) {
        const shiftDuration = (timeEntry.clockOutTime.toDate() - clockIn) / (1000 * 60 * 60);
        if (shiftDuration >= 6.0) {
          const breakMinutes = await getBreakMinutesForEntry(doc.id);
          if (breakMinutes < FULL_BREAK_MINUTES) {
            violations.push({
              type: 'shortBreak',
              date: formatDate(clockIn),
              minutes: FULL_BREAK_MINUTES - Math.round(breakMinutes),
              description: `Break was ${FULL_BREAK_MINUTES - Math.round(breakMinutes)} minutes short`,
            });
          }
        }
      }
    }
  }

  return violations;
}

/**
 * Get shift for a specific date
 */
async function getShiftForDate(employeeId, date) {
  const dayStart = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const dayEnd = new Date(dayStart);
  dayEnd.setDate(dayEnd.getDate() + 1);

  const shifts = await admin.firestore()
    .collection('shifts')
    .where('employeeId', '==', employeeId)
    .where('startTime', '>=', dayStart)
    .where('startTime', '<', dayEnd)
    .where('isDayOff', '==', false)
    .limit(1)
    .get();

  return shifts.empty ? null : shifts.docs[0].data();
}

/**
 * Generate remediation strategies
 */
async function generateRemediationStrategies(employeeId, actualHours, projectedTotal, violations, weekStart, weekEnd) {
  const strategies = [];

  // Strategy 1: Clock on time
  const behaviorMinutes = violations
    .filter(v => v.type !== 'shortBreak')
    .reduce((sum, v) => sum + v.minutes, 0);

  if (behaviorMinutes > 0) {
    strategies.push({
      priority: 1,
      type: 'Clock In/Out On Time',
      hoursSaved: (behaviorMinutes / 60).toFixed(1),
      description: `Clock in and out at your scheduled times. You have accumulated ${behaviorMinutes} extra minutes this week.`,
    });
  }

  // Strategy 2: Take full breaks
  const breakMinutes = violations
    .filter(v => v.type === 'shortBreak')
    .reduce((sum, v) => sum + v.minutes, 0);

  if (breakMinutes > 0) {
    strategies.push({
      priority: 2,
      type: 'Take Full Breaks',
      hoursSaved: (breakMinutes / 60).toFixed(1),
      description: `Take your full ${FULL_BREAK_MINUTES}-minute breaks. You have missed ${breakMinutes} minutes of breaks this week.`,
    });
  }

  // Strategy 3: Shift swap (if still over after other strategies)
  const hoursSavedFromBehavior = (behaviorMinutes + breakMinutes) / 60;
  if (projectedTotal - hoursSavedFromBehavior >= OVERTIME_THRESHOLD) {
    const swapCandidates = await findShiftSwapCandidates(employeeId, weekStart, weekEnd);

    if (swapCandidates.length > 0) {
      const candidate = swapCandidates[0];
      strategies.push({
        priority: 3,
        type: 'Shift Swap',
        hoursSaved: candidate.shiftHours.toFixed(1),
        description: `Swap your ${formatDate(candidate.shiftDate)} shift (${candidate.shiftHours.toFixed(1)}h) with ${candidate.candidateName}.`,
        swapWith: candidate.candidateName,
      });
    }
  }

  return strategies;
}

/**
 * Find shift swap candidates
 */
async function findShiftSwapCandidates(employeeId, weekStart, weekEnd) {
  const now = new Date();

  // Get employee's remaining shifts
  const employeeShifts = await admin.firestore()
    .collection('shifts')
    .where('employeeId', '==', employeeId)
    .where('startTime', '>=', now)
    .where('startTime', '<=', weekEnd)
    .where('isDayOff', '==', false)
    .get();

  const candidates = [];

  // For each shift, find potential swap candidates
  for (const shiftDoc of employeeShifts.docs) {
    const shift = shiftDoc.data();
    const shiftHours = (shift.endTime.toDate() - shift.startTime.toDate()) / (1000 * 60 * 60);

    // Get all other employees
    const users = await admin.firestore()
      .collection('users')
      .where('role', '==', 'employee')
      .get();

    for (const userDoc of users.docs) {
      if (userDoc.id === employeeId) continue;

      // Calculate if candidate would still be under overtime
      const candidateActual = await calculateActualWeeklyHours(userDoc.id, weekStart, weekEnd);
      const candidateRemaining = await calculateRemainingScheduledHours(userDoc.id, now, weekEnd);
      const candidateTotal = candidateActual + candidateRemaining + shiftHours;

      if (candidateTotal <= OVERTIME_THRESHOLD) {
        candidates.push({
          candidateId: userDoc.id,
          candidateName: userDoc.data().fullName,
          shiftId: shiftDoc.id,
          shiftDate: shift.startTime.toDate(),
          shiftHours,
          candidateCurrentHours: candidateActual + candidateRemaining,
        });
      }
    }
  }

  // Sort by candidates with most capacity
  candidates.sort((a, b) => a.candidateCurrentHours - b.candidateCurrentHours);

  return candidates;
}

/**
 * Send overtime risk email
 */
async function sendOvertimeRiskEmail(analysis) {
  const sendGridApiKey = process.env.SENDGRID_API_KEY;
  const fromEmail = process.env.SENDGRID_FROM_EMAIL || 'noreply@chronoworks.com';
  const fromName = process.env.SENDGRID_FROM_NAME || 'ChronoWorks';

  if (!sendGridApiKey || !fromEmail) {
    console.log('SendGrid not configured, skipping email notification');
    return;
  }

  sgMail.setApiKey(sendGridApiKey);

  // Get manager and admins
  const recipients = await getNotificationRecipients(analysis.employeeId, analysis.managerId);

  // Build email content
  const htmlContent = buildEmailHTML(analysis);

  // Send to employee, manager, and admins
  const allRecipients = [
    analysis.employeeEmail,
    ...recipients.managers.map(m => m.email),
    ...recipients.admins.map(a => a.email),
  ];

  const uniqueRecipients = [...new Set(allRecipients)];

  console.log(`Sending overtime risk email to: ${uniqueRecipients.join(', ')}`);
  console.log(`From: ${fromName} <${fromEmail}>`);

  try {
    await sgMail.send({
      to: uniqueRecipients,
      from: { email: fromEmail, name: fromName },
      subject: `⚠️ Overtime Risk Alert: ${analysis.employeeName} - ${analysis.riskLevel.toUpperCase()} Risk`,
      html: htmlContent,
      text: buildEmailText(analysis),
    });

    console.log(`Email sent successfully`);
  } catch (error) {
    console.error('Error sending email:', error);
    console.error('Error details:', error.response?.body || error.message);
  }
}

/**
 * Send overtime risk SMS notification
 */
async function sendOvertimeRiskSMS(analysis) {
  const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID;
  const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN;
  const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER;

  if (!twilioAccountSid || !twilioAuthToken || !twilioPhoneNumber) {
    console.log('Twilio not configured, skipping SMS notification');
    return;
  }

  const twilioClient = twilio(twilioAccountSid, twilioAuthToken);

  // Get manager and admins with phone numbers
  const recipients = await getNotificationRecipients(analysis.employeeId, analysis.managerId);

  const allRecipients = [
    ...recipients.managers.filter(m => m.phoneNumber),
    ...recipients.admins.filter(a => a.phoneNumber),
  ];

  if (allRecipients.length === 0) {
    console.log('No recipients with phone numbers for SMS');
    return;
  }

  const riskEmoji = {
    critical: '🚨',
    high: '⚠️',
    medium: '⚡',
    low: 'ℹ️',
  }[analysis.riskLevel];

  const message = `${riskEmoji} ChronoWorks Overtime Alert!\n\n` +
    `Employee: ${analysis.employeeName}\n` +
    `Risk: ${analysis.riskLevel.toUpperCase()}\n` +
    `Projected Hours: ${analysis.projectedTotal}h\n` +
    `Potential OT: ${analysis.overtimeHours}h\n\n` +
    `Check ChronoWorks for details.`;

  console.log(`Sending SMS to ${allRecipients.length} recipients`);

  const results = [];
  for (const recipient of allRecipients) {
    try {
      const result = await twilioClient.messages.create({
        body: message,
        to: recipient.phoneNumber,
        from: twilioPhoneNumber,
      });
      console.log(`SMS sent to ${recipient.name} (${recipient.phoneNumber}): ${result.sid}`);
      results.push({
        name: recipient.name,
        phone: recipient.phoneNumber,
        status: 'sent',
        sid: result.sid
      });
    } catch (error) {
      console.error(`Failed to send SMS to ${recipient.name}:`, error.message);
      results.push({
        name: recipient.name,
        phone: recipient.phoneNumber,
        status: 'failed',
        error: error.message
      });
    }
  }

  console.log(`SMS notification complete. Sent: ${results.filter(r => r.status === 'sent').length}, Failed: ${results.filter(r => r.status === 'failed').length}`);
  return results;
}

/**
 * Get notification recipients
 */
async function getNotificationRecipients(employeeId, managerId) {
  const recipients = {
    managers: [],
    admins: [],
  };

  // Get manager
  if (managerId) {
    const managerDoc = await admin.firestore().collection('users').doc(managerId).get();
    if (managerDoc.exists) {
      const managerData = managerDoc.data();
      recipients.managers.push({
        id: managerId,
        name: managerData.fullName,
        email: managerData.email,
        phoneNumber: managerData.phoneNumber,
      });
    }
  }

  // Get all admins
  const admins = await admin.firestore()
    .collection('users')
    .where('role', '==', 'admin')
    .get();

  for (const doc of admins.docs) {
    const adminData = doc.data();
    recipients.admins.push({
      id: doc.id,
      name: adminData.fullName,
      email: adminData.email,
      phoneNumber: adminData.phoneNumber,
    });
  }

  return recipients;
}

/**
 * Build HTML email content
 */
function buildEmailHTML(analysis) {
  const riskColor = {
    critical: '#d9534f',
    high: '#f0ad4e',
    medium: '#5bc0de',
    low: '#5cb85c',
  }[analysis.riskLevel];

  let violationsHTML = '';
  if (analysis.violations.length > 0) {
    violationsHTML = `
      <div style="background-color: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0;">
        <h3 style="margin-top: 0; color: #856404;">⚠️ Time Tracking Issues This Week</h3>
        <ul>
          ${analysis.violations.map(v => `<li>${v.description} on ${v.date}</li>`).join('')}
        </ul>
      </div>
    `;
  }

  let strategiesHTML = '';
  if (analysis.strategies.length > 0) {
    strategiesHTML = `
      <div style="background-color: #d1ecf1; padding: 20px; border-radius: 5px; margin: 20px 0;">
        <h3 style="margin-top: 0; color: #0c5460;">💡 Recommended Actions to Avoid Overtime</h3>
        ${analysis.strategies.map((s, i) => `
          <div style="background-color: white; padding: 15px; margin: 10px 0; border-radius: 5px;">
            <h4 style="margin-top: 0; color: #0c5460;">${i + 1}. ${s.type} (Save ${s.hoursSaved}h)</h4>
            <p>${s.description}</p>
          </div>
        `).join('')}
      </div>
    `;
  }

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: ${riskColor}; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
        .content { background-color: #f9f9f9; padding: 20px; }
        .stats { background-color: white; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .stat-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #eee; }
        .stat-label { font-weight: bold; }
        .footer { text-align: center; color: #666; font-size: 12px; margin-top: 20px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>⚠️ Overtime Risk Alert</h1>
          <h2>${analysis.riskLevel.toUpperCase()} RISK</h2>
        </div>
        <div class="content">
          <h3>Employee: ${analysis.employeeName}</h3>
          <p><strong>Week:</strong> ${formatDate(new Date(analysis.weekStart))} - ${formatDate(new Date(analysis.weekEnd))}</p>

          <div class="stats">
            <h3>Hours Summary</h3>
            <div class="stat-row">
              <span class="stat-label">Actual Hours Worked:</span>
              <span>${analysis.actualHours}h</span>
            </div>
            <div class="stat-row">
              <span class="stat-label">Current Shift (if active):</span>
              <span>${analysis.currentShiftHours}h</span>
            </div>
            <div class="stat-row">
              <span class="stat-label">Remaining Scheduled:</span>
              <span>${analysis.remainingScheduled}h</span>
            </div>
            <div class="stat-row">
              <span class="stat-label">Projected Total:</span>
              <span><strong>${analysis.projectedTotal}h</strong></span>
            </div>
            <div class="stat-row">
              <span class="stat-label">Potential Overtime:</span>
              <span style="color: ${riskColor};"><strong>${analysis.overtimeHours}h</strong></span>
            </div>
          </div>

          ${violationsHTML}
          ${strategiesHTML}

          <div style="background-color: #e7f3fe; padding: 15px; border-left: 4px solid #2196F3; margin: 20px 0;">
            <h4 style="margin-top: 0;">What to Do Now</h4>
            <ul>
              <li><strong>Employee:</strong> Review the recommended actions above and adjust your schedule accordingly</li>
              <li><strong>Manager:</strong> Discuss these strategies with the employee and help coordinate any shift swaps if needed</li>
              <li><strong>Admin:</strong> Monitor the situation and approve any necessary schedule changes</li>
            </ul>
          </div>
        </div>
        <div class="footer">
          <p>This is an automated message from ChronoWorks Time Tracking System</p>
          <p>Overtime threshold: 40 hours per week</p>
        </div>
      </div>
    </body>
    </html>
  `;
}

/**
 * Build plain text email content
 */
function buildEmailText(analysis) {
  let text = `
OVERTIME RISK ALERT - ${analysis.riskLevel.toUpperCase()} RISK

Employee: ${analysis.employeeName}
Week: ${formatDate(new Date(analysis.weekStart))} - ${formatDate(new Date(analysis.weekEnd))}

HOURS SUMMARY:
- Actual Hours Worked: ${analysis.actualHours}h
- Current Shift (if active): ${analysis.currentShiftHours}h
- Remaining Scheduled: ${analysis.remainingScheduled}h
- Projected Total: ${analysis.projectedTotal}h
- Potential Overtime: ${analysis.overtimeHours}h

`;

  if (analysis.violations.length > 0) {
    text += `\nTIME TRACKING ISSUES:\n`;
    analysis.violations.forEach(v => {
      text += `- ${v.description} on ${v.date}\n`;
    });
  }

  if (analysis.strategies.length > 0) {
    text += `\nRECOMMENDED ACTIONS:\n`;
    analysis.strategies.forEach((s, i) => {
      text += `${i + 1}. ${s.type} (Save ${s.hoursSaved}h)\n   ${s.description}\n\n`;
    });
  }

  return text;
}

/**
 * Check if we've already notified today
 */
async function checkIfNotifiedToday(employeeId) {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  const notifications = await admin.firestore()
    .collection('overtimeRiskNotifications')
    .where('employeeId', '==', employeeId)
    .where('date', '>=', admin.firestore.Timestamp.fromDate(todayStart))
    .limit(1)
    .get();

  return !notifications.empty;
}

/**
 * Record that we've sent a notification with complete risk data
 * Updates existing record if one exists for today, otherwise creates new
 */
async function recordNotification(employeeId, notificationData = {}) {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  // Check if notification already exists for today
  const existing = await admin.firestore()
    .collection('overtimeRiskNotifications')
    .where('employeeId', '==', employeeId)
    .where('date', '>=', admin.firestore.Timestamp.fromDate(todayStart))
    .limit(1)
    .get();

  const notificationRecord = {
    employeeId,
    employeeName: notificationData.employeeName || 'Unknown',
    riskLevel: notificationData.riskLevel || 'unknown',
    projectedHours: parseFloat(notificationData.projectedTotal || 0),
    overtimeHours: parseFloat(notificationData.overtimeHours || 0),
    date: admin.firestore.Timestamp.fromDate(todayStart),
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (!existing.empty) {
    // Update existing record for today
    const docId = existing.docs[0].id;
    await admin.firestore()
      .collection('overtimeRiskNotifications')
      .doc(docId)
      .update(notificationRecord);
  } else {
    // Create new record for today
    await admin.firestore()
      .collection('overtimeRiskNotifications')
      .add({
        ...notificationRecord,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  }
}

/**
 * Get week start (Sunday)
 */
function getWeekStart(date) {
  const d = new Date(date);
  const day = d.getDay();
  const diff = d.getDate() - day;
  return new Date(d.setDate(diff));
}

/**
 * Get week end (Saturday)
 */
function getWeekEnd(date) {
  const weekStart = getWeekStart(date);
  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekEnd.getDate() + 6);
  weekEnd.setHours(23, 59, 59, 999);
  return weekEnd;
}

/**
 * Format date for display
 */
function formatDate(date) {
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(date);
}
