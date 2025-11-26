const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const {
  sendTimeOffApprovedEmail,
  sendTimeOffDeniedEmail,
  sendTimeOffRequestSubmittedEmail,
} = require("./emailService");

/**
 * Trigger when a new time-off request is created
 * Sends email notification to managers and admins
 */
exports.onTimeOffRequestCreated = onDocumentCreated(
    {
      document: "timeOffRequests/{requestId}",
      region: "us-central1",
    },
    async (event) => {
      try {
        const timeOffRequest = event.data.data();
        const requestId = event.params.requestId;

        logger.info(`Processing new time-off request: ${requestId}`);

        // Get employee information
        const employeeDoc = await admin.firestore()
            .collection("users")
            .doc(timeOffRequest.employeeId)
            .get();

        if (!employeeDoc.exists) {
          logger.error(`Employee not found: ${timeOffRequest.employeeId}`);
          return;
        }

        const employee = employeeDoc.data();
        const employeeName = `${employee.firstName} ${employee.lastName}`;

        // Get company information
        const companyDoc = await admin.firestore()
            .collection("companies")
            .doc(timeOffRequest.companyId)
            .get();

        if (!companyDoc.exists) {
          logger.error(`Company not found: ${timeOffRequest.companyId}`);
          return;
        }

        const company = companyDoc.data();

        // Check for conflicting time-off requests
        const conflictsSnapshot = await admin.firestore()
            .collection("timeOffRequests")
            .where("companyId", "==", timeOffRequest.companyId)
            .where("status", "in", ["pending", "approved"])
            .get();

        let conflictCount = 0;
        conflictsSnapshot.forEach((doc) => {
          const otherRequest = doc.data();
          // Skip the current request
          if (doc.id === requestId) return;
          // Skip requests from the same employee
          if (otherRequest.employeeId === timeOffRequest.employeeId) return;

          // Check for date overlap
          const startDate = timeOffRequest.startDate.toDate();
          const endDate = timeOffRequest.endDate.toDate();
          const otherStartDate = otherRequest.startDate.toDate();
          const otherEndDate = otherRequest.endDate.toDate();

          const hasOverlap = (startDate <= otherEndDate && endDate >= otherStartDate);

          if (hasOverlap) {
            conflictCount++;
          }
        });

        // Get all managers and admins for the company
        const managersSnapshot = await admin.firestore()
            .collection("users")
            .where("companyId", "==", timeOffRequest.companyId)
            .where("role", "in", ["admin", "manager"])
            .get();

        // Format dates for email
        const startDate = timeOffRequest.startDate.toDate().toLocaleDateString("en-US");
        const endDate = timeOffRequest.endDate.toDate().toLocaleDateString("en-US");

        // Calculate days requested
        const start = timeOffRequest.startDate.toDate();
        const end = timeOffRequest.endDate.toDate();
        const daysRequested = Math.ceil((end - start) / (1000 * 60 * 60 * 24)) + 1;

        // Send email to each manager/admin
        const emailPromises = [];
        managersSnapshot.forEach((doc) => {
          const manager = doc.data();
          const managerName = `${manager.firstName} ${manager.lastName}`;

          emailPromises.push(
              sendTimeOffRequestSubmittedEmail({
                managerName: managerName,
                managerEmail: manager.email,
                employeeName: employeeName,
                companyName: company.name,
                startDate: startDate,
                endDate: endDate,
                type: timeOffRequest.type,
                reason: timeOffRequest.reason || "",
                daysRequested: daysRequested,
                hasConflicts: conflictCount > 0,
                conflictCount: conflictCount,
                appUrl: "https://chronoworks-dcfd6.web.app",
              }),
          );
        });

        await Promise.all(emailPromises);
        logger.info(`Sent ${emailPromises.length} time-off request notifications`);
      } catch (error) {
        logger.error("Error processing time-off request:", error);
      }
    },
);

/**
 * Trigger when a time-off request is updated
 * Sends email notification when status changes to approved or denied
 */
exports.onTimeOffRequestUpdated = onDocumentUpdated(
    {
      document: "timeOffRequests/{requestId}",
      region: "us-central1",
    },
    async (event) => {
      try {
        const beforeData = event.data.before.data();
        const afterData = event.data.after.data();
        const requestId = event.params.requestId;

        // Check if status changed
        if (beforeData.status === afterData.status) {
          logger.info(`Time-off request ${requestId} updated but status unchanged`);
          return;
        }

        // Only send emails for approved or denied status changes
        if (afterData.status !== "approved" && afterData.status !== "denied") {
          logger.info(`Time-off request ${requestId} status changed to ${afterData.status}, no email needed`);
          return;
        }

        logger.info(`Processing time-off status change to ${afterData.status}: ${requestId}`);

        // Get employee information
        const employeeDoc = await admin.firestore()
            .collection("users")
            .doc(afterData.employeeId)
            .get();

        if (!employeeDoc.exists) {
          logger.error(`Employee not found: ${afterData.employeeId}`);
          return;
        }

        const employee = employeeDoc.data();
        const employeeName = `${employee.firstName} ${employee.lastName}`;

        // Get company information
        const companyDoc = await admin.firestore()
            .collection("companies")
            .doc(afterData.companyId)
            .get();

        if (!companyDoc.exists) {
          logger.error(`Company not found: ${afterData.companyId}`);
          return;
        }

        const company = companyDoc.data();

        // Get reviewer information
        const reviewerDoc = await admin.firestore()
            .collection("users")
            .doc(afterData.reviewerId)
            .get();

        if (!reviewerDoc.exists) {
          logger.error(`Reviewer not found: ${afterData.reviewerId}`);
          return;
        }

        const reviewer = reviewerDoc.data();
        const reviewerName = `${reviewer.firstName} ${reviewer.lastName}`;

        // Format dates for email
        const startDate = afterData.startDate.toDate().toLocaleDateString("en-US");
        const endDate = afterData.endDate.toDate().toLocaleDateString("en-US");

        // Send appropriate email based on status
        if (afterData.status === "approved") {
          await sendTimeOffApprovedEmail({
            employeeName: employeeName,
            employeeEmail: employee.email,
            companyName: company.name,
            startDate: startDate,
            endDate: endDate,
            type: afterData.type,
            reviewerName: reviewerName,
            reviewNotes: afterData.reviewNotes || "",
            appUrl: "https://chronoworks-dcfd6.web.app",
          });
          logger.info(`Sent time-off approved email to ${employee.email}`);
        } else if (afterData.status === "denied") {
          await sendTimeOffDeniedEmail({
            employeeName: employeeName,
            employeeEmail: employee.email,
            companyName: company.name,
            startDate: startDate,
            endDate: endDate,
            type: afterData.type,
            reviewerName: reviewerName,
            reviewNotes: afterData.reviewNotes || "",
            appUrl: "https://chronoworks-dcfd6.web.app",
          });
          logger.info(`Sent time-off denied email to ${employee.email}`);
        }
      } catch (error) {
        logger.error("Error processing time-off request update:", error);
      }
    },
);
