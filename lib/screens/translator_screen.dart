import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_strings.dart';
import '../widgets/input_section.dart';
import '../widgets/action_button.dart';
import '../widgets/results_display.dart';
import '../widgets/api_key_dialog.dart';

class TranslatorScreen extends ConsumerWidget {
  const TranslatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
