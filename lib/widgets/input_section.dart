import 'package:flutter/material.dart';
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
        TextField(
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
        const SizedBox(height: 16),
      ],
    );
  }
}
