import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/config_providers.dart';
import '../providers/translation_providers.dart';
import '../widgets/translation_card.dart';
import '../constants/app_strings.dart';

class TranslatorScreen extends ConsumerWidget {
  const TranslatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKeyState = ref.watch(apiKeyProvider);
    final translationState = ref.watch(translationResultProvider);
    final inputText = ref.watch(inputTextProvider);

    final hasApiKey =
        apiKeyState.hasValue &&
        apiKeyState.value != null &&
        apiKeyState.value!.isNotEmpty;
    final TextEditingController inputController = TextEditingController(
      text: inputText,
    );

    // Update controller text if state changes
    if (inputController.text != inputText) {
      inputController.text = inputText;
      inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: inputController.text.length),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showApiKeyDialog(context, ref),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: inputController,
              decoration: const InputDecoration(
                labelText: AppStrings.inputLabel,
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              onChanged:
                  (value) => ref.read(inputTextProvider.notifier).state = value,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  !hasApiKey
                      ? () => _showApiKeyDialog(context, ref)
                      : () =>
                          ref
                              .read(translationResultProvider.notifier)
                              .translate(),
              child: Text(
                !hasApiKey
                    ? AppStrings.setApiKeyButton
                    : AppStrings.generateButton,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
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
                  if (result.isEmpty) {
                    return Center(
                      child: Text(
                        hasApiKey
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showApiKeyDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final apiKeyState = ref.read(apiKeyProvider);

    if (apiKeyState.hasValue && apiKeyState.value != null) {
      controller.text = apiKeyState.value!;
    }

    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(AppStrings.apiKeyDialogTitle),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: AppStrings.apiKeyLabel,
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(AppStrings.cancelButton),
              ),
              ElevatedButton(
                onPressed: () {
                  ref.read(apiKeyProvider.notifier).setApiKey(controller.text);
                  Navigator.pop(context);
                },
                child: const Text(AppStrings.saveButton),
              ),
            ],
          ),
    );
  }
}
