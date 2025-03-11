import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translate/providers/config_providers.dart';
import 'package:translate/providers/translation_providers.dart';
import '../constants/app_strings.dart';
import '../widgets/input_section.dart';
import '../widgets/action_button.dart';
import '../widgets/results_display.dart';
import '../widgets/api_key_dialog.dart';

class TranslatorScreen extends ConsumerStatefulWidget {
  const TranslatorScreen({super.key});

  @override
  ConsumerState<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends ConsumerState<TranslatorScreen> {
  bool _checkingInitialization = true;

  @override
  void initState() {
    super.initState();
    _checkInitialization();
  }

  Future<void> _checkInitialization() async {
    try {
      // notice:need to wait for both providers to be initialized
      await ref.read(apiConfigProvider.future);
      await ref.read(promptConfigProvider.future);
      // check API key
      final apiKeyState = ref.watch(apiKeyProvider);
      if (apiKeyState.value == null || apiKeyState.value!.isEmpty) {
        ref
            .read(translationResultProvider.notifier)
            .setError(AppStrings.errorApiKeyMissing);
      }
    } catch (e) {
      // handle initialization error
      ref
          .read(translationResultProvider.notifier)
          .setError('${AppStrings.errorConfigLoading}$e');
    } finally {
      setState(() {
        _checkingInitialization = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // check if still initializing
    if (_checkingInitialization) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.appTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => showApiKeyDialog(context),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => showApiKeyDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input area for text
            const InputSection(),

            // Action button (set API key or generate translation)
            ActionButton(onApiKeyRequest: () => showApiKeyDialog(context)),

            const SizedBox(height: 24),

            // Results display area
            const ResultsDisplay(),
          ],
        ),
      ),
    );
  }
}
