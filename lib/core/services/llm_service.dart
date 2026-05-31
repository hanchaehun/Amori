import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class LlmService {
  LlmService._();

  static Future<String> chat({
    required String systemPrompt,
    required String userMessage,
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.groqBaseUrl}/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${AppConfig.groqApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': AppConfig.groqModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Groq API error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes))
        as Map<String, dynamic>;
    return data['choices'][0]['message']['content'] as String;
  }
}
