/// A structured observation returned by the /ingest endpoint.
class Observation {
  final String id;
  final String patientId;
  final String type;
  final String content;
  final List<String> triggers;
  final List<String> successfulInterventions;
  final List<String> failedInterventions;
  final String sentiment;
  final String loggedBy;
  final String timestamp;

  const Observation({
    required this.id,
    required this.patientId,
    required this.type,
    required this.content,
    required this.triggers,
    required this.successfulInterventions,
    required this.failedInterventions,
    required this.sentiment,
    required this.loggedBy,
    required this.timestamp,
  });

  factory Observation.fromJson(Map<String, dynamic> json) {
    return Observation(
      id: json['_id']?.toString() ?? '',
      patientId: json['patient_id'] as String? ?? 'unknown',
      type: json['type'] as String? ?? 'other',
      content: json['content'] as String? ?? '',
      triggers: _toStringList(json['triggers']),
      successfulInterventions: _toStringList(json['successful_interventions']),
      failedInterventions: _toStringList(json['failed_interventions']),
      sentiment: json['sentiment'] as String? ?? 'neutral',
      loggedBy: json['logged_by'] as String? ?? 'unknown',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// Human-friendly label for the observation type.
  String get typeLabel {
    switch (type) {
      case 'behavioral_observation':
        return 'Behavior';
      case 'medication_log':
        return 'Medication';
      case 'dietary_note':
        return 'Diet & Nutrition';
      case 'environmental_note':
        return 'Environment';
      default:
        return 'Note';
    }
  }

  /// Emoji for the sentiment.
  String get sentimentEmoji {
    switch (sentiment) {
      case 'positive':
        return '😊';
      case 'distressing':
        return '😟';
      default:
        return '😐';
    }
  }

  /// Human-friendly label for the sentiment.
  String get sentimentLabel {
    switch (sentiment) {
      case 'positive':
        return 'Positive';
      case 'distressing':
        return 'Difficult';
      default:
        return 'Neutral';
    }
  }
}

/// The full response from /ingest.
class IngestResponse {
  final String message;
  final String extractedText;
  final Observation structuredData;

  const IngestResponse({
    required this.message,
    required this.extractedText,
    required this.structuredData,
  });

  factory IngestResponse.fromJson(Map<String, dynamic> json) {
    return IngestResponse(
      message: json['message'] as String? ?? '',
      extractedText: json['extracted_text'] as String? ?? '',
      structuredData: Observation.fromJson(
        json['structured_data'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
