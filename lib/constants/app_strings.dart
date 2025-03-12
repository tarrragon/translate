class AppStrings {
  // App-wide
  static const appTitle = '忠告';

  // Translator Screen
  static const inputLabel = '輸入文字';
  static const setApiKeyButton = '設定 API Key';
  static const generateButton = '生成翻譯';
  static const pleaseInputText = '輸入文字並點擊生成翻譯';
  static const pleaseSetApiKey = '請先設定 API Key';
  static const errorPrefix = '錯誤: ';

  // API Key Dialog
  static const apiKeyDialogTitle = '設定 Claude API Key';
  static const apiKeyLabel = 'API Key';
  static const cancelButton = '取消';
  static const saveButton = '儲存';

  // Translation Card
  static const cardTitle = '笨蛋呢，看著前方卻想著後方';
  static const analysisTitle = '深層分析';
  static const adviceTitle = '建議回應';
  static const copyButton = '複製';
  static const pasteButton = '貼上';

  // 錯誤訊息
  static const errorApiNotInitialized = 'API 服務尚未初始化，請先設定您的 API 金鑰';
  static const errorApiKeyMissing = 'API 金鑰未設定，請在設定中添加您的 Claude API 金鑰';
  static const errorApiRequest = 'API 請求失敗：';
  static const errorResponseParsing = '無法解析 API 回應，請稍後再試';
  static const errorGeneric = '發生錯誤：';
  static const errorNetworkConnection = '網路連線異常，請檢查您的網路設定';
  static const errorUnknown = '未知原因';
  static const errorApiKeyInvalid = 'API 金鑰無效，請檢查您的 API 金鑰';

  // API 金鑰相關錯誤
  static const errorApiKeyLoading = '無法載入 API 金鑰：';
  static const errorApiKeyEmpty = 'API 金鑰不能為空';
  static const errorApiKeySaving = '儲存 API 金鑰時發生錯誤：';
  static const errorApiKeyClearing = '清除 API 金鑰時發生錯誤：';

  // 配置文件錯誤
  static const errorConfigEmpty = 'API 配置文件為空';
  static const errorConfigIncomplete = 'API 配置文件缺少必要欄位';
  static const errorConfigFormat = 'API 配置文件格式錯誤：';
  static const errorConfigFile = 'API 配置文件讀取失敗：';
  static const errorConfigLoading = '載入 API 配置時發生錯誤：';

  // 提示文件錯誤
  static const errorPromptEmpty = '提示配置文件為空';
  static const errorPromptIncomplete = '提示配置文件缺少必要欄位';
  static const errorPromptFormat = '提示配置文件格式錯誤：';
  static const errorPromptFile = '提示配置文件讀取失敗：';
  static const errorPromptLoading = '載入提示配置時發生錯誤：';
}
