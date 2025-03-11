import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_strings.dart';
import '../providers/translation_providers.dart';

class InputSection extends ConsumerWidget {
  const InputSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inputText = ref.watch(inputTextProvider);
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
          onChanged:
              (value) => ref.read(inputTextProvider.notifier).state = value,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
