import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translate/constants/app_strings.dart';
import 'package:translate/providers/config_providers.dart';
import '../models/translation_result.dart';
import '../services/claude_api_service.dart';

// Input text provider
final inputTextProvider = StateProvider<String>((ref) => '');

// Translation result provider
final translationResultProvider =
    StateNotifierProvider<TranslationNotifier, AsyncValue<TranslationResult>>((
      ref,
    ) {
      return TranslationNotifier(ref);
    });

class TranslationNotifier extends StateNotifier<AsyncValue<TranslationResult>> {
  final Ref ref;

  TranslationNotifier(this.ref) : super(AsyncValue.data(TranslationResult()));

  Future<void> translate() async {
    final inputText = ref.read(inputTextProvider);
    if (inputText.isEmpty) return;

    state = const AsyncValue.loading();

    try {
      // 先檢查 API 金鑰
      final apiKeyState = ref.read(apiKeyProvider);
      if (!apiKeyState.hasValue ||
          apiKeyState.value == null ||
          apiKeyState.value!.isEmpty) {
        state = AsyncValue.data(
          TranslationResult.withError(AppStrings.errorApiKeyMissing),
        );
        return;
      }

      final apiService = ref.read(claudeApiServiceProvider);
      final result = await apiService.generateTranslation(inputText);
      state = AsyncValue.data(result);
    } catch (e) {
      state = AsyncValue.data(
        TranslationResult.withError('${AppStrings.errorGeneric}$e'),
      );
    }
  }

  void reset() {
    state = AsyncValue.data(TranslationResult());
  }

  void setError(String errorMessage) {
    state = AsyncValue.data(TranslationResult.withError(errorMessage));
  }
}
