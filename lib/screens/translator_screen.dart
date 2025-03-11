import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/config_providers.dart';
import '../providers/translation_providers.dart';
import '../widgets/translation_card.dart';

class TranslatorScreen extends ConsumerWidget {
  const TranslatorScreen({Key? key}) : super(key: key);

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
        title: const Text('言外之意 Translator'),
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
                labelText: '輸入文字',
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
              child: Text(!hasApiKey ? '設定 API Key' : '生成翻譯'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: translationState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, stack) => Center(
                      child: Text(
                        '錯誤: $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                data: (result) {
                  if (result.isEmpty) {
                    return Center(
                      child: Text(hasApiKey ? '輸入文字並點擊生成翻譯' : '請先設定 API Key'),
                    );
                  }

                  if (result.hasError) {
                    return Center(
                      child: Text(
                        '錯誤: ${result.error}',
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
            title: const Text('設定 Claude API Key'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  ref.read(apiKeyProvider.notifier).setApiKey(controller.text);
                  Navigator.pop(context);
                },
                child: const Text('儲存'),
              ),
            ],
          ),
    );
  }
}
