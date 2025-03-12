import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_strings.dart';

class TranslationCard extends StatelessWidget {
  final String inputText;
  final String analysis;
  final String advice;

  const TranslationCard({
    super.key,
    required this.inputText,
    required this.analysis,
    required this.advice,
  });

  // 複製文字到剪貼簿
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    // 顯示提示訊息
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.copiedToClipboard),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Center(
              child: Text(
                AppStrings.cardTitle,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const Divider(thickness: 1, color: Colors.grey, height: 32),

            // Input section
            // Container(
            //   padding: const EdgeInsets.all(12),
            //   decoration: BoxDecoration(
            //     color: Colors.grey.shade100,
            //     borderRadius: BorderRadius.circular(8),
            //   ),
            //   child: Text(
            //     inputText,
            //     style: const TextStyle(fontSize: 14, color: Colors.black87),
            //   ),
            // ),
            const SizedBox(height: 24),

            // Analysis section
            Row(
              children: [
                const Text(
                  AppStrings.analysisTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                // 分析區域的複製按鈕
                IconButton(
                  icon: const Icon(Icons.content_copy, size: 20),
                  tooltip: AppStrings.copyButton,
                  onPressed: () => _copyToClipboard(context, analysis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              analysis,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Advice section
            Row(
              children: [
                const Text(
                  AppStrings.adviceTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                // 建議區域的複製按鈕
                IconButton(
                  icon: const Icon(Icons.content_copy, size: 20),
                  tooltip: AppStrings.copyButton,
                  onPressed: () => _copyToClipboard(context, advice),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              advice,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // const Divider(thickness: 1, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
