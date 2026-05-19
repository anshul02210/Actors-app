import 'package:flutter/material.dart';
import '../services/script_formatter_service.dart';
import '../services/env_config.dart';
import '../widgets/background_pattern.dart';

class ScriptFormattingPreviewScreen extends StatefulWidget {
  final String rawScriptText;
  final String scriptTitle;
  final Function(FormattedScript) onFormatted;

  const ScriptFormattingPreviewScreen({
    super.key,
    required this.rawScriptText,
    required this.scriptTitle,
    required this.onFormatted,
  });

  @override
  State<ScriptFormattingPreviewScreen> createState() =>
      _ScriptFormattingPreviewScreenState();
}

class _ScriptFormattingPreviewScreenState
    extends State<ScriptFormattingPreviewScreen> {
  late ScriptFormatterService _formatterService;
  FormattedScript? _formattedScript;
  String? _error;
  bool _isLoading = true;
  bool _isWarning = false;
  String? _selectedCharacter;

  @override
  void initState() {
    super.initState();
    _initAndFormat();
  }

  Future<void> _initAndFormat() async {
    setState(() => _isLoading = true);
    try {
      if (!EnvConfig.isInitialized) {
        await EnvConfig.init();
      }
    } catch (e) {
      setState(() {
        _error = 'AI_KEY not configured. Add AI_KEY to your .env file and restart the app.';
        _isLoading = false;
      });
      return;
    }

    _formatterService = ScriptFormatterService(apiKey: EnvConfig.aiKey);
    await _formatScript();
  }

  Future<void> _formatScript() async {
    try {
      setState(() => _isLoading = true);

      ScriptFormatterService.validateScriptSize(
        rawScriptText: widget.rawScriptText,
        scriptTitle: widget.scriptTitle,
      );

      final formatted = await _formatterService.formatScript(
        rawScriptText: widget.rawScriptText,
        scriptTitle: widget.scriptTitle,
      );
      setState(() {
        _formattedScript = formatted;
        _isWarning = false;
        _isLoading = false;
      });
    } on ScriptTooLargeException catch (e) {
      setState(() {
        _error = e.message;
        _isWarning = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error formatting script: $e';
        _isWarning = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Script Preview with Emotional Cues'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          const BackgroundPattern(),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFFC107)),
                  SizedBox(height: 16),
                  Text(
                    'Formatting script with AI...',
                    style: TextStyle(color: Colors.white70),
                  )
                ],
              ),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isWarning ? Icons.warning_amber_rounded : Icons.error_outline,
                      color: _isWarning ? Colors.amber : Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isWarning ? Colors.amber : Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isWarning ? () => Navigator.pop(context) : _formatScript,
                      child: Text(_isWarning ? 'Back' : 'Retry'),
                    )
                  ],
                ),
              ),
            )
          else if (_formattedScript != null)
            _buildFormattedScriptView(_formattedScript!)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildFormattedScriptView(FormattedScript script) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  script.title,
                  style: const TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    script.summary,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Characters
                Text(
                  'Characters: ${script.characters.join(", ")}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 24),
                // Dialogue lines with emotional cues
                Text(
                  'Script with Emotional Directions:',
                  style: const TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...script.lines.map((line) => _buildDialogueLine(line)),
              ],
            ),
          ),
        ),
        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Character selection
              if (_formattedScript != null && _formattedScript!.characters.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Your Role',
                      style: TextStyle(
                        color: Color(0xFFFFC107),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _formattedScript!.characters
                          .map((char) => _buildCharacterPill(char))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: (_selectedCharacter == null)
                        ? null
                        : () {
                            Navigator.pop(context, {
                              'script': _formattedScript!,
                              'character': _selectedCharacter!,
                            });
                          },
                    icon: const Icon(Icons.check),
                    label: const Text('Continue to Rehearsal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedCharacter == null
                          ? Colors.grey[600]
                          : const Color(0xFFFFC107),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDialogueLine(DialogueLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stage direction if present
          if (line.stageDirection != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                line.stageDirection!,
                style: const TextStyle(
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ),
          // Character name
          Text(
            line.character,
            style: const TextStyle(
              color: Color(0xFFFFC107),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          // Dialogue
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              '"${line.dialogue}"',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          // Emotional direction
          if (line.emotionDescription != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A52).withOpacity(0.6),
                  border: Border(
                    left: BorderSide(
                      color: _getEmotionColor(line.emotion),
                      width: 3,
                    ),
                  ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    _getEmotionIcon(line.emotion),
                    color: _getEmotionColor(line.emotion),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.emotion ?? 'Neutral',
                          style: TextStyle(
                            color: _getEmotionColor(line.emotion),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          line.emotionDescription!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getEmotionColor(String? emotion) {
    switch (emotion?.toLowerCase()) {
      case 'angry':
      case 'rage':
      case 'furious':
        return Colors.red;
      case 'sad':
      case 'sorrowful':
      case 'depressed':
        return Colors.blue;
      case 'happy':
      case 'joyful':
      case 'excited':
        return Colors.green;
      case 'confused':
      case 'uncertain':
        return Colors.orange;
      case 'scared':
      case 'fearful':
      case 'terrified':
        return Colors.purple;
      case 'in love':
      case 'romantic':
      case 'tender':
        return Colors.pink;
      default:
        return Colors.white54;
    }
  }

  IconData _getEmotionIcon(String? emotion) {
    switch (emotion?.toLowerCase()) {
      case 'angry':
      case 'rage':
      case 'furious':
        return Icons.sentiment_very_dissatisfied;
      case 'sad':
      case 'sorrowful':
      case 'depressed':
        return Icons.sentiment_dissatisfied;
      case 'happy':
      case 'joyful':
      case 'excited':
        return Icons.sentiment_very_satisfied;
      case 'confused':
      case 'uncertain':
        return Icons.help;
      case 'scared':
      case 'fearful':
      case 'terrified':
        return Icons.warning;
      case 'in love':
      case 'romantic':
      case 'tender':
        return Icons.favorite;
      default:
        return Icons.info;
    }
  }

  Widget _buildCharacterPill(String character) {
    final isSelected = _selectedCharacter == character;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCharacter = character;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFC107) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFC107)
                : const Color(0xFFFFC107).withOpacity(0.5),
          ),
        ),
        child: Text(
          character,
          style: TextStyle(
            color: isSelected ? Colors.black : const Color(0xFFFFC107),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
