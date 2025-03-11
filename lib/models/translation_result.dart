class TranslationResult {
  final String? analysis;
  final String? advice;
  final String? error;

  TranslationResult({this.analysis, this.advice, this.error});

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      analysis: json['analysis'] as String?,
      advice: json['advice'] as String?,
    );
  }

  factory TranslationResult.withError(String errorMessage) {
    return TranslationResult(error: errorMessage);
  }

  bool get hasError => error != null;
  bool get isEmpty => analysis == null && advice == null && error == null;
}
