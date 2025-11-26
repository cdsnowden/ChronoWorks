const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const sgMail = require("@sendgrid/mail");

/**
 * Helper function to get all admin users with email addresses
 */
async function getAdminEmails() {
  try {
    const adminsSnapshot = await admin.firestore()
        .collection("users")
        .where("role", "==", "admin")
        .where("isActive", "==", true)
        .get();

    const adminEmails = [];
    adminsSnapshot.forEach((doc) => {
      const user = doc.data();
      if (user.email && user.email.trim() !== "") {
        adminEmails.push({
          email: user.email,
          name: `${user.firstName} ${user.lastName}`,
        });
      }
    });

    return adminEmails;
  } catch (error) {
    logger.error("Error fetching admin emails:", error);
    return [];
  }
}

/**
 * Helper function to get manager email by managerId
 */
async function getManagerEmail(managerId) {
  try {
    if (!managerId) return null;

    const managerDoc = await admin.firestore()
        .collection("users")
        .doc(managerId)
        .get();

    if (!managerDoc.exists) return null;

    const manager = managerDoc.data();
    if (manager.email && manager.email.trim() !== "") {
      return {
        email: manager.email,
        name: `${manager.firstName} ${manager.lastName}`,
      };
    }

    return null;
  } catch (error) {
    logger.error(`Error fetching manager email for ${managerId}:`, error);
    return null;
  }
}

/**
 * Helper function to get employee's shift for today
 */
async function getTodayShift(employeeId) {
  try {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

    const shiftsSnapshot = await admin.firestore()
        .collection("shifts")
        .where("employeeId", "==", employeeId)
        .where("startTime", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
        .where("startTime", "<=", admin.firestore.Timestamp.fromDate(endOfDay))
        .where("isDayOff", "==", false)
        .limit(1)
        .get();

    if (shiftsSnapshot.empty) return null;

    const shiftDoc = shiftsSnapshot.docs[0];
    const shift = shiftDoc.data();

    return {
      id: shiftDoc.id,
      startTime: shift.startTime.toDate(),
      endTime: shift.endTime.toDate(),
    };
  } catch (error) {
    logger.error(`Error fetching shift for employee ${employeeId}:`, error);
    return null;
  }
}

/**
 * Helper function to check if warning already sent
 */
async function hasWarningBeenSent(userId, date) {
  try {
    const dateString = date.toISOString().split("T")[0]; // YYYY-MM-DD format

    const warningSnapshot = await admin.firestore()
        .collection("missedClockOutWarnings")
        .where("userId", "==", userId)
        .where("date", "==", dateString)
        .limit(1)
        .get();

    return !warningSnapshot.empty;
  } catch (error) {
    logger.error(`Error checking warning for user ${userId}:`, error);
    return false;
  }
}

/**
 * Helper function to record warning sent
 */
async function recordWarningSent(userId, employeeName, shiftEndTime, clockInTime, currentTime) {
  try {
    const dateString = currentTime.toISOString().split("T")[0]; // YYYY-MM-DD format

    await admin.firestore()
        .collection("missedClockOutWarnings")
        .add({
          userId: userId,
          employeeName: employeeName,
          date: dateString,
          shiftEndTime: admin.firestore.Timestamp.fromDate(shiftEndTime),
          clockInTime: admin.firestore.Timestamp.fromDate(clockInTime),
          warningSentAt: admin.firestore.FieldValue.serverTimestamp(),
          minutesOverdue: Math.floor((currentTime - shiftEndTime) / 1000 / 60),
        });

    logger.info(`Recorded warning for ${employeeName} (${userId}) on ${dateString}`);
  } catch (error) {
    logger.error(`Error recording warning for user ${userId}:`, error);
  }
}

/**
 * Helper function to format time for email
 */
function formatTime(date) {
  let hours = date.getHours();
  const minutes = date.getMinutes().toString().padStart(2, "0");
  const ampm = hours >= 12 ? "PM" : "AM";
  hours = hours % 12;
  hours = hours ? hours : 12; // 0 should be 12
  return `${hours}:${minutes} ${ampm}`;
}

/**
 * Helper function to format duration
 */
function formatDuration(minutes) {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  if (hours === 0) return `${mins} minutes`;
  if (mins === 0) return `${hours} hour${hours > 1 ? "s" : ""}`;
  return `${hours} hour${hours > 1 ? "s" : ""} and ${mins} minute${mins > 1 ? "s" : ""}`;
}

/**
 * Helper function to send email via SendGrid
 */
async function sendMissedClockOutEmail(recipients, employeeName, shiftTime, clockInTime, duration) {
  try {
    const sendgridApiKey = process.env.SENDGRID_API_KEY;

    if (!sendgridApiKey) {
      logger.error("SendGrid API key not configured");
      return {success: false, error: "SendGrid API key not configured"};
    }

    sgMail.setApiKey(sendgridApiKey);

    const emailContent = {
      subject: `ChronoWorks Alert: Missed Clock-Out - ${employeeName}`,
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #2563eb; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background-color: #f9fafb; padding: 30px; border: 1px solid #e5e7eb; }
            .alert-box { background-color: #fef2f2; border-left: 4px solid #ef4444; padding: 15px; margin: 20px 0; }
            .info-table { width: 100%; margin: 20px 0; }
            .info-table td { padding: 10px; border-bottom: 1px solid #e5e7eb; }
            .info-table td:first-child { font-weight: bold; width: 40%; }
            .cta-button { display: inline-block; background-color: #2563eb; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .footer { text-align: center; color: #6b7280; font-size: 12px; margin-top: 20px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1 style="margin: 0;">⚠️ Missed Clock-Out Alert</h1>
            </div>
            <div class="content">
              <div class="alert-box">
                <strong>Action Required:</strong> An employee has failed to clock out 45 minutes after their shift ended.
              </div>

              <h2>Employee Details</h2>
              <table class="info-table">
                <tr>
                  <td>Employee Name:</td>
                  <td><strong>${employeeName}</strong></td>
                </tr>
                <tr>
                  <td>Scheduled Shift:</td>
                  <td>${shiftTime}</td>
                </tr>
                <tr>
                  <td>Clock In Time:</td>
                  <td>${clockInTime}</td>
                </tr>
                <tr>
                  <td>Time Clocked In:</td>
                  <td><strong style="color: #ef4444;">${duration}</strong></td>
                </tr>
              </table>

              <p style="font-size: 16px; margin: 20px 0;">
                <strong>Please take action:</strong>
              </p>
              <ul>
                <li>Contact the employee immediately to remind them to clock out</li>
                <li>Verify if the employee is still working or forgot to clock out</li>
                <li>Review time entries for accuracy and make manual adjustments if needed</li>
              </ul>

              <div style="text-align: center;">
                <a href="https://chronoworks.app" class="cta-button">Open ChronoWorks Dashboard</a>
              </div>
            </div>
            <div class="footer">
              <p>This is an automated alert from ChronoWorks Time Tracking System</p>
              <p>To manage notification preferences, please contact your system administrator</p>
            </div>
          </div>
        </body>
        </html>
      `,
      text: `
ChronoWorks Alert: Missed Clock-Out

Employee: ${employeeName}
Scheduled Shift: ${shiftTime}
Clock In Time: ${clockInTime}
Time Clocked In: ${duration}

Action Required:
The employee has failed to clock out 45 minutes after their shift ended. Please contact them immediately to remind them to clock out and verify their status.

Open ChronoWorks: https://chronoworks.app
      `.trim(),
    };

    const messages = recipients.map((recipient) => ({
      to: recipient.email,
      from: process.env.SENDGRID_FROM_EMAIL || "noreply@chronoworks.app",
      subject: emailContent.subject,
      text: emailContent.text,
      html: emailContent.html,
    }));

    await sgMail.send(messages);

    logger.info(`Sent ${messages.length} missed clock-out emails for ${employeeName}`);
    return {success: true, count: messages.length};
  } catch (error) {
    logger.error("Error sending email via SendGrid:", error);
    return {success: false, error: error.message};
  }
}

/**
 * Scheduled Cloud Function that checks for missed clock-outs
 * Runs every 15 minutes
 */
exports.checkMissedClockOuts = onSchedule(
    {
      schedule: "every 15 minutes",
      timeZone: "America/New_York", // Adjust to your timezone
      region: "us-central1",
    },
    async (event) => {
      try {
        logger.info("Starting missed clock-out check...");

        const now = new Date();
        const graceMinutes = 45; // 45 minutes after shift end

        // Get all active clock-ins
        const activeClockInsSnapshot = await admin.firestore()
            .collection("activeClockIns")
            .get();

        if (activeClockInsSnapshot.empty) {
          logger.info("No active clock-ins found");
          return {success: true, message: "No active clock-ins"};
        }

        logger.info(`Found ${activeClockInsSnapshot.size} active clock-ins to check`);

        const warnings = [];

        // Check each active clock-in
        for (const activeDoc of activeClockInsSnapshot.docs) {
          try {
            const activeData = activeDoc.data();
            const userId = activeData.userId;
            const clockInTime = activeData.clockInTime.toDate();

            logger.info(`Checking user ${userId}...`);

            // Get employee details
            const userDoc = await admin.firestore()
                .collection("users")
                .doc(userId)
                .get();

            if (!userDoc.exists) {
              logger.warn(`User ${userId} not found, skipping`);
              continue;
            }

            const user = userDoc.data();
            const employeeName = `${user.firstName} ${user.lastName}`;

            // Get today's shift for this employee
            const shift = await getTodayShift(userId);

            if (!shift) {
              logger.info(`No shift found for ${employeeName} (${userId}), skipping`);
              continue;
            }

            // Calculate time since shift ended
            const minutesSinceShiftEnd = Math.floor((now - shift.endTime) / 1000 / 60);

            logger.info(`Shift ended ${minutesSinceShiftEnd} minutes ago for ${employeeName}`);

            // Check if they've exceeded the grace period
            if (minutesSinceShiftEnd > graceMinutes) {
              // Check if warning already sent today
              const alreadySent = await hasWarningBeenSent(userId, now);

              if (alreadySent) {
                logger.info(`Warning already sent for ${employeeName} today, skipping`);
                continue;
              }

              logger.warn(`${employeeName} has exceeded clock-out grace period by ${minutesSinceShiftEnd - graceMinutes} minutes`);

              // Get recipients for email
              const recipients = [];

              // Add employee
              if (user.email && user.email.trim() !== "") {
                recipients.push({
                  email: user.email,
                  name: employeeName,
                });
              }

              // Add manager if exists
              if (user.managerId) {
                const manager = await getManagerEmail(user.managerId);
                if (manager) {
                  recipients.push(manager);
                }
              }

              // Add all admins
              const admins = await getAdminEmails();
              recipients.push(...admins);

              // Remove duplicates based on email
              const uniqueRecipients = Array.from(
                  new Map(recipients.map((r) => [r.email, r])).values()
              );

              if (uniqueRecipients.length === 0) {
                logger.warn(`No recipients found for ${employeeName}, skipping email`);
                continue;
              }

              // Format data for email
              const shiftTime = `${formatTime(shift.startTime)} - ${formatTime(shift.endTime)}`;
              const clockInTimeStr = formatTime(clockInTime);
              const minutesClockedIn = Math.floor((now - clockInTime) / 1000 / 60);
              const duration = formatDuration(minutesClockedIn);

              // Send email
              const emailResult = await sendMissedClockOutEmail(
                  uniqueRecipients,
                  employeeName,
                  shiftTime,
                  clockInTimeStr,
                  duration
              );

              if (emailResult.success) {
                // Record warning sent
                await recordWarningSent(userId, employeeName, shift.endTime, clockInTime, now);

                warnings.push({
                  userId: userId,
                  employeeName: employeeName,
                  emailsSent: emailResult.count,
                  minutesOverdue: minutesSinceShiftEnd - graceMinutes,
                });
              } else {
                logger.error(`Failed to send email for ${employeeName}: ${emailResult.error}`);
              }
            } else {
              logger.info(`${employeeName} is within grace period (${graceMinutes - minutesSinceShiftEnd} minutes remaining)`);
            }
          } catch (error) {
            logger.error(`Error processing active clock-in ${activeDoc.id}:`, error);
            // Continue with next record
          }
        }

        const summary = {
          success: true,
          timestamp: now.toISOString(),
          activeClockIns: activeClockInsSnapshot.size,
          warningsSent: warnings.length,
          warnings: warnings,
        };

        logger.info(`Missed clock-out check complete: ${warnings.length} warnings sent`);
        return summary;
      } catch (error) {
        logger.error("Error in checkMissedClockOuts:", error);
        throw error;
      }
    }
);
