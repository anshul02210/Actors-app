import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Utility class for accessing environment variables
class EnvConfig {
  static String? _aiKey;

  /// Initialize environment variables from .env file
  static Future<void> init() async {
    await dotenv.load(fileName: '.env');
    _aiKey = dotenv.env['AI_KEY'];
    
    if (_aiKey == null || _aiKey!.isEmpty) {
      throw Exception('AI_KEY not found in .env file');
    }
  }

  /// Get the OpenAI API key
  static String get aiKey {
    if (_aiKey == null || _aiKey!.isEmpty) {
      throw Exception('AI_KEY not initialized. Call EnvConfig.init() first.');
    }
    return _aiKey!;
  }

  /// Check if configuration is initialized
  static bool get isInitialized => _aiKey != null && _aiKey!.isNotEmpty;
}
