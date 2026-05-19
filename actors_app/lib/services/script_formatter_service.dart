import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model to represent a formatted script line with emotional context
class DialogueLine {
  final String character;
  final String dialogue;
  final String? emotion; // e.g., "happy", "angry", "confused"
  final String? emotionDescription; // e.g., "Say this with excitement and joy"
  final String? stageDirection; // e.g., "(enters from left)" or "(pauses)"

  DialogueLine({
    required this.character,
    required this.dialogue,
    this.emotion,
    this.emotionDescription,
    this.stageDirection,
  });

  Map<String, dynamic> toJson() {
    return {
      'character': character,
      'dialogue': dialogue,
      'emotion': emotion,
      'emotionDescription': emotionDescription,
      'stageDirection': stageDirection,
    };
  }

  factory DialogueLine.fromJson(Map<String, dynamic> json) {
    return DialogueLine(
      character: json['character'] as String,
      dialogue: json['dialogue'] as String,
      emotion: json['emotion'] as String?,
      emotionDescription: json['emotionDescription'] as String?,
      stageDirection: json['stageDirection'] as String?,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    if (stageDirection != null) {
      buffer.writeln(stageDirection);
    }
    buffer.write('$character: $dialogue');
    if (emotionDescription != null) {
      buffer.write('\n  [${emotionDescription!}]');
    }
    return buffer.toString();
  }
}

/// Model for formatted script
class FormattedScript {
  final String title;
  final List<String> characters;
  final List<DialogueLine> lines;
  final String summary;

  FormattedScript({
    required this.title,
    required this.characters,
    required this.lines,
    required this.summary,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'characters': characters,
      'lines': lines.map((l) => l.toJson()).toList(),
      'summary': summary,
    };
  }

  factory FormattedScript.fromJson(Map<String, dynamic> json) {
    return FormattedScript(
      title: json['title'] as String,
      characters: List<String>.from(json['characters'] as List),
      lines: (json['lines'] as List)
          .map((l) => DialogueLine.fromJson(l as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] as String,
    );
  }
}

/// Service for formatting scripts using OpenAI API
class ScriptFormatterService {
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  static const int maxEstimatedPromptTokens = 100000;
  final String _apiKey;

  ScriptFormatterService({required String apiKey}) : _apiKey = apiKey;

  /// Formats raw script text into standardized format with emotional cues
  Future<FormattedScript> formatScript({
    required String rawScriptText,
    required String scriptTitle,
  }) async {
    try {
      validateScriptSize(
        rawScriptText: rawScriptText,
        scriptTitle: scriptTitle,
      );

      final prompt = _buildFormattingPrompt(rawScriptText, scriptTitle);

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'temperature': 0.7,
          'messages': [
            {
              'role': 'system',
              'content': '''You are an expert script editor and drama coach. Your task is to:
1. Parse any script format (dialogue-heavy, screenplay, stage play, novel excerpt, etc.)
2. Extract and standardize the script into a clear format
3. Identify emotional context and delivery instructions for each line of dialogue
4. Extract character names and create a character list
5. Return the result as valid JSON

Be thorough in extracting emotional cues and provide specific, actionable delivery instructions.'''
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'API Error: ${response.statusCode} - ${response.body}',
        );
      }

      final jsonResponse = jsonDecode(response.body);
      final content = jsonResponse['choices'][0]['message']['content'] as String;

      // Extract JSON from response (may be wrapped in markdown code blocks)
      final jsonContent = _extractJsonFromResponse(content);

      return FormattedScript.fromJson(jsonDecode(jsonContent));
    } catch (e) {
      throw Exception('Failed to format script: $e');
    }
  }

  /// Estimates whether a script fits within the formatting request budget.
  static int estimatePromptTokens({
    required String rawScriptText,
    required String scriptTitle,
  }) {
    final prompt = _buildFormattingPrompt(rawScriptText, scriptTitle);
    return (prompt.length / 4).ceil();
  }

  /// Throws a clear error before we send an oversized request to the API.
  static void validateScriptSize({
    required String rawScriptText,
    required String scriptTitle,
  }) {
    final estimatedTokens = estimatePromptTokens(
      rawScriptText: rawScriptText,
      scriptTitle: scriptTitle,
    );

    if (estimatedTokens > maxEstimatedPromptTokens) {
      throw ScriptTooLargeException(
        estimatedTokens: estimatedTokens,
        maxTokens: maxEstimatedPromptTokens,
      );
    }
  }

  /// Extracts emotional analysis for a single line
  Future<Map<String, String>> analyzeLineEmotion(
    String character,
    String dialogue,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4-turbo',
          'temperature': 0.7,
          'messages': [
            {
              'role': 'system',
              'content': '''You are an acting coach. Analyze dialogue and provide:
1. Primary emotion (anger, joy, sadness, fear, confusion, love, etc.)
2. A specific delivery instruction for how to say this line
3. Any subtext or hidden meaning

Respond ONLY with valid JSON: {"emotion": "...", "instruction": "..."}'''
            },
            {
              'role': 'user',
              'content':
                  'Character: $character\nDialogue: "$dialogue"\n\nWhat emotion should this be delivered with, and how should the actor say it?',
            }
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('API Error: ${response.statusCode}');
      }

      final jsonResponse = jsonDecode(response.body);
      final content = jsonResponse['choices'][0]['message']['content'] as String;
      final jsonContent = _extractJsonFromResponse(content);

      final analysis = jsonDecode(jsonContent);
      return {
        'emotion': analysis['emotion'] as String? ?? 'neutral',
        'instruction': analysis['instruction'] as String? ?? 'Deliver naturally',
      };
    } catch (e) {
      return {
        'emotion': 'neutral',
        'instruction': 'Deliver naturally',
      };
    }
  }

  /// Extracts JSON from a response that may contain markdown code blocks
  String _extractJsonFromResponse(String content) {
    // Remove markdown code blocks if present
    String cleaned = content.replaceAll(RegExp(r'```json\n?'), '');
    cleaned = cleaned.replaceAll(RegExp(r'```\n?'), '');
    return cleaned.trim();
  }

  /// Builds the prompt for script formatting
  static String _buildFormattingPrompt(String rawScript, String title) {
    return '''Please format and analyze this script text.

Script Title: "$title"

Raw Script Text:
---
$rawScript
---

Please:
1. Parse this script regardless of its format
2. Extract all character names
3. Identify all dialogue lines and who speaks them
4. Extract stage directions and scene information
5. For EACH dialogue line, analyze the emotional context and provide a delivery instruction
6. Return ONLY valid JSON with this structure:

{
  "title": "$title",
  "characters": ["Character1", "Character2", ...],
  "lines": [
    {
      "character": "CharacterName",
      "dialogue": "The actual dialogue text",
      "emotion": "primary emotion (e.g., angry, joyful, confused)",
      "emotionDescription": "A specific delivery instruction like 'Say this angrily with frustration' or 'Pause before saying this nervously'",
      "stageDirection": "Any stage directions or scene info, or null if none"
    },
    ...
  ],
  "summary": "A brief 1-2 sentence summary of the scene or script"
}

Be thorough and creative with emotional descriptions to help actors deliver authentic performances.''';
  }
}

class ScriptTooLargeException implements Exception {
  final int estimatedTokens;
  final int maxTokens;

  ScriptTooLargeException({
    required this.estimatedTokens,
    required this.maxTokens,
  });

  String get message =>
      'This script is too large to format in one AI request. Estimated size: $estimatedTokens tokens. Limit: $maxTokens tokens. Split the script into smaller sections and try again.';

  @override
  String toString() => message;
}
