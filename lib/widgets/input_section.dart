import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_strings.dart';
import '../providers/translation_providers.dart';

class InputSection extends ConsumerStatefulWidget {
  const InputSection({super.key});

  @override
  ConsumerState<InputSection> createState() => _InputSectionState();
}

class _InputSectionState extends ConsumerState<InputSection> {
  late TextEditingController inputController;

  @override
  void initState() {
    super.initState();
    inputController = TextEditingController();
  }

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }

  // 從剪貼簿貼上文字
  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      final text = clipboardData.text!;
      inputController.text = text;
      ref.read(inputTextProvider.notifier).state = text;
      // 確保游標位置在文字末尾
      inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: inputController.text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputText = ref.watch(inputTextProvider);

    // Update controller text if state changes
    if (inputController.text != inputText) {
      inputController.text = inputText;
      // 確保游標位置在文字末尾
      inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: inputController.text.length),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 輸入框
            Expanded(
              child: TextField(
                controller: inputController,
                decoration: InputDecoration(
                  labelText: AppStrings.inputLabel,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 5,
                textDirection: TextDirection.ltr, // 明確設定文字方向為從左到右
                onChanged: (value) {
                  // 更新 provider 狀態
                  ref.read(inputTextProvider.notifier).state = value;
                  // 確保游標位置在文字末尾
                  inputController.selection = TextSelection.fromPosition(
                    TextPosition(offset: inputController.text.length),
                  );
                },
              ),
            ),
            // 貼上按鈕
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.content_paste),
              tooltip: AppStrings.pasteButton,
              onPressed: _pasteFromClipboard,
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
