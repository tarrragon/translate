import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_strings.dart';
import '../providers/config_providers.dart';
import '../providers/translation_providers.dart';
import 'translation_card.dart';

class ResultsDisplay extends ConsumerWidget {
  const ResultsDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKeyStatus = ref.watch(apiKeyStatusProvider);
    final translationState = ref.watch(translationResultProvider);
    final inputText = ref.watch(inputTextProvider);

    return Expanded(
      child: translationState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Text(
                '${AppStrings.errorPrefix}$error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        data: (result) {
          if (apiKeyStatus == ApiKeyStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (result.isEmpty) {
            return Center(
              child: Text(
                apiKeyStatus == ApiKeyStatus.valid
                    ? AppStrings.pleaseInputText
                    : AppStrings.pleaseSetApiKey,
              ),
            );
          }

          if (result.hasError) {
            return Center(
              child: Text(
                '${AppStrings.errorPrefix}${result.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          return SingleChildScrollView(
            child: TranslationCard(
              inputText: inputText,
              analysis: result.analysis ?? '',
              advice: result.advice ?? '',
            ),
          );
        },
      ),
    );
  }
}
