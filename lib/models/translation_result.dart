class TranslationResult {
  final String? analysis;
  final String? advice;
  final String? error;

  TranslationResult({this.analysis, this.advice, this.error});

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    // 檢查並安全地提取字段，處理可能的編碼問題
    String? safeGetString(String key) {
      final value = json[key];
      if (value == null) return null;

      // 如果已經是字符串，處理可能的 Unicode 轉義序列
      if (value is String) {
        return _decodeUnicodeEscapes(value);
      }

      // 如果是其他類型，嘗試轉換為字符串
      try {
        return _decodeUnicodeEscapes(value.toString());
      } catch (e) {
        print('轉換 $key 為字符串時出錯: $e');
        return null;
      }
    }

    return TranslationResult(
      analysis: safeGetString('analysis'),
      advice: safeGetString('advice'),
    );
  }

  // 處理 Unicode 轉義序列
  static String _decodeUnicodeEscapes(String input) {
    // 如果輸入為空，直接返回
    if (input.isEmpty) return input;

    // 檢查是否包含 Unicode 轉義序列
    if (!input.contains('\\u')) return input;

    // 替換所有 Unicode 轉義序列
    return input.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (match) {
      final hexCode = match.group(1)!;
      final codePoint = int.parse(hexCode, radix: 16);
      return String.fromCharCode(codePoint);
    });
  }

  factory TranslationResult.withError(String errorMessage) {
    return TranslationResult(error: errorMessage);
  }

  bool get hasError => error != null;
  bool get isEmpty => analysis == null && advice == null && error == null;
}
