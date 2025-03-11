import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_strings.dart';
import '../models/api_config.dart';
import '../models/prompt_config.dart';
import '../models/translation_result.dart';
import '../providers/config_providers.dart';

final claudeApiServiceProvider = Provider<ClaudeApiService>((ref) {
  return ClaudeApiService(ref);
});

class ClaudeApiService {
  final Ref ref;

  ClaudeApiService(this.ref);

  bool isInitialized(
    AsyncValue<ApiConfig> apiConfigAsync,
    AsyncValue<PromptConfig> promptConfigAsync,
  ) {
    if (!apiConfigAsync.hasValue || !promptConfigAsync.hasValue) {
      return false;
    }

    final apiConfig = apiConfigAsync.valueOrNull;
    if (apiConfig == null ||
        apiConfig.apiKey == null ||
        apiConfig.apiKey!.isEmpty) {
      return false;
    }

    return true;
  }

  Future<TranslationResult> generateTranslation(String userInput) async {
    // 獲取配置
    final apiConfigAsync = ref.read(apiConfigProvider);
    final promptConfigAsync = ref.read(promptConfigProvider);

    // 檢查初始化狀態
    if (!apiConfigAsync.hasValue || !promptConfigAsync.hasValue) {
      return TranslationResult.withError(
        AppStrings.errorConfigLoading +
            (apiConfigAsync.error?.toString() ??
                promptConfigAsync.error?.toString() ??
                AppStrings.errorUnknown),
      );
    }

    final apiConfig = apiConfigAsync.valueOrNull;
    final promptConfig = promptConfigAsync.valueOrNull;

    // 檢查 API 配置是否完整
    if (apiConfig == null || promptConfig == null) {
      return TranslationResult.withError(
        AppStrings.errorConfigLoading + AppStrings.errorConfigIncomplete,
      );
    }

    // 檢查 API 金鑰
    if (apiConfig.apiKey == null || apiConfig.apiKey!.isEmpty) {
      return TranslationResult.withError(AppStrings.errorApiKeyMissing);
    }

    // 檢查 API 金鑰格式
    if (!apiConfig.apiKey!.startsWith('sk-ant-')) {
      return TranslationResult.withError(
        '${AppStrings.errorApiKeyInvalid}: API 金鑰格式不正確，應以 sk-ant- 開頭',
      );
    }

    // 檢查 baseUrl
    if (!apiConfig.baseUrl.startsWith('https://')) {
      return TranslationResult.withError(
        '${AppStrings.errorConfigIncomplete}: API URL 必須使用 HTTPS',
      );
    }

    // 獲取系統提示詞
    String systemPrompt = promptConfig.systemPrompt;

    // 準備請求內容
    final requestBody = {
      'model': apiConfig.model,
      'max_tokens': apiConfig.maxTokens,
      'messages': [
        {'role': 'user', 'content': userInput},
      ],
    };

    // 如果系統提示詞不為空，則添加到請求中
    if (systemPrompt.isNotEmpty) {
      requestBody['system'] = systemPrompt;
    }

    // 準備請求標頭
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': apiConfig.apiKey!,
      'anthropic-version': '2023-06-01',
    };

    try {
      // 記錄請求開始（不記錄敏感資訊）
      print('開始 API 請求: ${apiConfig.baseUrl}');
      print(
        '請求標頭: ${headers.map((k, v) => MapEntry(k, k == 'x-api-key' ? '[已隱藏]' : v))}',
      );
      print(
        '請求內容: ${requestBody.toString().substring(0, min(100, requestBody.toString().length))}...',
      );

      // 發送請求
      final response = await http.post(
        Uri.parse(apiConfig.baseUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      // 記錄回應狀態
      print('API 回應狀態碼: ${response.statusCode}');
      print('API 回應標頭: ${response.headers}');

      // 檢查回應的內容類型
      final contentType = response.headers['content-type'] ?? '';
      print('回應內容類型: $contentType');

      // 檢查回應的編碼
      final contentEncoding = response.headers['content-encoding'] ?? '';
      print('回應內容編碼: $contentEncoding');

      // 如果回應內容不太長，記錄完整內容；否則只記錄前 200 個字元
      final responsePreview =
          response.body.length > 200
              ? '${response.body.substring(0, 200)}...'
              : response.body;
      print('API 回應內容預覽: $responsePreview');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'][0]['text'];

        // 輸出原始內容以便調試
        print('原始回應內容: $content');

        try {
          // 嘗試解析 JSON 回應
          Map<String, dynamic> parsedJson;

          // 首先嘗試直接解析
          try {
            parsedJson = jsonDecode(content);
            print('直接解析 content 成功: $parsedJson');
          } catch (e) {
            print('直接解析 content 失敗: $e');

            // 嘗試使用正則表達式提取 JSON
            final jsonRegex = RegExp(
              r'```json\s*\n([\s\S]*?)\n```|({[\s\S]*})',
            );
            final match = jsonRegex.firstMatch(content);

            if (match != null) {
              final jsonStr =
                  (match.group(1)?.trim() ?? match.group(2) ?? '{}').trim();
              print('提取的 JSON 字符串: $jsonStr');

              try {
                parsedJson = jsonDecode(jsonStr);
                print('使用正則表達式解析 JSON 成功');
              } catch (e2) {
                print('使用正則表達式解析 JSON 失敗: $e2');

                // 清理並修復 JSON
                String cleanedContent = content.replaceAll(
                  RegExp(r'^\uFEFF'),
                  '',
                );

                // 檢查 JSON 是否完整
                bool isJsonComplete = cleanedContent.trim().endsWith('}');

                // 如果 JSON 不完整，嘗試修復
                if (!isJsonComplete) {
                  print('檢測到不完整的 JSON，嘗試修復...');

                  // 檢查是否有 "advice" 欄位但沒有結束引號
                  if (cleanedContent.contains('"advice"') &&
                      !cleanedContent.contains('"advice": "')) {
                    // 沒有 advice 欄位值，可能是格式錯誤
                    cleanedContent = cleanedContent.trim() + '}';
                  } else if (cleanedContent.contains('"advice": "') &&
                      !cleanedContent.contains('"}')) {
                    // 有 advice 欄位開始但沒有結束，添加結束引號和大括號
                    cleanedContent = cleanedContent.trim() + '"}';
                  } else {
                    // 其他情況，嘗試添加缺失的大括號
                    cleanedContent = cleanedContent.trim() + '}';
                  }

                  print(
                    '修復後的 JSON: ${cleanedContent.substring(0, min(100, cleanedContent.length))}...',
                  );
                }

                // 嘗試解析修復後的 JSON
                try {
                  parsedJson = jsonDecode(cleanedContent);
                  print('修復後的 JSON 解析成功');
                } catch (e3) {
                  print('修復後的 JSON 仍然無法解析: $e3');

                  // 更激進的修復方法：提取已知的欄位並重建 JSON
                  // 使用更寬鬆的正則表達式，可以匹配多行字符串
                  final analysisRegex = RegExp(
                    r'"analysis"\s*:\s*"([\s\S]*?)(?:"(?=\s*,|\s*})|$)',
                  );
                  final adviceRegex = RegExp(
                    r'"advice"\s*:\s*"([\s\S]*?)(?:"(?=\s*})|$)',
                  );

                  final analysisMatch = analysisRegex.firstMatch(
                    cleanedContent,
                  );
                  final adviceMatch = adviceRegex.firstMatch(cleanedContent);

                  String analysis = analysisMatch?.group(1) ?? '';
                  String advice = adviceMatch?.group(1) ?? '';

                  // 如果提取的內容為空，嘗試直接從原始內容中提取
                  if (analysis.isEmpty && content.contains('"analysis"')) {
                    final directAnalysisMatch = analysisRegex.firstMatch(
                      content,
                    );
                    analysis = directAnalysisMatch?.group(1) ?? '';
                  }

                  if (advice.isEmpty && content.contains('"advice"')) {
                    final directAdviceMatch = adviceRegex.firstMatch(content);
                    advice = directAdviceMatch?.group(1) ?? '';
                  }

                  // 如果 advice 被截斷，添加一個提示
                  if (advice.isEmpty && content.contains('"advice"')) {
                    advice = '[內容被截斷]';
                  }

                  // 手動創建 JSON
                  parsedJson = {'analysis': analysis, 'advice': advice};

                  print('使用手動提取的欄位創建 JSON: $parsedJson');
                }
              }
            } else {
              // 如果無法使用正則表達式提取 JSON，嘗試直接從內容中提取欄位
              print('無法使用正則表達式提取 JSON，嘗試直接從內容中提取欄位');

              // 使用更寬鬆的正則表達式，可以匹配多行字符串
              final analysisRegex = RegExp(
                r'"analysis"\s*:\s*"([\s\S]*?)(?:"(?=\s*,|\s*})|$)',
              );
              final adviceRegex = RegExp(
                r'"advice"\s*:\s*"([\s\S]*?)(?:"(?=\s*})|$)',
              );

              final analysisMatch = analysisRegex.firstMatch(content);
              final adviceMatch = adviceRegex.firstMatch(content);

              String analysis = analysisMatch?.group(1) ?? '';
              String advice = adviceMatch?.group(1) ?? '';

              // 如果 advice 被截斷，添加一個提示
              if (advice.isEmpty && content.contains('"advice"')) {
                advice = '[內容被截斷]';
              }

              // 手動創建 JSON
              parsedJson = {'analysis': analysis, 'advice': advice};

              print('使用手動提取的欄位創建 JSON: $parsedJson');
            }
          }

          // 修復中文編碼問題
          Map<String, dynamic> fixedJson = {};
          parsedJson.forEach((key, value) {
            if (value is String) {
              // 嘗試修復亂碼
              final fixedValue = _fixChineseEncoding(value);
              fixedJson[key] = fixedValue;
              print('修復後的 $key: $fixedValue');
            } else {
              fixedJson[key] = value;
            }
          });

          return TranslationResult.fromJson(fixedJson);
        } catch (e) {
          print('JSON 處理過程中發生錯誤: $e');
          return TranslationResult.withError(
            '${AppStrings.errorResponseParsing}: 處理 JSON 時發生錯誤 - $e',
          );
        }
      } else if (response.statusCode == 401) {
        print('認證錯誤: API 金鑰無效或過期');
        return TranslationResult.withError(
          AppStrings.errorApiKeyMissing + AppStrings.errorApiKeyInvalid,
        );
      } else if (response.statusCode == 400) {
        print('請求錯誤: 請求格式或內容有問題');
        return TranslationResult.withError(
          '${AppStrings.errorApiRequest}${response.statusCode}: 請求格式或內容有問題\n${response.body}',
        );
      } else if (response.statusCode == 429) {
        print('請求頻率限制: 已達到 API 請求限制');
        return TranslationResult.withError(
          '${AppStrings.errorApiRequest}${response.statusCode}: 已達到 API 請求限制\n${response.body}',
        );
      } else if (response.statusCode >= 500) {
        print('伺服器錯誤: Anthropic API 伺服器問題');
        return TranslationResult.withError(
          '${AppStrings.errorApiRequest}${response.statusCode}: Anthropic API 伺服器問題\n${response.body}',
        );
      } else {
        print('未預期的回應狀態碼: ${response.statusCode}');
        return TranslationResult.withError(
          '${AppStrings.errorApiRequest}${response.statusCode}\n${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      // 網路連線錯誤
      print('網路連線錯誤: $e');

      // 檢查具體的錯誤類型
      final errorMessage = e.toString();
      if (errorMessage.contains('Connection refused')) {
        return TranslationResult.withError(
          '${AppStrings.errorNetworkConnection}: 連線被拒絕，請檢查網路設定',
        );
      } else if (errorMessage.contains('Connection timed out')) {
        return TranslationResult.withError(
          '${AppStrings.errorNetworkConnection}: 連線逾時，請檢查網路狀態',
        );
      } else if (errorMessage.contains('Operation not permitted')) {
        return TranslationResult.withError(
          '${AppStrings.errorNetworkConnection}: 操作不允許 (errno = 1)，請檢查應用程式網路權限',
        );
      } else if (errorMessage.contains('No address associated with hostname')) {
        return TranslationResult.withError(
          '${AppStrings.errorNetworkConnection}: 無法解析主機名稱，請檢查 DNS 設定',
        );
      } else {
        return TranslationResult.withError(
          '${AppStrings.errorNetworkConnection}: $e',
        );
      }
    } on FormatException catch (e) {
      // JSON 解析錯誤
      print('JSON 格式錯誤: $e');
      return TranslationResult.withError(
        '${AppStrings.errorResponseParsing}: $e',
      );
    } on SocketException catch (e) {
      // Socket 錯誤
      print('Socket 錯誤: $e');
      return TranslationResult.withError(
        '${AppStrings.errorNetworkConnection}: Socket 錯誤 - $e',
      );
    } catch (e) {
      // 其他未預期的錯誤
      print('未預期的錯誤: $e');
      return TranslationResult.withError('${AppStrings.errorGeneric}$e');
    }
  }

  String _fixChineseEncoding(String input) {
    // 如果輸入為空，直接返回
    if (input.isEmpty) return input;

    print('嘗試修復編碼: ${input.substring(0, min(50, input.length))}...');

    // 方法 1: 嘗試使用 UTF-8 重新編碼
    try {
      // 將字符串轉換為字節
      List<int> bytes = [];
      for (int i = 0; i < input.length; i++) {
        int code = input.codeUnitAt(i);
        if (code < 128) {
          // ASCII 字符直接添加
          bytes.add(code);
        } else {
          // 非 ASCII 字符可能需要特殊處理
          // 這裡我們嘗試將其視為 Latin-1 編碼的字節
          if (code <= 255) {
            bytes.add(code);
          } else {
            // 對於更大的代碼點，我們將其拆分為多個字節
            bytes.add(code >> 8);
            bytes.add(code & 0xFF);
          }
        }
      }

      // 嘗試使用 UTF-8 解碼
      String result = utf8.decode(bytes, allowMalformed: true);
      print('UTF-8 重新編碼結果: ${result.substring(0, min(50, result.length))}...');

      // 如果結果看起來合理（包含中文字符），則返回
      if (_containsChineseCharacters(result)) {
        return result;
      }
    } catch (e) {
      print('UTF-8 重新編碼失敗: $e');
    }

    // 方法 2: 嘗試使用 Latin-1 編碼後再用 UTF-8 解碼
    try {
      List<int> latin1Bytes = [];
      for (int i = 0; i < input.length; i++) {
        int code = input.codeUnitAt(i);
        if (code <= 255) {
          latin1Bytes.add(code);
        }
      }

      String result = utf8.decode(latin1Bytes, allowMalformed: true);
      print(
        'Latin-1 -> UTF-8 結果: ${result.substring(0, min(50, result.length))}...',
      );

      if (_containsChineseCharacters(result)) {
        return result;
      }
    } catch (e) {
      print('Latin-1 -> UTF-8 轉換失敗: $e');
    }

    // 方法 3: 嘗試使用 Big5 編碼（常用於繁體中文）
    try {
      // 這裡我們需要使用外部庫來處理 Big5 編碼
      // 由於無法直接在這裡實現，我們可以嘗試一些啟發式方法

      // 將連續的非 ASCII 字符視為可能的中文字符
      StringBuffer result = StringBuffer();
      int i = 0;
      while (i < input.length) {
        int code = input.codeUnitAt(i);
        if (code < 128) {
          // ASCII 字符直接添加
          result.writeCharCode(code);
          i++;
        } else if (i + 1 < input.length) {
          // 嘗試將兩個連續的非 ASCII 字符組合為一個中文字符
          int nextCode = input.codeUnitAt(i + 1);
          int combinedCode = (code << 8) | nextCode;

          // 中文字符的 Unicode 範圍大致在 0x4E00-0x9FFF
          if (combinedCode >= 0x4E00 && combinedCode <= 0x9FFF) {
            result.writeCharCode(combinedCode);
          } else {
            // 如果不在中文範圍內，則保持原樣
            result.writeCharCode(code);
          }
          i += 2;
        } else {
          result.writeCharCode(code);
          i++;
        }
      }

      String resultStr = result.toString();
      print('啟發式方法結果: ${resultStr.substring(0, min(50, resultStr.length))}...');

      if (_containsChineseCharacters(resultStr)) {
        return resultStr;
      }
    } catch (e) {
      print('啟發式方法失敗: $e');
    }

    // 如果所有方法都失敗，返回原始輸入
    return input;
  }

  bool _containsChineseCharacters(String input) {
    // 檢查字符串是否包含中文字符
    // 中文字符的 Unicode 範圍大致在 0x4E00-0x9FFF
    for (int i = 0; i < input.length; i++) {
      int code = input.codeUnitAt(i);
      if (code >= 0x4E00 && code <= 0x9FFF) {
        return true;
      }
    }
    return false;
  }
}
