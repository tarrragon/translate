import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_strings.dart';
import '../providers/config_providers.dart';

class ApiKeyDialog extends ConsumerWidget {
  const ApiKeyDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final apiKeyState = ref.read(apiKeyProvider);

    if (apiKeyState.hasValue && apiKeyState.value != null) {
      controller.text = apiKeyState.value!;
    }

    return AlertDialog(
      title: Text(AppStrings.apiKeyDialogTitle),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: AppStrings.apiKeyLabel,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.cancelButton),
        ),
        ElevatedButton(
          onPressed: () {
            ref.read(apiKeyProvider.notifier).setApiKey(controller.text);
            Navigator.pop(context);
          },
          child: Text(AppStrings.saveButton),
        ),
      ],
    );
  }
}

// Helper function to show the dialog
Future<void> showApiKeyDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const ApiKeyDialog(),
  );
}
