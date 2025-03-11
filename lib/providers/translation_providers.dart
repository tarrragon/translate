import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      final apiService = ref.read(claudeApiServiceProvider);
      final result = await apiService.generateTranslation(inputText);
      state = AsyncValue.data(result);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void reset() {
    state = AsyncValue.data(TranslationResult());
  }
}
