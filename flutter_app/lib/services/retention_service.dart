import 'package:cloud_functions/cloud_functions.dart';
import '../models/retention_task.dart';

/// Service for managing customer retention tasks
class RetentionService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Gets the retention dashboard data for the current user
  Future<RetentionDashboardData> getDashboard() async {
    try {
      final callable = _functions.httpsCallable('getRetentionDashboard');
      final result = await callable.call();

      if (result.data['success'] != true) {
        throw Exception('Failed to load dashboard');
      }

      final tasks = (result.data['tasks'] as List<dynamic>)
          .map((t) => RetentionTask.fromJson(t as Map<String, dynamic>))
          .toList();

      final metrics = RetentionMetrics.fromJson(
        result.data['metrics'] as Map<String, dynamic>,
      );

      return RetentionDashboardData(
        tasks: tasks,
        metrics: metrics,
      );
    } catch (e) {
      print('Error loading retention dashboard: $e');
      rethrow;
    }
  }

  /// Updates a retention task with contact notes and outcome
  Future<void> updateTask({
    required String taskId,
    String? status,
    String? outcome,
    String? note,
    int? callDuration,
    String? callOutcome,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateRetentionTask');
      final result = await callable.call({
        'taskId': taskId,
        if (status != null) 'status': status,
        if (outcome != null) 'outcome': outcome,
        if (note != null) 'note': note,
        if (callDuration != null) 'callDuration': callDuration,
        if (callOutcome != null) 'callOutcome': callOutcome,
      });

      if (result.data['success'] != true) {
        throw Exception('Failed to update task');
      }
    } catch (e) {
      print('Error updating retention task: $e');
      rethrow;
    }
  }

  /// Marks task as contacted with notes
  Future<void> logContactAttempt({
    required String taskId,
    required String note,
    required int callDuration,
    required String callOutcome,
  }) async {
    String newStatus = 'contacted';

    // If no answer, keep as assigned/pending
    if (callOutcome == 'no_answer' || callOutcome == 'wrong_number') {
      newStatus = 'assigned';
    }

    await updateTask(
      taskId: taskId,
      status: newStatus,
      note: note,
      callDuration: callDuration,
      callOutcome: callOutcome,
    );
  }

  /// Resolves task with final outcome
  Future<void> resolveTask({
    required String taskId,
    required String outcome,
    required String notes,
  }) async {
    await updateTask(
      taskId: taskId,
      status: 'resolved',
      outcome: outcome,
      note: notes,
    );
  }
}

/// Data structure for retention dashboard
class RetentionDashboardData {
  final List<RetentionTask> tasks;
  final RetentionMetrics metrics;

  RetentionDashboardData({
    required this.tasks,
    required this.metrics,
  });

  /// Get tasks filtered by status
  List<RetentionTask> get urgentTasks =>
      tasks.where((t) => t.priority == 1).toList();

  List<RetentionTask> get todayTasks =>
      tasks.where((t) => t.isDueToday).toList();

  List<RetentionTask> get overdueTasks =>
      tasks.where((t) => t.isOverdue).toList();

  List<RetentionTask> get followUpTasks =>
      tasks.where((t) => t.status == 'contacted').toList();
}
