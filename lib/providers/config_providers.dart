// lib/providers/config_providers.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
final apiConfigProvider = FutureProvider<ApiConfig>((ref) async {
  try {
    print('===== 開始載入 API 配置 =====');

    // 等待 API 金鑰載入完成
    final apiKeyStatus = ref.read(apiKeyStatusProvider);
    print('當前 API 金鑰狀態: $apiKeyStatus');

    // 如果 API 金鑰仍在載入中，等待它完成
    if (apiKeyStatus == ApiKeyStatus.loading) {
      print('API 金鑰仍在載入中，等待它完成');
      // 創建一個 Completer 來等待 API 金鑰載入完成
      final completer = Completer<void>();

      // 創建一個定時器，每 100ms 檢查一次 API 金鑰狀態
      Timer.periodic(const Duration(milliseconds: 100), (timer) {
        final currentStatus = ref.read(apiKeyStatusProvider);
        print('檢查 API 金鑰狀態: $currentStatus');
        if (currentStatus != ApiKeyStatus.loading) {
          print('API 金鑰載入完成，狀態: $currentStatus');
          timer.cancel();
          completer.complete();
        }
      });

      // 等待 API 金鑰載入完成，但最多等待 5 秒
      print('等待 API 金鑰載入完成，最多 5 秒');
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // 如果超時，也視為完成
          print('等待 API 金鑰載入超時');
          return;
        },
      );
    }

    // read config file
    print('嘗試讀取配置文件: assets/config/api_config.json');
    final jsonString = await rootBundle.loadString(
      'assets/config/api_config.json',
    );
    print('配置文件內容長度: ${jsonString.length}');

    // parse JSON
    final jsonMap = json.decode(jsonString);
    print('JSON 解析結果: ${jsonMap != null ? "成功" : "失敗"}');
    if (jsonMap == null) {
      print('配置文件為空');
      throw Exception(AppStrings.errorConfigEmpty);
    }

    // create ApiConfig object
    print('創建 ApiConfig 對象');
    final config = ApiConfig.fromJson(jsonMap);
    print(
      'ApiConfig 創建成功: baseUrl=${config.baseUrl}, model=${config.model}, maxTokens=${config.maxTokens}, apiKey=${config.apiKey != null ? (config.apiKey!.isEmpty ? "空字串" : "長度為 ${config.apiKey!.length} 的金鑰") : "null"}',
    );

    // check required fields
    if (config.baseUrl.isEmpty || config.model.isEmpty) {
      print('配置文件缺少必要欄位');
      throw Exception(AppStrings.errorConfigIncomplete);
    }

    // check API key
    print('檢查 API 金鑰');
    final apiKeyState = ref.read(apiKeyProvider);
    print(
      'API 金鑰狀態: ${apiKeyState.hasValue ? "有值" : "無值"}${apiKeyState.isLoading ? " (載入中)" : ""}',
    );
    if (apiKeyState.hasValue &&
        apiKeyState.value != null &&
        apiKeyState.value!.isNotEmpty) {
      print('使用 apiKeyProvider 中的金鑰替換配置中的金鑰');
      final result = config.copyWith(apiKey: apiKeyState.value);
      print(
        '最終配置: baseUrl=${result.baseUrl}, model=${result.model}, maxTokens=${result.maxTokens}, apiKey=${result.apiKey != null ? (result.apiKey!.isEmpty ? "空字串" : "長度為 ${result.apiKey!.length} 的金鑰") : "null"}',
      );
      print('===== API 配置載入完成 =====');
      return result;
    }

    print('使用配置文件中的金鑰');
    print(
      '最終配置: baseUrl=${config.baseUrl}, model=${config.model}, maxTokens=${config.maxTokens}, apiKey=${config.apiKey != null ? (config.apiKey!.isEmpty ? "空字串" : "長度為 ${config.apiKey!.length} 的金鑰") : "null"}',
    );
    print('===== API 配置載入完成 =====');
    return config;
  } on FormatException catch (e) {
    print('===== API 配置載入失敗: 格式錯誤 $e =====');
    throw Exception('${AppStrings.errorConfigFormat}$e');
  } on FileSystemException catch (e) {
    print('===== API 配置載入失敗: 文件系統錯誤 $e =====');
    throw Exception('${AppStrings.errorConfigFile}$e');
  } catch (e) {
    print('===== API 配置載入失敗: $e =====');
    throw Exception('${AppStrings.errorConfigLoading}$e');
  }
});

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
      print('===== 開始載入 API 金鑰 =====');

      // 先嘗試從 SharedPreferences 讀取金鑰
      final prefs = await SharedPreferences.getInstance();

      // 檢查 SharedPreferences 中的所有鍵
      final allKeys = prefs.getKeys();
      print('SharedPreferences 中的所有鍵: $allKeys');

      // 檢查每個鍵的值
      for (var key in allKeys) {
        var value = prefs.get(key);
        if (value is String) {
          print('SharedPreferences 鍵 "$key" 的值類型: String, 長度: ${value.length}');
          if (value.startsWith('sk-')) {
            print(
              '鍵 "$key" 的值可能是 API 金鑰，前綴: ${value.substring(0, math.min(10, value.length))}...',
            );

            // 嘗試獲取該鍵的設置時間（如果有）
            try {
              final lastModifiedKey = "${key}_last_modified";
              if (prefs.containsKey(lastModifiedKey)) {
                final lastModified = prefs.getInt(lastModifiedKey);
                if (lastModified != null) {
                  final dateTime = DateTime.fromMillisecondsSinceEpoch(
                    lastModified,
                  );
                  print('鍵 "$key" 的最後修改時間: $dateTime');
                }
              } else {
                print('鍵 "$key" 沒有記錄最後修改時間');
              }
            } catch (e) {
              print('獲取鍵 "$key" 的最後修改時間時出錯: $e');
            }
          }
        } else {
          print('SharedPreferences 鍵 "$key" 的值類型: ${value.runtimeType}');
        }
      }

      // 檢查應用程序的安裝時間
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        print('應用程序包名: ${packageInfo.packageName}');
        print('應用程序版本: ${packageInfo.version}');
        print('應用程序構建號: ${packageInfo.buildNumber}');
      } catch (e) {
        print('獲取應用程序信息時出錯: $e');
      }

      String? apiKey = prefs.getString('claude_api_key');
      print(
        '從 SharedPreferences 讀取的金鑰: ${apiKey != null ? (apiKey.isEmpty ? "空字串" : "長度為 ${apiKey.length} 的金鑰") : "null"}',
      );

      // 顯示金鑰的前10個字符（如果存在）
      if (apiKey != null && apiKey.isNotEmpty) {
        String prefix = apiKey.length > 10 ? apiKey.substring(0, 10) : apiKey;
        print('金鑰前綴: $prefix...');

        // 檢查金鑰是否以 sk-ant- 開頭
        if (apiKey.startsWith('sk-ant-')) {
          print('金鑰格式正確，以 sk-ant- 開頭');
        } else {
          print('金鑰格式不正確，不是以 sk-ant- 開頭');
        }
      }

      // 如果 SharedPreferences 中沒有金鑰，嘗試從配置文件讀取
      if (apiKey == null || apiKey.isEmpty) {
        print('SharedPreferences 中沒有金鑰，嘗試從配置文件讀取');
        try {
          // 讀取配置文件
          print('嘗試讀取配置文件: assets/config/api_config.json');
          final jsonString = await rootBundle.loadString(
            'assets/config/api_config.json',
          );
          print('配置文件內容長度: ${jsonString.length}');

          // 解析 JSON
          final jsonMap = json.decode(jsonString);
          print('JSON 解析結果: ${jsonMap != null ? "成功" : "失敗"}');

          if (jsonMap != null && jsonMap is Map<String, dynamic>) {
            print('配置文件欄位: ${jsonMap.keys.join(", ")}');

            // 檢查配置文件中是否有 api_key 欄位
            final configApiKey = jsonMap['api_key'] as String?;
            print(
              '配置文件中的 api_key: ${configApiKey != null ? (configApiKey.isEmpty ? "空字串" : "長度為 ${configApiKey.length} 的金鑰") : "null"}',
            );

            if (configApiKey != null && configApiKey.isNotEmpty) {
              // 如果配置文件中有有效的金鑰，使用它並保存到 SharedPreferences
              print('使用配置文件中的金鑰並保存到 SharedPreferences');
              apiKey = configApiKey;
              await prefs.setString('claude_api_key', apiKey);
              print('金鑰已保存到 SharedPreferences');
            } else {
              print('配置文件中沒有有效的金鑰');
            }
          } else {
            print('配置文件不是有效的 JSON 或不是 Map 類型');
          }
        } catch (e) {
          // 忽略配置文件讀取錯誤，繼續使用 SharedPreferences 中的金鑰（如果有的話）
          print('無法從配置文件讀取 API 金鑰: $e');
        }
      } else {
        print('使用 SharedPreferences 中的金鑰');
      }

      print(
        '最終使用的金鑰: ${apiKey != null ? (apiKey.isEmpty ? "空字串" : "長度為 ${apiKey.length} 的金鑰") : "null"}',
      );
      print('===== API 金鑰載入完成 =====');

      state = AsyncValue.data(apiKey);
    } catch (e) {
      print('===== API 金鑰載入失敗: $e =====');
      state = AsyncValue.error(
        AppStrings.errorApiKeyLoading + e.toString(),
        StackTrace.current,
      );
    }
  }

  Future<void> setApiKey(String apiKey) async {
    print('===== 開始設置 API 金鑰 =====');
    print('輸入的金鑰: ${apiKey.isEmpty ? "空字串" : "長度為 ${apiKey.length} 的金鑰"}');

    state = const AsyncValue.loading();
    try {
      if (apiKey.trim().isEmpty) {
        print('金鑰為空，設置失敗');
        state = AsyncValue.error(
          AppStrings.errorApiKeyEmpty,
          StackTrace.current,
        );
        return;
      }

      print('嘗試保存金鑰到 SharedPreferences');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('claude_api_key', apiKey);

      // 記錄設置時間
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('claude_api_key_last_modified', now);
      print(
        '金鑰已保存到 SharedPreferences，設置時間: ${DateTime.fromMillisecondsSinceEpoch(now)}',
      );

      state = AsyncValue.data(apiKey);
      print('狀態已更新為新的金鑰');

      // refresh API config provider to reflect new key
      print('重新整理 apiConfigProvider');
      ref.invalidate(apiConfigProvider);

      // 重置翻譯結果狀態，清除錯誤訊息
      print('重置翻譯結果狀態');
      ref.read(translationResultProvider.notifier).reset();

      print('===== API 金鑰設置完成 =====');
    } catch (e) {
      print('===== API 金鑰設置失敗: $e =====');
      state = AsyncValue.error(
        AppStrings.errorApiKeySaving + e.toString(),
        StackTrace.current,
      );
    }
  }

  Future<void> clearApiKey() async {
    print('===== 開始清除 API 金鑰 =====');
    state = const AsyncValue.loading();
    try {
      print('嘗試從 SharedPreferences 中移除金鑰');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('claude_api_key');
      print('金鑰已從 SharedPreferences 中移除');

      state = const AsyncValue.data(null);
      print('狀態已更新為 null');

      // refresh API config provider
      print('重新整理 apiConfigProvider');
      ref.invalidate(apiConfigProvider);

      print('===== API 金鑰清除完成 =====');
    } catch (e) {
      print('===== API 金鑰清除失敗: $e =====');
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
    print('===== 開始清除所有 SharedPreferences 數據 =====');
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();

      // 獲取所有鍵
      final allKeys = prefs.getKeys();
      print('準備清除的鍵: $allKeys');

      // 清除所有數據
      await prefs.clear();
      print('所有 SharedPreferences 數據已清除');

      state = const AsyncValue.data(null);

      // 重新整理相關提供者
      ref.invalidate(apiConfigProvider);
      ref.read(translationResultProvider.notifier).reset();

      print('===== 所有 SharedPreferences 數據清除完成 =====');
    } catch (e) {
      print('===== 清除 SharedPreferences 數據失敗: $e =====');
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
