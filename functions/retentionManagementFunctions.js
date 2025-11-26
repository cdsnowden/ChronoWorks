/**
 * Retention Management Functions for ChronoWorks Phase 3B
 * Handles at-risk account detection, task creation, and account manager notifications
 */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest, onCall} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const {
  sendManagerUrgentTaskEmail,
  sendManagerDailyDigestEmail,
  sendManagerOverdueTaskEmail,
} = require("./emailService");

/**
 * Scheduled Function: Detects at-risk accounts and creates retention tasks
 * Runs daily at 8 AM ET (before manager start of day)
 */
const detectAtRiskAccounts = onSchedule(
    {
      schedule: "0 8 * * *", // Every day at 8 AM
      timeZone: "America/New_York",
      region: "us-central1",
    },
    async (event) => {
      try {
        logger.info("=== Starting At-Risk Account Detection ===");

        const now = admin.firestore.Timestamp.now();
        const today = new Date(now.toMillis());

        let tasksCreated = 0;

        // ==========================================
        // 1. Trial accounts expiring in 2 days (Day 29)
        // ==========================================

        const twoDaysFromNow = new Date(today);
        twoDaysFromNow.setDate(today.getDate() + 2);
        const twoDaysStart = new Date(twoDaysFromNow.setHours(0, 0, 0, 0));

        const expiringTrials = await admin.firestore()
            .collection("companies")
            .where("currentPlan", "==", "trial")
            .where("status", "==", "active")
            .get();

        for (const doc of expiringTrials.docs) {
          const company = doc.data();
          const trialEndDate = company.trialEndDate.toDate();
          const trialEndStart = new Date(trialEndDate.setHours(0, 0, 0, 0));

          if (trialEndStart.getTime() === twoDaysStart.getTime()) {
            // Check if task already exists
            const existingTask = await admin.firestore()
                .collection("retentionTasks")
                .where("companyId", "==", doc.id)
                .where("riskType", "==", "trial_expiring")
                .where("status", "in", ["pending", "assigned", "contacted"])
                .get();

            if (existingTask.empty) {
              const taskData = await createRetentionTask({
                companyId: doc.id,
                company,
                riskType: "trial_expiring",
                riskLevel: "critical",
                riskReason: "Trial expires in 2 days without conversion",
                expirationDate: company.trialEndDate,
                priority: 1,
                dueDate: today, // Due today
              });

              await notifyManagerOfNewTask(taskData);
              tasksCreated++;
              logger.info(`Created trial retention task for ${company.businessName}`);
            }
          }
        }

        // ==========================================
        // 2. Free accounts expiring in 3 days (already detected)
        // Task created immediately when warning is sent
        // ==========================================

        const threeDaysFromNow = new Date(today);
        threeDaysFromNow.setDate(today.getDate() + 3);
        const threeDaysStart = new Date(threeDaysFromNow.setHours(0, 0, 0, 0));

        const expiringFree = await admin.firestore()
            .collection("companies")
            .where("currentPlan", "==", "free")
            .where("status", "==", "active")
            .get();

        for (const doc of expiringFree.docs) {
          const company = doc.data();

          if (!company.freeEndDate) continue;

          const freeEndDate = company.freeEndDate.toDate();
          const freeEndStart = new Date(freeEndDate.setHours(0, 0, 0, 0));

          if (freeEndStart.getTime() === threeDaysStart.getTime()) {
            // Check if task already exists
            const existingTask = await admin.firestore()
                .collection("retentionTasks")
                .where("companyId", "==", doc.id)
                .where("riskType", "==", "free_expiring")
                .where("status", "in", ["pending", "assigned", "contacted"])
                .get();

            if (existingTask.empty) {
              const taskData = await createRetentionTask({
                companyId: doc.id,
                company,
                riskType: "free_expiring",
                riskLevel: "urgent",
                riskReason: "Free account expires in 3 days - account will be locked",
                expirationDate: company.freeEndDate,
                priority: 1,
                dueDate: today, // Due today
              });

              await notifyManagerOfNewTask(taskData);
              tasksCreated++;
              logger.info(`Created free account retention task for ${company.businessName}`);
            }
          }
        }

        // ==========================================
        // 3. Check for overdue tasks
        // ==========================================

        const overdueTasks = await admin.firestore()
            .collection("retentionTasks")
            .where("status", "in", ["pending", "assigned"])
            .where("dueDate", "<", admin.firestore.Timestamp.fromDate(today))
            .get();

        for (const doc of overdueTasks.docs) {
          const task = doc.data();

          // Check if overdue alert already sent today
          const lastAlert = task.lastOverdueAlert?.toDate();
          const isSameDay = lastAlert &&
            lastAlert.toDateString() === today.toDateString();

          if (!isSameDay) {
            await doc.ref.update({
              lastOverdueAlert: admin.firestore.FieldValue.serverTimestamp(),
            });

            await sendManagerOverdueTaskEmail({
              managerEmail: task.assignedToEmail || process.env.SENDGRID_ADMIN_EMAIL,
              managerName: task.assignedToName || "Account Manager",
              companyName: task.companyName,
              ownerName: task.ownerName,
              ownerPhone: task.ownerPhone,
              riskReason: task.riskReason,
              createdDate: task.createdAt.toDate(),
              daysOverdue: Math.floor((today - task.dueDate.toDate()) / (1000 * 60 * 60 * 24)),
              taskId: doc.id,
            });

            logger.info(`Sent overdue alert for task ${doc.id}`);
          }
        }

        logger.info(`At-Risk Detection Complete: ${tasksCreated} new tasks created`);
        logger.info(`Overdue alerts sent: ${overdueTasks.size - overdueTasks.docs.filter((d) => {
          const lastAlert = d.data().lastOverdueAlert?.toDate();
          return lastAlert && lastAlert.toDateString() === today.toDateString();
        }).length}`);

        return {
          success: true,
          tasksCreated,
          overdueAlertsSent: overdueTasks.size,
        };
      } catch (error) {
        logger.error("Error in detectAtRiskAccounts:", error);
        return {success: false, error: error.message};
      }
    }
);

/**
 * Scheduled Function: Sends daily digest to account managers
 * Runs daily at 8:30 AM ET (after detection runs)
 */
const notifyAccountManagers = onSchedule(
    {
      schedule: "30 8 * * *", // Every day at 8:30 AM
      timeZone: "America/New_York",
      region: "us-central1",
    },
    async (event) => {
      try {
        logger.info("=== Starting Account Manager Notifications ===");

        // Get all account managers
        const managersSnapshot = await admin.firestore()
            .collection("users")
            .where("role", "in", ["admin", "account_manager"])
            .get();

        if (managersSnapshot.empty) {
          logger.warn("No account managers found");
          return {success: false, message: "No account managers"};
        }

        let digestsSent = 0;

        for (const managerDoc of managersSnapshot.docs) {
          const manager = managerDoc.data();

          // Get manager's tasks
          const tasksSnapshot = await admin.firestore()
              .collection("retentionTasks")
              .where("assignedTo", "==", managerDoc.id)
              .where("status", "in", ["pending", "assigned", "contacted"])
              .get();

          if (tasksSnapshot.empty) {
            logger.info(`No tasks for ${manager.firstName} ${manager.lastName}`);
            continue;
          }

          const tasks = tasksSnapshot.docs.map((doc) => ({
            id: doc.id,
            ...doc.data(),
          }));

          // Categorize tasks
          const urgent = tasks.filter((t) => t.priority === 1);
          const today = new Date();
          today.setHours(0, 0, 0, 0);
          const todayTasks = tasks.filter((t) => {
            const due = t.dueDate.toDate();
            due.setHours(0, 0, 0, 0);
            return due.getTime() === today.getTime();
          });
          const overdue = tasks.filter((t) => t.dueDate.toDate() < today);
          const followUps = tasks.filter((t) => t.status === "contacted");

          // Calculate total at-risk value
          const totalValue = tasks.reduce((sum, t) => sum + (t.planValue || 0), 0);

          // Calculate manager's save rate
          const resolvedTasks = await admin.firestore()
              .collection("retentionTasks")
              .where("assignedTo", "==", managerDoc.id)
              .where("status", "==", "resolved")
              .where("resolvedAt", ">", admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)))
              .get();

          const saved = resolvedTasks.docs.filter((d) => d.data().outcome === "saved" || d.data().outcome === "converted_to_paid").length;
          const saveRate = resolvedTasks.size > 0 ? Math.round((saved / resolvedTasks.size) * 100) : 0;

          // Send daily digest
          await sendManagerDailyDigestEmail({
            managerEmail: manager.email,
            managerName: `${manager.firstName} ${manager.lastName}`,
            urgent: urgent.slice(0, 3), // Top 3 urgent
            todayTasks: todayTasks.slice(0, 3),
            overdue: overdue.slice(0, 3),
            followUps: followUps.slice(0, 3),
            totalAtRiskValue: totalValue,
            saveRate,
          });

          digestsSent++;
          logger.info(`Sent daily digest to ${manager.email}`);
        }

        logger.info(`Daily digests sent: ${digestsSent}`);

        return {
          success: true,
          digestsSent,
        };
      } catch (error) {
        logger.error("Error in notifyAccountManagers:", error);
        return {success: false, error: error.message};
      }
    }
);

/**
 * Helper: Creates a retention task in Firestore
 */
async function createRetentionTask({companyId, company, riskType, riskLevel, riskReason, expirationDate, priority, dueDate}) {
  // Get suggested plan value
  const planValue = getSuggestedPlanValue(company);

  // Assign to default account manager (or round-robin in future)
  const assignedManager = await getAvailableAccountManager();

  const taskData = {
    companyId,
    companyName: company.businessName,
    ownerName: company.ownerName,
    ownerEmail: company.ownerEmail,
    ownerPhone: company.ownerPhone || "",

    riskType,
    riskLevel,
    riskReason,
    expirationDate,

    currentPlan: company.currentPlan,
    planValue,

    status: "pending",
    priority,
    assignedTo: assignedManager?.id || null,
    assignedToName: assignedManager?.name || null,
    assignedToEmail: assignedManager?.email || null,
    dueDate: admin.firestore.Timestamp.fromDate(dueDate),

    contactAttempts: 0,
    notes: [],

    outcome: null,
    resolvedAt: null,
    resolvedBy: null,
    resolutionNotes: null,

    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),

    // Analytics fields
    daysAsCustomer: company.trialStartDate ? Math.floor((Date.now() - company.trialStartDate.toMillis()) / (1000 * 60 * 60 * 24)) : 0,
  };

  const docRef = await admin.firestore()
      .collection("retentionTasks")
      .add(taskData);

  return {id: docRef.id, ...taskData};
}

/**
 * Helper: Notifies account manager of new urgent task
 */
async function notifyManagerOfNewTask(taskData) {
  if (!taskData.assignedToEmail) {
    logger.warn(`No manager assigned for task ${taskData.id}`);
    return;
  }

  if (taskData.priority === 1) {
    // Urgent tasks get immediate email
    await sendManagerUrgentTaskEmail({
      managerEmail: taskData.assignedToEmail,
      managerName: taskData.assignedToName || "Account Manager",
      companyName: taskData.companyName,
      ownerName: taskData.ownerName,
      ownerPhone: taskData.ownerPhone,
      ownerEmail: taskData.ownerEmail,
      riskReason: taskData.riskReason,
      planValue: taskData.planValue,
      expirationDate: taskData.expirationDate.toDate(),
      taskId: taskData.id,
    });
  }

  // Create in-app notification
  await admin.firestore().collection("managerNotifications").add({
    managerId: taskData.assignedTo,
    managerEmail: taskData.assignedToEmail,
    notificationType: "new_retention_task",
    taskId: taskData.id,
    companyName: taskData.companyName,
    priority: taskData.priority,
    read: false,
    actionTaken: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Helper: Gets suggested plan value based on company size
 */
function getSuggestedPlanValue(company) {
  const employees = company.numberOfEmployees || 10;

  // Suggest plan based on employee count
  if (employees >= 100) return 499; // Platinum
  if (employees >= 50) return 349; // Gold
  if (employees >= 25) return 249; // Silver
  if (employees >= 10) return 149; // Bronze
  return 99; // Starter
}

/**
 * Helper: Gets available account manager (round-robin or least loaded)
 */
async function getAvailableAccountManager() {
  const managersSnapshot = await admin.firestore()
      .collection("users")
      .where("role", "in", ["admin", "account_manager"])
      .get();

  if (managersSnapshot.empty) {
    return null;
  }

  // For now, assign to first admin
  // TODO: Implement round-robin or load-based assignment
  const manager = managersSnapshot.docs[0].data();
  return {
    id: managersSnapshot.docs[0].id,
    name: `${manager.firstName} ${manager.lastName}`,
    email: manager.email,
  };
}

/**
 * HTTP Callable: Updates retention task with contact notes
 */
const updateRetentionTask = onCall(
    {
      region: "us-central1",
    },
    async (request) => {
      try {
        const {taskId, status, outcome, note, callDuration, callOutcome} = request.data;
        const userId = request.auth?.uid;

        if (!userId) {
          throw new Error("Unauthorized");
        }

        // Get user info
        const userDoc = await admin.firestore().collection("users").doc(userId).get();
        if (!userDoc.exists) {
          throw new Error("User not found");
        }

        const user = userDoc.data();
        const userName = `${user.firstName} ${user.lastName}`;

        // Get task
        const taskRef = admin.firestore().collection("retentionTasks").doc(taskId);
        const taskDoc = await taskRef.get();

        if (!taskDoc.exists) {
          throw new Error("Task not found");
        }

        const task = taskDoc.data();

        // Build update object
        const updates = {
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Add note if provided
        if (note) {
          const noteObj = {
            userId,
            userName,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            note,
            callDuration: callDuration || 0,
            callOutcome: callOutcome || null,
          };

          updates.notes = admin.firestore.FieldValue.arrayUnion(noteObj);
          updates.contactAttempts = (task.contactAttempts || 0) + 1;
          updates.lastContactedAt = admin.firestore.FieldValue.serverTimestamp();
        }

        // Update status if provided
        if (status) {
          updates.status = status;

          if (status === "resolved") {
            updates.resolvedAt = admin.firestore.FieldValue.serverTimestamp();
            updates.resolvedBy = userId;
          }
        }

        // Update outcome if provided
        if (outcome) {
          updates.outcome = outcome;
          updates.resolutionNotes = note || null;
        }

        await taskRef.update(updates);

        logger.info(`Task ${taskId} updated by ${userName}`);

        return {success: true, taskId};
      } catch (error) {
        logger.error("Error in updateRetentionTask:", error);
        throw new Error(error.message);
      }
    }
);

/**
 * HTTP Callable: Gets retention dashboard data
 */
const getRetentionDashboard = onCall(
    {
      region: "us-central1",
    },
    async (request) => {
      try {
        const userId = request.auth?.uid;

        if (!userId) {
          throw new Error("Unauthorized");
        }

        // Get user's tasks
        const tasksSnapshot = await admin.firestore()
            .collection("retentionTasks")
            .where("assignedTo", "==", userId)
            .where("status", "in", ["pending", "assigned", "contacted"])
            .orderBy("priority")
            .orderBy("dueDate")
            .get();

        const tasks = tasksSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
          // Convert Timestamps to ISO strings for JSON
          createdAt: doc.data().createdAt?.toDate().toISOString(),
          updatedAt: doc.data().updatedAt?.toDate().toISOString(),
          dueDate: doc.data().dueDate?.toDate().toISOString(),
          expirationDate: doc.data().expirationDate?.toDate().toISOString(),
          lastContactedAt: doc.data().lastContactedAt?.toDate().toISOString(),
        }));

        // Calculate metrics
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const urgent = tasks.filter((t) => t.priority === 1).length;
        const todayTasks = tasks.filter((t) => {
          const due = new Date(t.dueDate);
          due.setHours(0, 0, 0, 0);
          return due.getTime() === today.getTime();
        }).length;
        const overdue = tasks.filter((t) => new Date(t.dueDate) < today).length;

        // Get resolved tasks for save rate
        const resolvedSnapshot = await admin.firestore()
            .collection("retentionTasks")
            .where("assignedTo", "==", userId)
            .where("status", "==", "resolved")
            .where("resolvedAt", ">", admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)))
            .get();

        const saved = resolvedSnapshot.docs.filter((d) =>
          d.data().outcome === "saved" || d.data().outcome === "converted_to_paid"
        ).length;
        const saveRate = resolvedSnapshot.size > 0 ? Math.round((saved / resolvedSnapshot.size) * 100) : 0;

        const avgValue = tasks.length > 0 ? Math.round(tasks.reduce((sum, t) => sum + (t.planValue || 0), 0) / tasks.length) : 0;
        const totalAtRisk = tasks.reduce((sum, t) => sum + (t.planValue || 0), 0);

        return {
          success: true,
          tasks,
          metrics: {
            urgent,
            todayTasks,
            overdue,
            saveRate,
            avgValue,
            totalAtRisk,
          },
        };
      } catch (error) {
        logger.error("Error in getRetentionDashboard:", error);
        throw new Error(error.message);
      }
    }
);

module.exports = {
  detectAtRiskAccounts,
  notifyAccountManagers,
  updateRetentionTask,
  getRetentionDashboard,
};
