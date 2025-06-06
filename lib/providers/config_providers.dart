// lib/providers/config_providers.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_strings.dart';
import '../models/api_config.dart';
import '../models/prompt_config.dart';
import '../providers/translation_providers.dart';

/// API 設定提供者
///
/// 負責項目：
/// - 從資源檔讀取 API 設定（網址、模型名稱等）
/// - 將本機儲存的 API 金鑰整合到設定中
/// - 檢查設定的完整性與正確性
///
/// 設計理念：
/// - 集中管理 API 設定，避免設定散落各處造成維護上的困難
/// - 當設定變更時（例如更新 API 金鑰），只需在一處修改，便會自動更新到所有相依處
/// - 預先檢查設定，避免在實際呼叫 API 時才發現設定問題
///
/// 例外處理：
/// - 檔案不存在：丟出 FileSystemException，提示設定檔案遺失
/// - JSON 格式錯誤：丟出 FormatException，提示設定格式有誤
/// - 必要欄位缺失：檢查 baseUrl 和 model，確保基本設定完整
///
/// 使用情境：
/// - 在 API 服務中取得請求設定
/// - 在初始化流程中檢查應用程式設定的完整性
final apiConfigProvider = FutureProvider<ApiConfig>((configRef) async {
  try {
    // 等待 API 金鑰載入完成
    final apiKeyStatus = configRef.read(apiKeyStatusProvider);

    // 如果 API 金鑰仍在載入中，等待它完成
    bool isLoading = apiKeyStatus == ApiKeyStatus.loading;
    if (isLoading) {
      await waitForApiKeyStateChange(configRef);
    }

    // read config file
    final jsonString = await rootBundle.loadString(
      'assets/config/api_config.json',
    );

    // parse JSON
    final jsonMap = json.decode(jsonString);
    if (jsonMap == null) {
      throw Exception(AppStrings.errorConfigEmpty);
    }

    // create ApiConfig object
    final config = ApiConfig.fromJson(jsonMap);

    // check required fields
    if (config.baseUrl.isEmpty || config.model.isEmpty) {
      throw Exception(AppStrings.errorConfigIncomplete);
    }

    // check API key
    final apiKeyState = configRef.read(apiKeyProvider);
    if (apiKeyState.hasValue &&
        apiKeyState.value != null &&
        apiKeyState.value!.isNotEmpty) {
      final result = config.copyWith(apiKey: apiKeyState.value);
      return result;
    }

    return config;
  } on FormatException catch (e) {
    throw Exception('${AppStrings.errorConfigFormat}$e');
  } on FileSystemException catch (e) {
    throw Exception('${AppStrings.errorConfigFile}$e');
  } catch (e) {
    throw Exception('${AppStrings.errorConfigLoading}$e');
  }
});

/// 等待 API 金鑰狀態變更
///
/// 負責項目：
/// - 定期檢查 API 金鑰的載入狀態
/// - 當狀態不再是 loading 時完成等待
/// - 處理超時情況
///
/// 設計理念：
/// - 封裝等待邏輯，提供統一的介面
/// - 自動處理超時情況，避免永久等待
/// - 簡化使用方的程式碼
///
/// 使用情境：
/// - 需要等待 API 金鑰載入完成時
/// - 需要確保 API 金鑰狀態已就緒時
Future<void> waitForApiKeyStateChange(Ref ref) async {
  final completer = Completer<void>();

  Timer.periodic(const Duration(milliseconds: 100), (timer) {
    final currentStatus = ref.read(apiKeyStatusProvider);
    bool isReady = currentStatus != ApiKeyStatus.loading;
    if (isReady) {
      timer.cancel();
      completer.complete();
    }
  });

  // 等待 API 金鑰載入完成，但最多等待 5 秒
  await completer.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      // 如果超時，也視為完成
      return;
    },
  );
}

/// 提示詞設定提供者
///
/// 負責項目：
/// - 從資源檔讀取翻譯提示詞設定
/// - 檢查提示詞的完整性與正確性
/// - 為 AI 模型提供結構化的指令
///
/// 設計理念：
/// - 將提示詞與程式碼分開，方便非技術人員（如語言專家）調整提示詞內容
/// - 支援提示詞的版本控制與持續優化
/// - 避免硬編碼提示詞造成的維護困難
///
/// 例外處理：
/// - 檔案不存在：丟出 FileSystemException，提示提示詞檔案遺失
/// - JSON 格式錯誤：丟出 FormatException，提示提示詞格式有誤
/// - 系統提示詞缺失：檢查 systemPrompt 欄位，確保基本指令完整
///
/// 使用情境：
/// - 在翻譯服務中建立 AI 請求
/// - 在應用程式初始化時檢查提示詞設定
final promptConfigProvider = FutureProvider<PromptConfig>((ref) async {
  try {
    // read prompt file
    final jsonString = await rootBundle.loadString(
      'assets/prompts/translation_prompt.json',
    );

    // parse JSON
    final jsonMap = json.decode(jsonString);
    if (jsonMap == null) {
      throw Exception(AppStrings.errorPromptEmpty);
    }

    // create PromptConfig object
    final config = PromptConfig.fromJson(jsonMap);

    // check if system prompt is empty
    if (config.systemPrompt.isEmpty) {
      throw Exception(AppStrings.errorPromptIncomplete);
    }

    return config;
  } on FormatException catch (e) {
    throw Exception('${AppStrings.errorPromptFormat}$e');
  } on FileSystemException catch (e) {
    throw Exception('${AppStrings.errorPromptFile}$e');
  } catch (e) {
    throw Exception('${AppStrings.errorPromptLoading}$e');
  }
});

/// API 金鑰管理提供者
///
/// 負責項目：
/// - 從本機儲存讀取使用者的 API 金鑰
/// - 提供設定和清除 API 金鑰的功能
/// - 維護 API 金鑰的狀態（載入中/有效/錯誤）
///
/// 設計理念：
/// - 集中管理 API 金鑰，確保安全性與一致性
/// - 使用 StateNotifier 提供即時更新機制，當金鑰變更時自動通知相依元件
/// - 在金鑰變更時自動更新相關設定（如 apiConfigProvider）
///
/// 例外處理：
/// - 儲存錯誤：捕捉並回報 SharedPreferences 相關錯誤
/// - 空白金鑰檢查：防止設定空白或僅包含空格的金鑰
///
/// 使用情境：
/// - 使用者首次設定 API 金鑰
/// - 檢查應用程式是否已設定 API 金鑰
/// - 使用者更新或清除 API 金鑰
final apiKeyProvider =
    StateNotifierProvider<ApiKeyNotifier, AsyncValue<String?>>((ref) {
      return ApiKeyNotifier(ref);
    });

class ApiKeyNotifier extends StateNotifier<AsyncValue<String?>> {
  final Ref ref;

  ApiKeyNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    try {
      // 先嘗試從 SharedPreferences 讀取金鑰
      final prefs = await SharedPreferences.getInstance();

      // 檢查 SharedPreferences 中的所有鍵
      final allKeys = prefs.getKeys();

      // 檢查每個鍵的值
      for (var key in allKeys) {
        var value = prefs.get(key);
        if (value is String) {
          if (value.startsWith('sk-')) {
            // 嘗試獲取該鍵的設置時間（如果有）
            try {
              final lastModifiedKey = "${key}_last_modified";
              if (prefs.containsKey(lastModifiedKey)) {
                final lastModified = prefs.getInt(lastModifiedKey);
                if (lastModified != null) {}
              } else {}
            } catch (e) {
              throw Exception('${AppStrings.errorApiKeyLoading}$e');
            }
          }
        } else {}
      }

      String? apiKey = prefs.getString('claude_api_key');

      // 顯示金鑰的前10個字符（如果存在）
      if (apiKey != null && apiKey.isNotEmpty) {
        // 檢查金鑰是否以 sk-ant- 開頭
        if (apiKey.startsWith('sk-ant-')) {
        } else {}
      }

      // 如果 SharedPreferences 中沒有金鑰，嘗試從配置文件讀取
      if (apiKey == null || apiKey.isEmpty) {
        try {
          // 讀取配置文件
          final jsonString = await rootBundle.loadString(
            'assets/config/api_config.json',
          );

          // 解析 JSON
          final jsonMap = json.decode(jsonString);

          if (jsonMap != null && jsonMap is Map<String, dynamic>) {
            // 檢查配置文件中是否有 api_key 欄位
            final configApiKey = jsonMap['api_key'] as String?;

            if (configApiKey != null && configApiKey.isNotEmpty) {
              // 如果配置文件中有有效的金鑰，使用它並保存到 SharedPreferences
              apiKey = configApiKey;
              await prefs.setString('claude_api_key', apiKey);
            } else {}
          } else {}
        } catch (e) {
          // 忽略配置文件讀取錯誤，繼續使用 SharedPreferences 中的金鑰（如果有的話）
        }
      } else {}

      state = AsyncValue.data(apiKey);
    } catch (e) {
      state = AsyncValue.error(
        AppStrings.errorApiKeyLoading + e.toString(),
        StackTrace.current,
      );
    }
  }

  Future<void> setApiKey(String apiKey) async {
    state = const AsyncValue.loading();
    try {
      if (apiKey.trim().isEmpty) {
        state = AsyncValue.error(
          AppStrings.errorApiKeyEmpty,
          StackTrace.current,
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('claude_api_key', apiKey);

      // 記錄設置時間
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('claude_api_key_last_modified', now);

      state = AsyncValue.data(apiKey);

      // refresh API config provider to reflect new key
      ref.invalidate(apiConfigProvider);

      // 重置翻譯結果狀態，清除錯誤訊息
      ref.read(translationResultProvider.notifier).reset();
    } catch (e) {
      state = AsyncValue.error(
        AppStrings.errorApiKeySaving + e.toString(),
        StackTrace.current,
      );
    }
  }

  Future<void> clearApiKey() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('claude_api_key');

      state = const AsyncValue.data(null);

      // refresh API config provider
      ref.invalidate(apiConfigProvider);
    } catch (e) {
      state = AsyncValue.error(
        AppStrings.errorApiKeyClearing + e.toString(),
        StackTrace.current,
      );
    }
  }

  /// 清除所有 SharedPreferences 數據
  ///
  /// 此方法用於測試目的，可以清除所有存儲的數據，
  /// 包括 API 金鑰，以便測試應用程序在沒有預設金鑰的情況下的行為。
  Future<void> clearAllPreferences() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();

      // 獲取所有鍵
      prefs.getKeys();

      // 清除所有數據
      await prefs.clear();

      state = const AsyncValue.data(null);

      // 重新整理相關提供者
      ref.invalidate(apiConfigProvider);
      ref.read(translationResultProvider.notifier).reset();
    } catch (e) {
      state = AsyncValue.error(
        '清除 SharedPreferences 數據失敗: $e',
        StackTrace.current,
      );
    }
  }
}

/// 應用程式初始化提供者
///
/// 設計理念：
/// 1. 關注點分離：將初始化邏輯從 UI 元件中獨立出來，實現業務邏輯與畫面呈現的分離
/// 2. 單一職責原則：專門負責應用程式啟動時的初始化工作，包括：
///    - 確保設定檔正確載入
///    - 檢查 API 金鑰狀態
///    - 設定初始錯誤狀態（如有需要）
/// 3. 重複使用性：初始化邏輯可在應用程式的任何地方重複使用，不限於特定 UI 元件
/// 4. 易於測試：邏輯獨立封裝，便於單元測試
/// 5. 例外處理：集中處理初始化過程中可能出現的各種錯誤
///
/// 使用方式：
/// - UI 元件透過 ref.watch(appInitializationProvider) 監控初始化狀態
/// - 根據狀態（載入中/錯誤/完成）顯示對應的畫面
final appInitializationProvider = FutureProvider<bool>((ref) async {
  try {
    // 等待配置提供者初始化
    await ref.read(apiConfigProvider.future);
    await ref.read(promptConfigProvider.future);

    // 獲取最新的 API 金鑰狀態
    final apiKeyStatus = ref.read(apiKeyStatusProvider);

    // 檢查 API 金鑰是否有效
    if (apiKeyStatus == ApiKeyStatus.invalid) {
      ref
          .read(translationResultProvider.notifier)
          .setError(AppStrings.errorApiKeyMissing);
    } else if (apiKeyStatus == ApiKeyStatus.valid) {
      // 如果金鑰有效，確保重置任何可能的錯誤訊息
      ref.read(translationResultProvider.notifier).reset();
    }

    return true;
  } catch (e) {
    // 處理初始化錯誤
    ref
        .read(translationResultProvider.notifier)
        .setError('${AppStrings.errorConfigLoading}$e');
    return false;
  }
});

/// API 金鑰狀態提供者
///
/// 負責項目：
/// - 提供 API 金鑰的狀態（有效/無效/載入中）
/// - 集中管理 API 金鑰狀態的判斷邏輯
///
/// 設計理念：
/// - 遵循 Tell, Don't Ask 原則，將狀態判斷邏輯集中在狀態管理層
/// - 減少 UI 元件中的判斷邏輯，使程式碼更加清晰
/// - 提供統一的 API 金鑰狀態介面，避免重複邏輯
///
/// 使用情境：
/// - UI 元件需要根據 API 金鑰狀態顯示不同內容
/// - 業務邏輯需要判斷 API 金鑰是否有效
enum ApiKeyStatus {
  loading, // API 金鑰載入中
  valid, // API 金鑰有效
  invalid, // API 金鑰無效或未設定
}

final apiKeyStatusProvider = Provider<ApiKeyStatus>((ref) {
  final apiKeyState = ref.watch(apiKeyProvider);

  if (apiKeyState.isLoading) {
    return ApiKeyStatus.loading;
  }

  if (apiKeyState.hasValue &&
      apiKeyState.value != null &&
      apiKeyState.value!.isNotEmpty) {
    return ApiKeyStatus.valid;
  }

  return ApiKeyStatus.invalid;
});
