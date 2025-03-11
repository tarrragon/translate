import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_strings.dart';
import '../providers/config_providers.dart';
import '../providers/translation_providers.dart';

class ActionButton extends ConsumerWidget {
  final Function() onApiKeyRequest;

  const ActionButton({super.key, required this.onApiKeyRequest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKeyState = ref.watch(apiKeyProvider);
    final hasApiKey =
        apiKeyState.hasValue &&
        apiKeyState.value != null &&
        apiKeyState.value!.isNotEmpty;

    return ElevatedButton(
      onPressed:
          !hasApiKey
              ? onApiKeyRequest
              : () => ref.read(translationResultProvider.notifier).translate(),
      child: Text(
        !hasApiKey ? AppStrings.setApiKeyButton : AppStrings.generateButton,
      ),
    );
  }
}
