import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomerNote {
  final String id;
  final String companyId;
  final String companyName;
  final String note;
  final String noteType;
  final String createdBy;
  final String createdByName;
  final String createdByRole;
  final String? relatedTicketId;
  final List<String> tags;
  final String sentiment;
  final bool followUpRequired;
  final DateTime? followUpDate;
  final bool followUpCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerNote({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.note,
    required this.noteType,
    required this.createdBy,
    required this.createdByName,
    required this.createdByRole,
    this.relatedTicketId,
    required this.tags,
    required this.sentiment,
    required this.followUpRequired,
    this.followUpDate,
    required this.followUpCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerNote.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CustomerNote(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      note: data['note'] ?? '',
      noteType: data['noteType'] ?? 'interaction',
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      createdByRole: data['createdByRole'] ?? '',
      relatedTicketId: data['relatedTicketId'],
      tags: List<String>.from(data['tags'] ?? []),
      sentiment: data['sentiment'] ?? 'neutral',
      followUpRequired: data['followUpRequired'] ?? false,
      followUpDate: data['followUpDate']?.toDate(),
      followUpCompleted: data['followUpCompleted'] ?? false,
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'note': note,
      'noteType': noteType,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdByRole': createdByRole,
      'relatedTicketId': relatedTicketId,
      'tags': tags,
      'sentiment': sentiment,
      'followUpRequired': followUpRequired,
      'followUpDate':
          followUpDate != null ? Timestamp.fromDate(followUpDate!) : null,
      'followUpCompleted': followUpCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  // Helper getters
  bool get isPositive => sentiment == NoteSentiment.positive;
  bool get isNegative => sentiment == NoteSentiment.negative;
  bool get hasFollowUp => followUpRequired && !followUpCompleted;
  bool get isOverdue =>
      hasFollowUp && followUpDate != null && followUpDate!.isBefore(DateTime.now());
}

// Note types
class NoteType {
  static const String interaction = 'interaction';
  static const String onboardingCall = 'onboarding_call';
  static const String supportCall = 'support_call';
  static const String feedback = 'feedback';
  static const String featureRequest = 'feature_request';
  static const String upsellOpportunity = 'upsell_opportunity';
  static const String churnRisk = 'churn_risk';
  static const String successStory = 'success_story';

  static List<String> get all => [
        interaction,
        onboardingCall,
        supportCall,
        feedback,
        featureRequest,
        upsellOpportunity,
        churnRisk,
        successStory,
      ];

  static String getDisplayName(String type) {
    switch (type) {
      case interaction:
        return 'General Interaction';
      case onboardingCall:
        return 'Onboarding Call';
      case supportCall:
        return 'Support Call';
      case feedback:
        return 'Customer Feedback';
      case featureRequest:
        return 'Feature Request';
      case upsellOpportunity:
        return 'Upsell Opportunity';
      case churnRisk:
        return 'Churn Risk';
      case successStory:
        return 'Success Story';
      default:
        return type;
    }
  }

  static String getIcon(String type) {
    switch (type) {
      case interaction:
        return '💬';
      case onboardingCall:
        return '👋';
      case supportCall:
        return '📞';
      case feedback:
        return '💭';
      case featureRequest:
        return '💡';
      case upsellOpportunity:
        return '📈';
      case churnRisk:
        return '⚠️';
      case successStory:
        return '🎉';
      default:
        return '📝';
    }
  }
}

// Sentiment types
class NoteSentiment {
  static const String positive = 'positive';
  static const String neutral = 'neutral';
  static const String negative = 'negative';

  static List<String> get all => [positive, neutral, negative];

  static String getDisplayName(String sentiment) {
    return sentiment[0].toUpperCase() + sentiment.substring(1);
  }

  static String getIcon(String sentiment) {
    switch (sentiment) {
      case positive:
        return '😊';
      case neutral:
        return '😐';
      case negative:
        return '😞';
      default:
        return '😐';
    }
  }

  static dynamic getColor(String sentiment) {
    switch (sentiment) {
      case positive:
        return const Color(0xFF4CAF50);  // green
      case neutral:
        return const Color(0xFF9E9E9E);  // grey
      case negative:
        return const Color(0xFFF44336);  // red
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}
