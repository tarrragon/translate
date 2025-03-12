import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_strings.dart';
import '../providers/config_providers.dart';

class ApiKeyDialog extends ConsumerStatefulWidget {
  const ApiKeyDialog({super.key});

  @override
  ConsumerState<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends ConsumerState<ApiKeyDialog> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();

    // 初始化時設置已存在的 API 金鑰
    final apiKeyState = ref.read(apiKeyProvider);
    if (apiKeyState.hasValue && apiKeyState.value != null) {
      controller.text = apiKeyState.value!;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // 從剪貼簿貼上文字
  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        controller.text = clipboardData.text!;
        // 確保游標位置在文字末尾
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      });
    }
  }

  // 清除輸入的文字
  void _clearText() {
    setState(() {
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppStrings.apiKeyDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // API 金鑰輸入欄位
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: AppStrings.apiKeyLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              // 按鈕區域
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 貼上按鈕
                  IconButton(
                    icon: const Icon(Icons.content_paste),
                    tooltip: AppStrings.pasteButton,
                    onPressed: _pasteFromClipboard,
                  ),
                  // 清除按鈕
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: AppStrings.clearButton,
                    onPressed: _clearText,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 提示文字
          Text(
            AppStrings.apiKeyHint,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
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
