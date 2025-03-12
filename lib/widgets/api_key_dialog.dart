import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
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
                    hintText: AppStrings.apiKeyHint,
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
          const SizedBox(height: 16),
          // 顯示 API 金鑰來源信息的按鈕
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final apiKey = prefs.getString('claude_api_key');
              final lastModified = prefs.getInt('claude_api_key_last_modified');

              String message = '金鑰信息：\n';
              if (apiKey != null && apiKey.isNotEmpty) {
                message += '- 金鑰長度: ${apiKey.length}\n';
                message +=
                    '- 金鑰前綴: ${apiKey.substring(0, math.min(10, apiKey.length))}...\n';
                message +=
                    '- 格式: ${apiKey.startsWith('sk-ant-') ? "正確 (sk-ant-)" : "不正確"}\n';
              } else {
                message += '- 未設置金鑰\n';
              }

              if (lastModified != null) {
                final dateTime = DateTime.fromMillisecondsSinceEpoch(
                  lastModified,
                );
                message += '- 設置時間: $dateTime\n';
              } else {
                message += '- 未記錄設置時間\n';
              }

              message += '\nSharedPreferences 中的所有鍵：\n';
              message += prefs.getKeys().join(', ');

              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('API 金鑰來源信息'),
                      content: SingleChildScrollView(child: Text(message)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('關閉'),
                        ),
                      ],
                    ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('查看 API 金鑰來源信息'),
          ),
          const SizedBox(height: 8),
          // 清除所有 SharedPreferences 數據的按鈕（僅用於測試）
          ElevatedButton(
            onPressed: () {
              ref.read(apiKeyProvider.notifier).clearAllPreferences();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已清除所有 SharedPreferences 數據，請重新啟動應用程序'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('清除所有存儲數據（測試用）'),
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
