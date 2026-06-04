/// A single message in the ask-for-help conversation.
///
/// For assistant messages, [action] holds the clear "do this now" line
/// and [context] holds the supportive explanation. For user messages,
/// only [text] is used.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  /// The clear action extracted from an assistant response.
  /// Null for user messages or if parsing fails.
  final String? action;

  /// The context/explanation extracted from an assistant response.
  /// Null for user messages or if parsing fails.
  final String? context;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.action,
    this.context,
  });

  /// Creates a ChatMessage from an assistant's structured response.
  ///
  /// Parses the ACTION: / CONTEXT: format. Falls back gracefully
  /// if the agent doesn't follow the format.
  factory ChatMessage.fromIntervention(String response) {
    final parsed = _parseResponse(response);

    return ChatMessage(
      text: response,
      isUser: false,
      timestamp: DateTime.now(),
      action: parsed.$1,
      context: parsed.$2,
    );
  }

  /// Whether this message has a structured action/context split.
  bool get hasStructuredResponse => action != null && action!.isNotEmpty;

  /// Parse "ACTION: ...\n\nCONTEXT: ..." format.
  /// Returns (action, context). Falls back to (null, null) if unparseable.
  static (String?, String?) _parseResponse(String response) {
    final text = response.trim();

    // Try to find ACTION: prefix
    final actionPattern = RegExp(
      r'(?:^|\n)\s*\**ACTION\**[:\s]*(.+?)(?=\n\s*\**CONTEXT\**[:\s]|\n\n\**CONTEXT\**|\$)',
      caseSensitive: false,
      dotAll: true,
    );

    final contextPattern = RegExp(
      r'(?:^|\n)\s*\**CONTEXT\**[:\s]*(.+)',
      caseSensitive: false,
      dotAll: true,
    );

    final actionMatch = actionPattern.firstMatch(text);
    final contextMatch = contextPattern.firstMatch(text);

    if (actionMatch != null) {
      final action = actionMatch.group(1)?.trim() ?? '';
      final context = contextMatch?.group(1)?.trim() ?? '';
      if (action.isNotEmpty) {
        return (action, context.isNotEmpty ? context : null);
      }
    }

    return (null, null);
  }
}

/// The response from /query.
class InterventionResponse {
  final String question;
  final String intervention;

  const InterventionResponse({
    required this.question,
    required this.intervention,
  });

  factory InterventionResponse.fromJson(Map<String, dynamic> json) {
    return InterventionResponse(
      question: json['question'] as String? ?? '',
      intervention: json['intervention'] as String? ?? '',
    );
  }
}
