import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_strings.dart';
import '../models/api_config.dart';
import '../models/prompt_config.dart';
import '../models/translation_result.dart';
import '../providers/config_providers.dart';

final claudeApiServiceProvider = Provider<ClaudeApiService>((ref) {
  return ClaudeApiService(ref);
});

class ClaudeApiService {
  final Ref ref;

  ClaudeApiService(this.ref);

  bool isInitialized(
    AsyncValue<ApiConfig> apiConfigAsync,
    AsyncValue<PromptConfig> promptConfigAsync,
  ) {
    if (!apiConfigAsync.hasValue || !promptConfigAsync.hasValue) {
      return false;
    }

    final apiConfig = apiConfigAsync.valueOrNull;
    if (apiConfig == null ||
        apiConfig.apiKey == null ||
        apiConfig.apiKey!.isEmpty) {
      return false;
    }

    return true;
  }

  Future<TranslationResult> generateTranslation(String userInput) async {
    // 獲取配置
    final apiConfigAsync = ref.read(apiConfigProvider);
    final promptConfigAsync = ref.read(promptConfigProvider);

    // 檢查初始化狀態
    if (!apiConfigAsync.hasValue || !promptConfigAsync.hasValue) {
      return TranslationResult.withError(
        AppStrings.errorConfigLoading +
            (apiConfigAsync.error?.toString() ??
                promptConfigAsync.error?.toString() ??
                AppStrings.errorUnknown),
      );
    }

    final apiConfig = apiConfigAsync.valueOrNull;
    final promptConfig = promptConfigAsync.valueOrNull;

    // 檢查 API 配置是否完整
    if (apiConfig == null || promptConfig == null) {
      return TranslationResult.withError(
        AppStrings.errorConfigLoading + AppStrings.errorConfigIncomplete,
      );
    }

    // 檢查 API 金鑰
    if (apiConfig.apiKey == null || apiConfig.apiKey!.isEmpty) {
      return TranslationResult.withError(AppStrings.errorApiKeyMissing);
    }

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

        // 解析 JSON 回應
        final jsonRegex = RegExp(r'({[\s\S]*})');
        final match = jsonRegex.firstMatch(content);

        if (match != null) {
          final jsonStr = match.group(1) ?? '{}';
          try {
            final parsedJson = jsonDecode(jsonStr);
            return TranslationResult.fromJson(parsedJson);
          } catch (e) {
            return TranslationResult.withError(
              '${AppStrings.errorResponseParsing}: $e',
            );
          }
        } else {
          return TranslationResult.withError(AppStrings.errorResponseParsing);
        }
      } else if (response.statusCode == 401) {
        return TranslationResult.withError(
          AppStrings.errorApiKeyMissing + AppStrings.errorApiKeyInvalid,
        );
      } else {
        return TranslationResult.withError(
          '${AppStrings.errorApiRequest}${response.statusCode}\n${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      return TranslationResult.withError(
        '${AppStrings.errorNetworkConnection}: $e',
      );
    } catch (e) {
      return TranslationResult.withError('${AppStrings.errorGeneric}$e');
    }
  }
}
