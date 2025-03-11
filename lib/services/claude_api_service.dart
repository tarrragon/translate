import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_config.dart';
import '../models/prompt_config.dart';
import '../models/translation_result.dart';
import '../providers/config_providers.dart';

final claudeApiServiceProvider = Provider<ClaudeApiService>((ref) {
  final apiConfigAsync = ref.watch(apiConfigProvider);
  final promptConfigAsync = ref.watch(promptConfigProvider);

  return ClaudeApiService(ref, apiConfigAsync, promptConfigAsync);
});

class ClaudeApiService {
  final Ref ref;
  final AsyncValue<ApiConfig> apiConfigAsync;
  final AsyncValue<PromptConfig> promptConfigAsync;

  ClaudeApiService(this.ref, this.apiConfigAsync, this.promptConfigAsync);

  bool get isReady =>
      apiConfigAsync.hasValue &&
      promptConfigAsync.hasValue &&
      apiConfigAsync.value!.apiKey != null &&
      apiConfigAsync.value!.apiKey!.isNotEmpty;

  Future<TranslationResult> generateTranslation(String userInput) async {
    if (!isReady) {
      return TranslationResult.withError(
        'API service not properly initialized',
      );
    }

    final apiConfig = apiConfigAsync.value!;
    final promptConfig = promptConfigAsync.value!;

    try {
      final response = await http.post(
        Uri.parse(apiConfig.baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiConfig.apiKey!,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': apiConfig.model,
          'max_tokens': apiConfig.maxTokens,
          'system': promptConfig.systemPrompt,
          'messages': [
            {'role': 'user', 'content': userInput},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'][0]['text'];

        // Extract JSON from the response
        final jsonRegex = RegExp(r'({[\s\S]*})');
        final match = jsonRegex.firstMatch(content);

        if (match != null) {
          final jsonStr = match.group(1) ?? '{}';
          final parsedJson = jsonDecode(jsonStr);

          return TranslationResult.fromJson(parsedJson);
        } else {
          return TranslationResult.withError(
            'Could not parse response properly',
          );
        }
      } else {
        return TranslationResult.withError('API error: ${response.statusCode}');
      }
    } catch (e) {
      return TranslationResult.withError('Error: $e');
    }
  }
}
