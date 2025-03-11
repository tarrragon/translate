class PromptConfig {
  final String systemPrompt;

  PromptConfig({required this.systemPrompt});

  factory PromptConfig.fromJson(Map<String, dynamic> json) {
    return PromptConfig(systemPrompt: json['system_prompt'] as String);
  }
}
