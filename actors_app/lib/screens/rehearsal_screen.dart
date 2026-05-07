import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../widgets/background_pattern.dart';
import 'dart:math';
import 'dart:async';
import '../services/script_service.dart';

enum RehearsalState {
  aiSpeaking,
  userTurn,
  evaluation,
  finished
}

class ScriptLine {
  final String character;
  final String dialogue;
  final String? stageDirection; // e.g., "(Sighs)" or "(Abhi walked out after saying it)"
  final String dialogueClean; // dialogue without inline stage directions for TTS

  ScriptLine({
    required this.character,
    required this.dialogue,
    this.stageDirection,
    String? dialogueClean,
  }) : dialogueClean = dialogueClean ?? 
        dialogue.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '').trim();

  /// Extract stage directions from a line
  /// Returns first match like "(Sighs)" from "HAMLET: (Sighs) To be or not to be"
  static String? extractStageDirection(String text) {
    final match = RegExp(r'\(([^)]*)\)').firstMatch(text);
    return match != null ? '(${match.group(1)})' : null;
  }
}

class RehearsalScreen extends StatefulWidget {
  final String? scriptId;
  final String scriptTitle;
  final String fullText;
  final String selectedCharacter;

  const RehearsalScreen({
    super.key,
    this.scriptId,
    required this.scriptTitle,
    required this.fullText,
    required this.selectedCharacter,
  });

  @override
  State<RehearsalScreen> createState() => _RehearsalScreenState();
}

class _RehearsalScreenState extends State<RehearsalScreen> {
  // Parsed Script Data
  List<ScriptLine> _lines = [];
  int _currentLineIndex = 0;

  // State Machine
  RehearsalState _currentState = RehearsalState.aiSpeaking;
  // UI toggles
  bool _showMyLineDuringTurn = true;
  // Track whether TTS is actively speaking so UI can reflect true loading state
  bool _isAiSpeaking = false;
  
  // Settings & Toggles
  bool _isChallengeMode = false;
  double _ttsSpeed = 1.0;
  
  // Performance
  double _accuracyScore = 0.0;
  int _totalUserLines = 0;
  List<TextSpan> _evaluatedSpans = [];

  // Local Plugins (Piper / Whisper stubs using flutter generics)
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isSttInitialized = false;
  String _liveSpokenText = '';
  bool _isPaused = false;
  bool _hasStarted = false;
  DateTime? _sessionStartedAt;
  DateTime? _pauseStartedAt;
  Duration _totalPausedTime = Duration.zero;
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    _parseScript();
    _loadUserSettings();
    // Plugins will initialize when the user explicitly clicks Start
  }

  Future<void> _loadUserSettings() async {
    final settings = await ScriptService.getUserSettingsOnce();
    if (!mounted) {
      return;
    }

    final challengeMode = settings['challengeModeDefault'];
    final ttsSpeed = settings['preferredTtsSpeed'];

    setState(() {
      _isChallengeMode = challengeMode is bool ? challengeMode : false;
      _ttsSpeed = ttsSpeed is num ? ttsSpeed.toDouble() : 1.0;
    });
  }

  Future<void> _initPlugins() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(_ttsSpeed);
    
    // Setup completion handler to seamlessly transition the state machine
    _flutterTts.setCompletionHandler(() {
      // TTS finished speaking for this line
      setState(() {
        _isAiSpeaking = false;
      });
      _advanceStateMachine();
    });

    _isSttInitialized = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' && _currentState == RehearsalState.userTurn) {
          _evaluateSpokenLine();
        }
      },
      onError: (error) => debugPrint('STT Error: $error'),
    );

    // Start elapsed timer
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {}); // Trigger rebuild to update elapsed time display
    });

    // Kick off the first line
    _processStateForCurrentLine();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _parseScript() {
    final text = widget.fullText.trim();
    if (text.isEmpty) {
      setState(() {
        _lines = [ScriptLine(character: widget.selectedCharacter, dialogue: "Script is empty. Please provide a valid script.")];
      });
      return;
    }

    // Try multiple script format patterns (in priority order)
    List<ScriptLine> lines = [];

    // Format 1: Standard "CHARACTER: dialogue" format (handles inline stage directions)
    // Examples: "HAMLET: To be or not to be" or "HAMLET: (Sighs) To be or not to be"
    // Accept names like "Arjun", "Rahul", as well as ALL-CAPS names
    final standardRegex = RegExp(r"^([A-Za-z][A-Za-z0-9\s.\-']*?):(.+)$", multiLine: true);
    final standardMatches = standardRegex.allMatches(text);
    
    if (standardMatches.isNotEmpty) { // Accept even a single valid line now (relaxed from "> 2")
      for (final match in standardMatches) {
        String character = match.group(1)?.trim() ?? '';
        String dialogue = match.group(2)?.trim() ?? '';
        
        if (character.isNotEmpty && dialogue.isNotEmpty) {
          final stageDir = ScriptLine.extractStageDirection(dialogue);
          lines.add(ScriptLine(
            character: character,
            dialogue: dialogue,
            stageDirection: stageDir,
          ));
        }
      }
    }

    // Format 2: Screenplay format (CHARACTER centered, dialogue below)
    // This is more complex, so only attempt if Format 1 failed
    if (lines.isEmpty) {
      final screenplayLines = text.split('\n').where((l) => l.isNotEmpty).toList();
      for (int i = 0; i < screenplayLines.length - 1; i++) {
        final line = screenplayLines[i].trim();
        final nextLine = screenplayLines[i + 1].trim();
        
        // Check if line is ALL CAPS (potential character name) and next is dialogue
        if (line == line.toUpperCase() && 
            line.length > 2 && 
            line.length < 50 &&
            !nextLine.startsWith('(') && 
            nextLine.isNotEmpty) {
          final stageDir = ScriptLine.extractStageDirection(nextLine);
          lines.add(ScriptLine(
            character: line,
            dialogue: nextLine,
            stageDirection: stageDir,
          ));
        }
      }
    }

    // Fallback: if no lines parsed, show helpful message
    if (lines.isEmpty) {
      lines.add(ScriptLine(
        character: widget.selectedCharacter,
        dialogue: "Could not parse script. Supported formats:\n\n"
            "1. HAMLET: To be or not to be\n\n"
            "2. HAMLET: (Sighs) To be or not to be\n\n"
            "3. Screenplay format (CHARACTER on one line, dialogue below)\n\n"
            "Make sure character names start with a letter and are followed by a colon (:)"
      ));
    }

    setState(() {
      _lines = lines;
    });
  }

  Future<void> _processStateForCurrentLine() async {
    if (_currentLineIndex >= _lines.length) return;
    
    final currentLine = _lines[_currentLineIndex];
    
    setState(() {
      _evaluatedSpans = []; // Clear previous evaluations
      _liveSpokenText = ''; // Clear live mic buffer
    });

    if (currentLine.character != widget.selectedCharacter) {
      // STATE A: AI SPEAKING
      setState(() {
        _currentState = RehearsalState.aiSpeaking;
        _isAiSpeaking = true;
      });
      await _flutterTts.setSpeechRate(_ttsSpeed);
      
      // Use dialogueClean which already has stage directions removed
      String textToSpeak = currentLine.dialogueClean;
      
      await _flutterTts.speak(textToSpeak);
    } else {
      // STATE B: USER TURN
      setState(() {
         _currentState = RehearsalState.userTurn;
         _totalUserLines++;
      });
      if (_isSttInitialized) {
        _speechToText.listen(
          onResult: (result) {
            setState(() {
              _liveSpokenText = result.recognizedWords;
            });
            if (result.finalResult) {
               // isolate evaluator triggered externally
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3), // Trigger silence detection after 3 seconds
        );
      }
    }
  }

  void _togglePause() async {
    setState(() => _isPaused = !_isPaused);

    if (_isPaused) {
      _pauseStartedAt = DateTime.now();
      _flutterTts.stop();
      _speechToText.stop();
    } else {
      if (_pauseStartedAt != null) {
        _totalPausedTime += DateTime.now().difference(_pauseStartedAt!);
        _pauseStartedAt = null;
      }
      if (_currentState == RehearsalState.evaluation) {
         _advanceStateMachine();
      } else {
         _processStateForCurrentLine();
      }
    }
  }

  String _getElapsedTimeString() {
    if (_sessionStartedAt == null) return '00:00';
    final now = _isPaused && _pauseStartedAt != null ? _pauseStartedAt! : DateTime.now();
    final elapsed = now.difference(_sessionStartedAt!).inSeconds - _totalPausedTime.inSeconds;
    final minutes = elapsed ~/ 60;
    final seconds = elapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _restartRehearsal() async {
    _flutterTts.stop();
    _speechToText.stop();
    setState(() {
      _isPaused = false;
      _hasStarted = false; // Reset to the start gate
      _currentLineIndex = 0;
      _accuracyScore = 0.0;
      _totalUserLines = 0;
      _evaluatedSpans = [];
      _liveSpokenText = '';
    });
  }

  void _advanceStateMachine() {
    if (_isPaused) return; // Prevent state-machine from advancing if paused!
    if (_currentLineIndex < _lines.length - 1) {
      setState(() {
        _currentLineIndex++;
      });
      _processStateForCurrentLine();
    } else {
      // The scene is over! We hit the end of the script!
      setState(() => _currentState = RehearsalState.finished);
      _showCompletionReport();
    }
  }

  void _showCompletionReport() {
    final started = _sessionStartedAt;
    final duration = started == null
        ? 0
        : DateTime.now().difference(started).inSeconds.clamp(0, 86400);

    ScriptService.saveSession(
      scriptId: widget.scriptId ?? 'unsaved-script',
      scriptTitle: widget.scriptTitle,
      role: widget.selectedCharacter,
      accuracy: _accuracyScore,
      totalLines: _totalUserLines,
      durationSeconds: duration,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151821),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: const Color(0xFFFFC107).withOpacity(0.5))),
        title: const Text('Scene Complete! 🎬', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your Overall Accuracy:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            Text(
              '${(_accuracyScore * 100).toInt()}%',
              style: const TextStyle(color: Color(0xFFFFC107), fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Great job hitting your cues!', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _restartRehearsal();   // Take it from the top
            },
            child: const Text('Rehearse Again', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
            onPressed: () {
               // Pop all specific routes until we explicitly hit the root Dashboard!
               Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _evaluateSpokenLine() async {
    // STATE C: EVALUATION
    setState(() => _currentState = RehearsalState.evaluation);
    
    String spokenWords = _speechToText.lastRecognizedWords;
    String actualLine = _lines[_currentLineIndex].dialogueClean; // Use clean dialogue without stage directions
    
    // DART ISOLATE: Send heavy string comparison to background thread to preserve 60fps!
    final evaluationResult = await compute(_calculateLevenshteinIsolate, {
      'spoken': spokenWords,
      'actual': actualLine,
    });

    setState(() {
      _evaluatedSpans = evaluationResult['spans'] as List<TextSpan>;
      
      // Update running performance score
      double score = evaluationResult['score'] as double;
      // Rolling average
      _accuracyScore = ((_accuracyScore * (_totalUserLines - 1)) + score) / max(1, _totalUserLines);
    });

    // Barely wait so the AI responds instantly like a real scene-partner!
    await Future.delayed(const Duration(milliseconds: 400));
    _advanceStateMachine();
  }

  // A heavy processing function executed entirely on a background generic Isolate
  static Map<String, dynamic> _calculateLevenshteinIsolate(Map<String, String> data) {
    String spoken = (data['spoken'] ?? '').toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    String actual = (data['actual'] ?? '').toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    
    List<String> spokenWords = spoken.split(' ').where((w) => w.isNotEmpty).toList();
    List<String> actualWords = actual.split(' ').where((w) => w.isNotEmpty).toList();
    
    // Very simplified difference checker for visual UI demo:
    List<TextSpan> spans = [];
    int correctWords = 0;
    
    for (String targetWord in actualWords) {
      if (spokenWords.contains(targetWord)) {
        spans.add(TextSpan(text: '$targetWord ', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)));
        correctWords++;
        // Remove to prevent double counting
        spokenWords.removeAt(spokenWords.indexOf(targetWord));
      } else {
        // Here is where Soundex logic would determine if it's yellow/phonetic vs red
        spans.add(TextSpan(text: '$targetWord ', style: const TextStyle(color: Colors.redAccent, decoration: TextDecoration.lineThrough)));
      }
    }

    double localScore = actualWords.isEmpty ? 1.0 : (correctWords / actualWords.length);
    
    return {
      'spans': spans,
      'score': localScore,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      body: Stack(
        children: [
          const Positioned.fill(child: BackgroundPattern()),
          SafeArea(
            child: Column(
              children: [
                _buildHeaderBar(),
                _buildControlStrip(),
                const SizedBox(height: 16),
                
                // MAIN UI TRACKER
                Expanded(
                  child: !_hasStarted 
                    ? _buildPreRehearsalOverview()
                    : _lines.isEmpty 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFC107)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: _lines.length,
                        itemBuilder: (context, index) {
                           return _buildDialogueBlock(_lines[index], index);
                        },
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomStatusPanel(),
    );
  }

  Widget _buildPreRehearsalOverview() {
    if (_lines.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFC107)),
      );
    }

    // Count lines for each character
    int myLineCount = 0;
    int totalLines = _lines.length;
    final characterCounts = <String, int>{};

    for (final line in _lines) {
      characterCounts.update(line.character, (v) => v + 1, ifAbsent: () => 1);
      if (line.character == widget.selectedCharacter) {
        myLineCount++;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Scene Overview',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Your role stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFC107),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Playing ${widget.selectedCharacter}',
                      style: const TextStyle(color: Color(0xFFFFC107), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '$myLineCount Lines',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'You speak in ${((myLineCount / totalLines) * 100).toStringAsFixed(0)}% of the scene',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // All characters in scene
          const Text(
            'Scene Cast',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          ...characterCounts.entries.map((entry) {
            final isYourRole = entry.key == widget.selectedCharacter;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      color: isYourRole ? const Color(0xFFFFC107) : Colors.white70,
                      fontSize: 14,
                      fontWeight: isYourRole ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${entry.value} lines',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 32),

          // Start button
          ElevatedButton.icon(
            icon: const Icon(Icons.mic, color: Colors.black),
            label: const Text('START SCENE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              textStyle: const TextStyle(fontSize: 18),
            ),
            onPressed: () {
              setState(() => _hasStarted = true);
              _sessionStartedAt = DateTime.now();
              _initPlugins();
            },
          ),

          const SizedBox(height: 16),

          // Preview script button
          OutlinedButton.icon(
            icon: const Icon(Icons.preview, color: Color(0xFFFFC107)),
            label: const Text('Preview Full Script', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFC107))),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              side: const BorderSide(color: Color(0xFFFFC107), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: const Color(0xFF151821),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Full Script Preview',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              child: Icon(Icons.close, color: Colors.white.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _lines.map((line) {
                              final isYourLine = line.character == widget.selectedCharacter;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.character,
                                      style: TextStyle(
                                        color: isYourLine ? const Color(0xFFFFC107) : Colors.white54,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (line.stageDirection != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          line.stageDirection!,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.4),
                                            fontStyle: FontStyle.italic,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        line.dialogue,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC107),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDialogueBlock(ScriptLine line, int index) {
    bool isMyRole = line.character == widget.selectedCharacter;
    bool isActiveLine = index == _currentLineIndex;
    
    return Opacity(
      opacity: isActiveLine ? 1.0 : 0.4,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: isActiveLine ? const EdgeInsets.all(16) : null,
        decoration: isActiveLine ? BoxDecoration(
          color: isMyRole ? const Color(0xFFFFC107).withOpacity(0.05) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMyRole ? const Color(0xFFFFC107).withOpacity(0.3) : Colors.white.withOpacity(0.2)),
        ) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Character name + line counter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  line.character,
                  style: TextStyle(
                    color: isMyRole ? const Color(0xFFFFC107) : Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                if (isActiveLine)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Line ${index + 1} of ${_lines.length}',
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Stage direction (if any) - displayed in italics and muted
            if (line.stageDirection != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  line.stageDirection!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            
            // Core Display Logic for lines
            // If user is currently in 'userTurn' allow showing their line (configurable)
            if (isActiveLine && isMyRole && _currentState == RehearsalState.userTurn && _showMyLineDuringTurn)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  line.dialogue,
                  style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
                ),
              )
            else if (isActiveLine && isMyRole && _currentState == RehearsalState.evaluation && _evaluatedSpans.isNotEmpty)
              // EVALUATION DISPLAY
              RichText(text: TextSpan(children: _evaluatedSpans, style: const TextStyle(fontSize: 18, height: 1.5)))
            
            else if (isActiveLine && isMyRole && _currentState == RehearsalState.userTurn)
              // RECORDING FEEDBACK DISPLAY (LIVE)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE57373).withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE57373).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.mic, color: Color(0xFFE57373), size: 16),
                        SizedBox(width: 8),
                        Text('Recording...', style: TextStyle(color: Color(0xFFE57373), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _liveSpokenText.isEmpty ? 'Waiting for you to speak...' : _liveSpokenText, 
                      style: TextStyle(
                         color: _liveSpokenText.isEmpty ? Colors.white30 : Colors.white, 
                         fontSize: 18, 
                         fontStyle: _liveSpokenText.isEmpty ? FontStyle.italic : FontStyle.normal,
                         height: 1.5,
                      ),
                    ),
                  ],
                ),
              )

            else if (isMyRole && _isChallengeMode && (!isActiveLine || _currentState == RehearsalState.userTurn))
              // CHALLENGE MODE (Hidden until tap)
              GestureDetector(
                onTap: () {
                  // Reveal line temporarily or show in dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF151821),
                      title: const Text('Your Line', style: TextStyle(color: Colors.white)),
                      content: Text(line.dialogue, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Got it!', style: TextStyle(color: Color(0xFFFFC107))),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Tap to reveal your line...', style: TextStyle(color: Colors.white30, fontStyle: FontStyle.italic)),
                ),
              )
              
            else
              // STANDARD DISPLAY
              Text(
                line.dialogue,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)),
              child: const Icon(Icons.close, color: Colors.white, size: 24),
            ),
          ),
          Column(
            children: [
              const Text('REHEARSAL', style: TextStyle(color: Color(0xFFFFC107), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
              Text(widget.scriptTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          // Elapsed time display
          if (_hasStarted)
            Column(
              children: [
                const Text('TIME', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Text(
                  _getElapsedTimeString(),
                  style: TextStyle(
                    color: _isPaused ? Colors.white54 : const Color(0xFFFFC107),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            )
          else
            const SizedBox(width: 40), // Spacer balancing
        ],
      ),
    );
  }

  Widget _buildControlStrip() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_off, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              const Text('Challenge Mode', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Switch(
                value: _isChallengeMode,
                onChanged: (val) => setState(() => _isChallengeMode = val),
                activeThumbColor: const Color(0xFFFFC107),
              ),
              const SizedBox(width: 12),
              // Toggle to show user's line while speaking
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
                  icon: Icon(_showMyLineDuringTurn ? Icons.visibility : Icons.visibility_off, color: Colors.white54, size: 18),
                  tooltip: _showMyLineDuringTurn ? 'Hide your line while speaking' : 'Show your line while speaking',
                  onPressed: () => setState(() => _showMyLineDuringTurn = !_showMyLineDuringTurn),
                ),
              ),
            ],
          ),
          
          // Performance Meter snippet
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(
              '${(_accuracyScore * 100).toInt()}% ACC',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBottomStatusPanel() {
    String statusText;
    Color statusColor;
    
    if (_isPaused) {
      statusText = 'PAUSED';
      statusColor = Colors.white54;
    } else {
      switch (_currentState) {
        case RehearsalState.aiSpeaking:
          statusText = 'AI Speaking...';
          statusColor = Colors.blueAccent;
          break;
        case RehearsalState.userTurn:
          statusText = 'Listening... Say your line!';
          statusColor = const Color(0xFFE57373); // Red recording
          break;
        case RehearsalState.evaluation:
          statusText = 'Evaluating accuracy...';
          statusColor = Colors.purpleAccent;
          break;
        case RehearsalState.finished:
          statusText = 'SCENE COMPLETE 🎬';
          statusColor = const Color(0xFFFFC107);
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Playback speed slider
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Text('TTS Speed: ${_ttsSpeed.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                       Slider(
                         value: _ttsSpeed,
                         min: 0.5,
                         max: 2.0,
                         divisions: 3,
                         activeColor: Colors.white54,
                         onChanged: (val) {
                           setState(() => _ttsSpeed = val);
                           _flutterTts.setSpeechRate(val);
                         },
                       ),
                    ],
                  ),
                ),
                
                // Advanced Media Controls
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.restart_alt, color: Colors.white70),
                      onPressed: _restartRehearsal,
                      tooltip: 'Restart Scene',
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      mini: true,
                      backgroundColor: _isPaused ? Colors.white : const Color(0xFFFFC107),
                      onPressed: _togglePause,
                      child: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Status Engine Indicator Full Width
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isPaused && _currentState == RehearsalState.userTurn)
                    const Icon(Icons.mic, color: Color(0xFFE57373), size: 16)
                  else if (!_isPaused && _isAiSpeaking)
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: statusColor, strokeWidth: 2))
                  else if (!_isPaused)
                    const Icon(Icons.check_circle_outline, color: Colors.white54, size: 16)
                  else
                    const Icon(Icons.pause, color: Colors.white54, size: 16),
                    
                  const SizedBox(width: 8),
                  Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
