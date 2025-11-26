import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/shift_template_model.dart';
import '../utils/constants.dart';

class ShiftTemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new shift template
  Future<ShiftTemplateModel> createTemplate({
    required String name,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    required String createdBy,
    String? companyId,
    bool hasLunchBreak = false,
    bool isDayOff = false,
    String? dayOffType,
    double? paidHours,
    bool isGlobal = false,
  }) async {
    try {
      double durationHours = 0.0;

      if (isDayOff) {
        // For day off templates, duration is 0
        durationHours = 0.0;
      } else {
        // Regular shift - calculate duration
        if (startTime == null || endTime == null) {
          throw Exception('Start time and end time are required for regular shifts');
        }

        final startMinutes = startTime.hour * 60 + startTime.minute;
        final endMinutes = endTime.hour * 60 + endTime.minute;
        durationHours = (endMinutes - startMinutes) / 60.0;

        // Deduct 1 hour for lunch break if checked
        if (hasLunchBreak) {
          durationHours -= 1.0;
        }

        if (durationHours <= 0) {
          throw Exception('End time must be after start time');
        }
      }

      final docRef = _firestore.collection(FirebaseCollections.shiftTemplates).doc();

      final template = ShiftTemplateModel(
        id: docRef.id,
        name: name,
        startTime: startTime,
        endTime: endTime,
        durationHours: durationHours,
        hasLunchBreak: hasLunchBreak,
        isDayOff: isDayOff,
        dayOffType: dayOffType,
        paidHours: paidHours,
        createdBy: createdBy,
        companyId: companyId,
        isGlobal: isGlobal,
        createdAt: DateTime.now(),
      );

      await docRef.set(template.toMap());
      return template;
    } catch (e) {
      throw Exception('Failed to create template: $e');
    }
  }

  // Update an existing template
  Future<ShiftTemplateModel> updateTemplate({
    required String templateId,
    String? name,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? hasLunchBreak,
    bool? isDayOff,
    String? dayOffType,
    double? paidHours,
    bool? isGlobal,
  }) async {
    try {
      final docRef = _firestore
          .collection(FirebaseCollections.shiftTemplates)
          .doc(templateId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Template not found');
      }

      final currentTemplate = ShiftTemplateModel.fromFirestore(doc);

      final newIsDayOff = isDayOff ?? currentTemplate.isDayOff;
      double durationHours = 0.0;

      if (newIsDayOff) {
        // Day off templates have 0 duration
        durationHours = 0.0;
      } else {
        // Regular shift - recalculate duration
        final newStartTime = startTime ?? currentTemplate.startTime;
        final newEndTime = endTime ?? currentTemplate.endTime;
        final newHasLunchBreak = hasLunchBreak ?? currentTemplate.hasLunchBreak;

        if (newStartTime == null || newEndTime == null) {
          throw Exception('Start time and end time are required for regular shifts');
        }

        final startMinutes = newStartTime.hour * 60 + newStartTime.minute;
        final endMinutes = newEndTime.hour * 60 + newEndTime.minute;
        durationHours = (endMinutes - startMinutes) / 60.0;

        // Deduct 1 hour for lunch break if checked
        if (newHasLunchBreak) {
          durationHours -= 1.0;
        }

        if (durationHours <= 0) {
          throw Exception('End time must be after start time');
        }
      }

      final updatedTemplate = currentTemplate.copyWith(
        name: name,
        startTime: startTime,
        endTime: endTime,
        durationHours: durationHours,
        hasLunchBreak: hasLunchBreak,
        isDayOff: isDayOff,
        dayOffType: dayOffType,
        paidHours: paidHours,
        isGlobal: isGlobal,
        updatedAt: DateTime.now(),
      );

      await docRef.update(updatedTemplate.toMap());
      return updatedTemplate;
    } catch (e) {
      throw Exception('Failed to update template: $e');
    }
  }

  // Delete a template
  Future<void> deleteTemplate(String templateId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.shiftTemplates)
          .doc(templateId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete template: $e');
    }
  }

  // Get all templates for a company (global + company-specific)
  Stream<List<ShiftTemplateModel>> getCompanyTemplatesStream(String companyId) {
    return _firestore
        .collection(FirebaseCollections.shiftTemplates)
        .where(
          Filter.or(
            Filter('isGlobal', isEqualTo: true),
            Filter('companyId', isEqualTo: companyId),
          ),
        )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftTemplateModel.fromFirestore(doc))
          .toList()
        ..sort((a, b) {
          // Sort: global first, then by name
          if (a.isGlobal && !b.isGlobal) return -1;
          if (!a.isGlobal && b.isGlobal) return 1;
          return a.name.compareTo(b.name);
        });
    });
  }

  // Deprecated: Use getCompanyTemplatesStream instead
  @deprecated
  Stream<List<ShiftTemplateModel>> getUserTemplatesStream(String userId) {
    // For backward compatibility, return empty stream
    // This should be replaced with getCompanyTemplatesStream
    return Stream.value([]);
  }

  // Get all global templates
  Future<List<ShiftTemplateModel>> getGlobalTemplates() async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.shiftTemplates)
          .where('isGlobal', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ShiftTemplateModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get global templates: $e');
    }
  }

  // Get templates created by a specific user
  Future<List<ShiftTemplateModel>> getUserCreatedTemplates(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.shiftTemplates)
          .where('createdBy', isEqualTo: userId)
          .get();

      return querySnapshot.docs
          .map((doc) => ShiftTemplateModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user templates: $e');
    }
  }

  // Get a specific template by ID
  Future<ShiftTemplateModel?> getTemplateById(String templateId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.shiftTemplates)
          .doc(templateId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return ShiftTemplateModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get template: $e');
    }
  }
}
