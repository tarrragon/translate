import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translate/providers/config_providers.dart';
import '../constants/app_strings.dart';
import '../widgets/input_section.dart';
import '../widgets/action_button.dart';
import '../widgets/results_display.dart';
import '../widgets/api_key_dialog.dart';

class TranslatorScreen extends ConsumerWidget {
  const TranslatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /**
     * 應用程式初始化狀態監控
     * 
     * 1. 防止未初始化狀態下的 UI 錯誤：
     *    - 若設定檔未載入，翻譯功能將無法正常運作
     *    - 若 API 金鑰缺失，使用者操作將導致錯誤
     * 
     * 2. 提供適當的使用者回饋：
     *    - 載入中：顯示進度指示器，告知使用者應用程式正在準備中
     *    - 錯誤狀態：顯示明確的錯誤訊息，幫助使用者了解問題
     *    - 初始化完成：顯示完整功能介面
     * 
     * 3. 優化使用者體驗：
     *    - 避免使用者在應用程式未準備好時進行操作
     *    - 減少因初始化問題導致的應用程式當機
     *    - 提供清楚的狀態指示，減少使用者困惑
     */
    final initializationState = ref.watch(appInitializationProvider);

    return initializationState.when(
      loading:
          () => Scaffold(
            appBar: AppBar(
              title: Text(AppStrings.appTitle),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => showApiKeyDialog(context),
                ),
              ],
            ),
            body: const Center(child: CircularProgressIndicator()),
          ),
      error:
          (error, stack) => Scaffold(
            appBar: AppBar(title: Text(AppStrings.appTitle)),
            body: Center(
              child: Text(
                '${AppStrings.errorPrefix}$error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
      data:
          (_) => Scaffold(
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
                  ActionButton(
                    onApiKeyRequest: () => showApiKeyDialog(context),
                  ),

                  const SizedBox(height: 24),

                  // Results display area
                  const ResultsDisplay(),
                ],
              ),
            ),
          ),
    );
  }
}
