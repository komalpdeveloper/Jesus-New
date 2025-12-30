/// Data models for Biblical Chat API communication
/// Based on the FastAPI Biblical Chat Service schema

/// Request model for chat endpoints
class ChatRequest {
  final String message;
  final String sessionId;

  const ChatRequest({
    required this.message,
    required this.sessionId,
  });

  Map<String, dynamic> toJson() => {
    'message': message,
    'session_id': sessionId,
  };

  factory ChatRequest.fromJson(Map<String, dynamic> json) => ChatRequest(
    message: json['message'] as String,
    sessionId: json['session_id'] as String,
  );
}

/// Response model for successful chat responses
class ChatResponse {
  final String response;
  final String persona;
  final String sessionId;

  const ChatResponse({
    required this.response,
    required this.persona,
    required this.sessionId,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
    response: json['response'] as String,
    persona: json['persona'] as String,
    sessionId: json['session_id'] as String,
  );

  Map<String, dynamic> toJson() => {
    'response': response,
    'persona': persona,
    'session_id': sessionId,
  };
}

/// Error response model
class ApiError {
  final String detail;
  final int statusCode;

  const ApiError({
    required this.detail,
    required this.statusCode,
  });

  factory ApiError.fromJson(Map<String, dynamic> json, int statusCode) => ApiError(
    detail: json['detail'] as String? ?? 'Unknown error',
    statusCode: statusCode,
  );

  Map<String, dynamic> toJson() => {
    'detail': detail,
    'status_code': statusCode,
  };

  @override
  String toString() => 'ApiError($statusCode): $detail';
}

/// API health status model
class HealthStatus {
  final String status;
  final String message;
  final String timestamp;

  const HealthStatus({
    required this.status,
    required this.message,
    required this.timestamp,
  });

  factory HealthStatus.fromJson(Map<String, dynamic> json) => HealthStatus(
    status: json['status'] as String,
    message: json['message'] as String,
    timestamp: json['timestamp'] as String,
  );

  bool get isHealthy => status.toLowerCase() == 'ok';
}

/// API statistics model
class ApiStats {
  final Map<String, dynamic> endpoints;
  final Map<String, dynamic> rateLimits;
  final Map<String, dynamic> features;

  const ApiStats({
    required this.endpoints,
    required this.rateLimits,
    required this.features,
  });

  factory ApiStats.fromJson(Map<String, dynamic> json) => ApiStats(
    endpoints: json['endpoints'] as Map<String, dynamic>? ?? {},
    rateLimits: json['rate_limits'] as Map<String, dynamic>? ?? {},
    features: json['features'] as Map<String, dynamic>? ?? {},
  );
}

/// Session clear response model
class SessionClearResponse {
  final String message;
  final String sessionId;

  const SessionClearResponse({
    required this.message,
    required this.sessionId,
  });

  factory SessionClearResponse.fromJson(Map<String, dynamic> json) => SessionClearResponse(
    message: json['message'] as String,
    sessionId: json['session_id'] as String,
  );
}

/// Biblical persona enumeration
enum BiblicalPersona {
  jesus('Jesus', '/chat/jesus'),
  god('God the Father', '/chat/god'),
  livingWord('The Living Word', '/chat/word');

  const BiblicalPersona(this.displayName, this.endpoint);
  
  final String displayName;
  final String endpoint;

  String get description {
    switch (this) {
      case BiblicalPersona.jesus:
        return 'Personal and compassionate conversation using only direct words of Jesus from the New Testament';
      case BiblicalPersona.god:
        return 'Powerful and profound conversation using direct words of God from the Old Testament';
      case BiblicalPersona.livingWord:
        return 'Comprehensive wisdom drawing from the entire Bible - Genesis to Revelation';
    }
  }

  static BiblicalPersona fromEndpoint(String endpoint) {
    return values.firstWhere(
      (persona) => persona.endpoint == endpoint,
      orElse: () => BiblicalPersona.jesus,
    );
  }
}

/// Message model for UI
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isTyping;
  final BiblicalPersona? persona;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isTyping = false,
    this.persona,
  });

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    bool? isTyping,
    BiblicalPersona? persona,
  }) => ChatMessage(
    text: text ?? this.text,
    isUser: isUser ?? this.isUser,
    timestamp: timestamp ?? this.timestamp,
    isTyping: isTyping ?? this.isTyping,
    persona: persona ?? this.persona,
  );
}