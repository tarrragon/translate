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
    // 使用 apiKeyStatusProvider 來判斷 API 金鑰狀態
    final apiKeyStatus = ref.watch(apiKeyStatusProvider);

    // 根據 API 金鑰狀態顯示不同的按鈕
    switch (apiKeyStatus) {
      case ApiKeyStatus.loading:
        return ElevatedButton(
          onPressed: null, // 禁用按鈕
          child: const Text('載入中...'),
        );

      case ApiKeyStatus.valid:
        return ElevatedButton(
          onPressed:
              () => ref.read(translationResultProvider.notifier).translate(),
          child: Text(AppStrings.generateButton),
        );

      case ApiKeyStatus.invalid:
        return ElevatedButton(
          onPressed: onApiKeyRequest,
          child: Text(AppStrings.setApiKeyButton),
        );
    }
  }
}
