// lib/providers/config_providers.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_strings.dart';
import '../models/api_config.dart';
import '../models/prompt_config.dart';

// Provider for API config loaded from assets
final apiConfigProvider = FutureProvider<ApiConfig>((ref) async {
  try {
    // read config file
    final jsonString = await rootBundle.loadString(
      'assets/config/api_config.json',
    );

    // parse JSON
    final jsonMap = json.decode(jsonString);
    if (jsonMap == null) {
      throw Exception(AppStrings.errorConfigEmpty);
    }

    // create ApiConfig object
    final config = ApiConfig.fromJson(jsonMap);

    // check required fields
    if (config.baseUrl.isEmpty || config.model.isEmpty) {
      throw Exception(AppStrings.errorConfigIncomplete);
    }

    // check API key
    final apiKeyState = ref.watch(apiKeyProvider);
    if (apiKeyState.value != null && apiKeyState.value!.isNotEmpty) {
      return config.copyWith(apiKey: apiKeyState.value);
    }

    return config;
  } on FormatException catch (e) {
    throw Exception('${AppStrings.errorConfigFormat}$e');
  } on FileSystemException catch (e) {
    throw Exception('${AppStrings.errorConfigFile}$e');
  } catch (e) {
    throw Exception('${AppStrings.errorConfigLoading}$e');
  }
});

// Provider for prompt config loaded from assets
final promptConfigProvider = FutureProvider<PromptConfig>((ref) async {
  try {
    // read prompt file
    final jsonString = await rootBundle.loadString(
      'assets/prompts/translation_prompt.json',
    );

    // parse JSON
    final jsonMap = json.decode(jsonString);
    if (jsonMap == null) {
      throw Exception(AppStrings.errorPromptEmpty);
    }

    // create PromptConfig object
    final config = PromptConfig.fromJson(jsonMap);

    // check if system prompt is empty
    if (config.systemPrompt.isEmpty) {
      throw Exception(AppStrings.errorPromptIncomplete);
    }

    return config;
  } on FormatException catch (e) {
    throw Exception('${AppStrings.errorPromptFormat}$e');
  } on FileSystemException catch (e) {
    throw Exception('${AppStrings.errorPromptFile}$e');
  } catch (e) {
    throw Exception('${AppStrings.errorPromptLoading}$e');
  }
});

// Provider to update and store API key
final apiKeyProvider =
    StateNotifierProvider<ApiKeyNotifier, AsyncValue<String?>>((ref) {
      return ApiKeyNotifier(ref);
    });

class ApiKeyNotifier extends StateNotifier<AsyncValue<String?>> {
  final Ref ref;

  ApiKeyNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('claude_api_key');
      state = AsyncValue.data(apiKey);
    } catch (e) {
      state = AsyncValue.error(
        AppStrings.errorApiKeyLoading + e.toString(),
        StackTrace.current,
      );
    }
  }

  Future<void> setApiKey(String apiKey) async {
    state = const AsyncValue.loading();
    try {
      if (apiKey.trim().isEmpty) {
        state = AsyncValue.error(
          AppStrings.errorApiKeyEmpty,
          StackTrace.current,
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('claude_api_key', apiKey);
      state = AsyncValue.data(apiKey);

      // refresh API config provider to reflect new key
      ref.invalidate(apiConfigProvider);
    } catch (e) {
      state = AsyncValue.error(
        AppStrings.errorApiKeySaving + e.toString(),
        StackTrace.current,
      );
    }
  }

  Future<void> clearApiKey() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('claude_api_key');
      state = const AsyncValue.data(null);

      // refresh API config provider
      ref.invalidate(apiConfigProvider);
    } catch (e) {
      state = AsyncValue.error(
        AppStrings.errorApiKeyClearing + e.toString(),
        StackTrace.current,
      );
    }
  }
}
