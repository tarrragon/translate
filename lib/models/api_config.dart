class ApiConfig {
  final String baseUrl;
  final String model;
  final int maxTokens;
  final String? apiKey;

  ApiConfig({
    required this.baseUrl,
    required this.model,
    required this.maxTokens,
    this.apiKey,
  });

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    return ApiConfig(
      baseUrl: json['base_url'] as String,
      model: json['model'] as String,
      maxTokens: json['max_tokens'] as int,
      apiKey: json['api_key'] as String?,
    );
  }

  ApiConfig copyWith({
    String? baseUrl,
    String? model,
    int? maxTokens,
    String? apiKey,
  }) {
    return ApiConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      maxTokens: maxTokens ?? this.maxTokens,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}
