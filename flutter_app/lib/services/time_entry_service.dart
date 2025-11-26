import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/time_entry_model.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';

class TimeEntryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Clock in
  Future<TimeEntryModel> clockIn({
    required String userId,
    Position? location,
    String? photoUrl,
    String? notes,
  }) async {
    try {
      // Check if user already has an active clock-in
      final activeClock = await getActiveClockIn(userId);
      if (activeClock != null) {
        throw Exception(
            'You are already clocked in. Please clock out before clocking in again.');
      }

      // Get company's work location for geofencing
      Map<String, double>? workLocation;
      bool isOffPremises = false;

      try {
        // First, get user's company ID
        final userDoc = await _firestore
            .collection(FirebaseCollections.users)
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          final companyId = userData?['companyId'];

          if (companyId != null) {
            // Get company's work location (geocoded business address)
            final companyDoc = await _firestore
                .collection('companies')
                .doc(companyId)
                .get();

            if (companyDoc.exists) {
              final companyData = companyDoc.data();
              if (companyData?['workLocation'] != null) {
                workLocation = Map<String, double>.from(companyData!['workLocation']);

                // Check geofencing if both locations are available
                if (location != null && workLocation != null) {
                  isOffPremises = !isWithinGeofence(
                    currentLocation: location,
                    targetLocation: workLocation,
                  );
                }
              }
            }
          }
        }
      } catch (e) {
        ErrorHandler.logError(e, null);
        // Continue with clock-in even if geofence check fails
      }

      // Create new time entry
      final docRef = _firestore.collection(FirebaseCollections.timeEntries).doc();

      final timeEntry = TimeEntryModel(
        id: docRef.id,
        userId: userId,
        clockInTime: DateTime.now(),
        clockInLocation: location != null
            ? {'lat': location.latitude, 'lng': location.longitude}
            : null,
        clockInPhotoUrl: photoUrl,
        notes: notes,
        createdAt: DateTime.now(),
        isOffPremises: isOffPremises,
      );

      await docRef.set(timeEntry.toMap());

      // Track active clock-in
      await _firestore
          .collection(FirebaseCollections.activeClockIns)
          .doc(userId)
          .set({
        'timeEntryId': timeEntry.id,
        'clockInTime': Timestamp.fromDate(timeEntry.clockInTime),
        'userId': userId,
      });

      // If off-premises, trigger notification (Cloud Function will handle this)
      if (isOffPremises) {
        await _firestore
            .collection(FirebaseCollections.offPremisesAlerts)
            .add({
          'userId': userId,
          'timeEntryId': timeEntry.id,
          'clockInTime': Timestamp.fromDate(timeEntry.clockInTime),
          'location': location != null
              ? {'lat': location.latitude, 'lng': location.longitude}
              : null,
          'workLocation': workLocation,
          'createdAt': Timestamp.now(),
          'notified': false,
        });
      }

      return timeEntry;
    } on FirebaseException catch (e) {
      throw Exception(ErrorHandler.getFirestoreErrorMessage(e));
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Clock out
  Future<TimeEntryModel> clockOut({
    required String userId,
    Position? location,
    String? photoUrl,
    String? notes,
  }) async {
    try {
      // Get active clock-in
      final activeDoc = await _firestore
          .collection(FirebaseCollections.activeClockIns)
          .doc(userId)
          .get();

      if (!activeDoc.exists) {
        throw Exception('No active clock-in found. Please clock in first.');
      }

      final timeEntryId = activeDoc.data()!['timeEntryId'] as String;

      // Get the time entry
      final timeEntryDoc = await _firestore
          .collection(FirebaseCollections.timeEntries)
          .doc(timeEntryId)
          .get();

      if (!timeEntryDoc.exists) {
        throw Exception('Time entry not found.');
      }

      final timeEntry = TimeEntryModel.fromFirestore(timeEntryDoc);

      // Update time entry with clock out
      final updatedEntry = timeEntry.copyWith(
        clockOutTime: DateTime.now(),
        clockOutLocation: location != null
            ? {'lat': location.latitude, 'lng': location.longitude}
            : null,
        clockOutPhotoUrl: photoUrl,
        notes: notes ?? timeEntry.notes,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(FirebaseCollections.timeEntries)
          .doc(timeEntryId)
          .update(updatedEntry.toMap());

      // Remove active clock-in
      await _firestore
          .collection(FirebaseCollections.activeClockIns)
          .doc(userId)
          .delete();

      return updatedEntry;
    } on FirebaseException catch (e) {
      throw Exception(ErrorHandler.getFirestoreErrorMessage(e));
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Get active clock-in for a user
  Future<TimeEntryModel?> getActiveClockIn(String userId) async {
    try {
      final activeDoc = await _firestore
          .collection(FirebaseCollections.activeClockIns)
          .doc(userId)
          .get();

      if (!activeDoc.exists) return null;

      final timeEntryId = activeDoc.data()!['timeEntryId'] as String;

      final timeEntryDoc = await _firestore
          .collection(FirebaseCollections.timeEntries)
          .doc(timeEntryId)
          .get();

      if (!timeEntryDoc.exists) return null;

      return TimeEntryModel.fromFirestore(timeEntryDoc);
    } catch (e) {
      ErrorHandler.logError(e, null);
      return null;
    }
  }

  // Check if user is currently clocked in
  Future<bool> isUserClockedIn(String userId) async {
    final activeClockIn = await getActiveClockIn(userId);
    return activeClockIn != null;
  }

  // Get time entries for a user
  Stream<List<TimeEntryModel>> getUserTimeEntriesStream(String userId) {
    return _firestore
        .collection(FirebaseCollections.timeEntries)
        .where('userId', isEqualTo: userId)
        .orderBy('clockInTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TimeEntryModel.fromFirestore(doc))
            .toList());
  }

  // Get time entries for a date range
  Future<List<TimeEntryModel>> getTimeEntriesInRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.timeEntries)
          .where('userId', isEqualTo: userId)
          .where('clockInTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('clockInTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('clockInTime', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => TimeEntryModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      ErrorHandler.logError(e, null);
      return [];
    }
  }

  // Get all time entries for employees in a company (for admin)
  // Note: This method should be called with a list of employee IDs from the company
  // to ensure proper multi-tenancy isolation
  Stream<List<TimeEntryModel>> getTimeEntriesForEmployees(List<String> employeeIds) {
    if (employeeIds.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(FirebaseCollections.timeEntries)
        .where('userId', whereIn: employeeIds.take(10).toList()) // Firestore limit of 10 for whereIn
        .orderBy('clockInTime', descending: true)
        .limit(100) // Limit to most recent 100
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TimeEntryModel.fromFirestore(doc))
            .toList());
  }

  // Get time entry by ID
  Future<TimeEntryModel?> getTimeEntryById(String timeEntryId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.timeEntries)
          .doc(timeEntryId)
          .get();

      if (!doc.exists) return null;

      return TimeEntryModel.fromFirestore(doc);
    } catch (e) {
      ErrorHandler.logError(e, null);
      return null;
    }
  }

  // Update time entry (for corrections)
  Future<void> updateTimeEntry(TimeEntryModel timeEntry) async {
    try {
      await _firestore
          .collection(FirebaseCollections.timeEntries)
          .doc(timeEntry.id)
          .update(timeEntry.copyWith(updatedAt: DateTime.now()).toMap());
    } on FirebaseException catch (e) {
      throw Exception(ErrorHandler.getFirestoreErrorMessage(e));
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Edit time entry with audit trail (for admin/manager edits)
  Future<void> editTimeEntry({
    required String timeEntryId,
    required DateTime newClockIn,
    required DateTime? newClockOut,
    required String editorId,
    required String editorName,
    required String reason,
  }) async {
    try {
      // Get the existing time entry
      final timeEntry = await getTimeEntryById(timeEntryId);
      if (timeEntry == null) {
        throw Exception('Time entry not found');
      }

      // Validate that clock out is after clock in
      if (newClockOut != null && newClockOut.isBefore(newClockIn)) {
        throw Exception('Clock out time must be after clock in time');
      }

      // Create edit history record
      final editRecord = {
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'editorId': editorId,
        'editorName': editorName,
        'reason': reason,
        'oldClockIn': Timestamp.fromDate(timeEntry.clockInTime),
        'oldClockOut': timeEntry.clockOutTime != null
            ? Timestamp.fromDate(timeEntry.clockOutTime!)
            : null,
        'newClockIn': Timestamp.fromDate(newClockIn),
        'newClockOut':
            newClockOut != null ? Timestamp.fromDate(newClockOut) : null,
      };

      // Get existing edit history or create new list
      final editHistory = timeEntry.editHistory ?? [];
      final updatedEditHistory = [...editHistory, editRecord];

      // Update the time entry
      final updatedEntry = timeEntry.copyWith(
        clockInTime: newClockIn,
        clockOutTime: newClockOut,
        updatedAt: DateTime.now(),
        editHistory: updatedEditHistory,
      );

      await _firestore
          .collection(FirebaseCollections.timeEntries)
          .doc(timeEntryId)
          .update(updatedEntry.toMap());
    } on FirebaseException catch (e) {
      throw Exception(ErrorHandler.getFirestoreErrorMessage(e));
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Delete time entry
  Future<void> deleteTimeEntry(String timeEntryId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.timeEntries)
          .doc(timeEntryId)
          .delete();
    } on FirebaseException catch (e) {
      throw Exception(ErrorHandler.getFirestoreErrorMessage(e));
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Calculate total hours for a user in a date range
  Future<double> getTotalHoursInRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final entries = await getTimeEntriesInRange(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    double totalHours = 0.0;
    for (final entry in entries) {
      totalHours += entry.totalHours;
    }

    return totalHours;
  }

  // Get current week's hours for a user
  Future<double> getCurrentWeekHours(String userId) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final weekStartMidnight =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    final weekEnd = weekStartMidnight.add(const Duration(days: 7));

    return getTotalHoursInRange(
      userId: userId,
      startDate: weekStartMidnight,
      endDate: weekEnd,
    );
  }

  // Get location permission and current position
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
            'Location permissions are permanently denied. Please enable them in settings.');
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      ErrorHandler.logError(e, null);
      return null;
    }
  }

  // Check if user is within geofence
  bool isWithinGeofence({
    required Position currentLocation,
    required Map<String, double> targetLocation,
    int radiusMeters = AppConstants.geofenceRadiusMeters,
  }) {
    final distance = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      targetLocation['lat']!,
      targetLocation['lng']!,
    );

    return distance <= radiusMeters;
  }
}
