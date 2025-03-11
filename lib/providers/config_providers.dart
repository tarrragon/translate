import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_config.dart';
import '../models/prompt_config.dart';

// Provider for API config loaded from assets
final apiConfigProvider = FutureProvider<ApiConfig>((ref) async {
  final jsonString = await rootBundle.loadString(
    'assets/config/api_config.json',
  );
  final config = ApiConfig.fromJson(json.decode(jsonString));

  // Check for stored API key
  final prefs = await SharedPreferences.getInstance();
  final storedApiKey = prefs.getString('claude_api_key');

  if (storedApiKey != null && storedApiKey.isNotEmpty) {
    return config.copyWith(apiKey: storedApiKey);
  }

  return config;
});

// Provider for prompt config loaded from assets
final promptConfigProvider = FutureProvider<PromptConfig>((ref) async {
  final jsonString = await rootBundle.loadString(
    'assets/prompts/translation_prompt.json',
  );
  return PromptConfig.fromJson(json.decode(jsonString));
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
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('claude_api_key');
    state = AsyncValue.data(apiKey);
  }

  Future<void> setApiKey(String apiKey) async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('claude_api_key', apiKey);
      state = AsyncValue.data(apiKey);

      // Refresh the API config provider to reflect new key
      ref.invalidate(apiConfigProvider);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
