import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/app_state.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../widgets/background_pattern.dart';
import 'dart:math';

enum RehearsalState {
  aiSpeaking,
  userTurn,
  evaluation,
  finished
}

class ScriptLine {
  final String character;
  final String dialogue;

  ScriptLine({required this.character, required this.dialogue});
}

class RehearsalScreen extends StatefulWidget {
  final String scriptTitle;
  final String fullText;
  final String selectedCharacter;

  const RehearsalScreen({
    super.key,
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

  @override
  void initState() {
    super.initState();
    _parseScript();
    // Plugins will initialize when the user explicitly clicks Start
  }

  Future<void> _initPlugins() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(_ttsSpeed);
    
    // Setup completion handler to seamlessly transition the state machine
    _flutterTts.setCompletionHandler(() {
      _advanceStateMachine();
    });

    _isSttInitialized = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' && _currentState == RehearsalState.userTurn) {
          _evaluateSpokenLine();
        }
      },
      onError: (error) => print('STT Error: $error'),
    );

    // Kick off the first line
    _processStateForCurrentLine();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    super.dispose();
  }

  void _parseScript() {
    final RegExp exp = RegExp(r'^([A-Z\s\.]+):(.*)$', multiLine: true);
    final Iterable<RegExpMatch> matches = exp.allMatches(widget.fullText);
    
    List<ScriptLine> lines = [];
    for (final match in matches) {
      String character = match.group(1)?.trim() ?? '';
      String dialogue = match.group(2)?.trim() ?? '';
      if (character.isNotEmpty && dialogue.isNotEmpty) {
        lines.add(ScriptLine(character: character, dialogue: dialogue));
      }
    }
    
    if (lines.isEmpty) {
      lines.add(ScriptLine(character: widget.selectedCharacter, dialogue: "Could not parse standard script format. Make sure characters are in ALL CAPS followed by a colon."));
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
      setState(() => _currentState = RehearsalState.aiSpeaking);
      await _flutterTts.setSpeechRate(_ttsSpeed);
      
      // Strip out stage directions like (Sighs) or [Angry] so the TTS doesn't read them aloud!
      String textToSpeak = currentLine.dialogue.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '').trim();
      
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
      _flutterTts.stop();
      _speechToText.stop();
    } else {
      if (_currentState == RehearsalState.evaluation) {
         _advanceStateMachine();
      } else {
         _processStateForCurrentLine();
      }
    }
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
    // Save to global state so Dashboard can pick it up!
    AppState.recentScriptTitle = widget.scriptTitle;
    AppState.recentRole = widget.selectedCharacter;
    AppState.recentAccuracy = _accuracyScore;
    AppState.recentTotalLines = _totalUserLines;
    AppState.recentFullText = widget.fullText;

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
    String actualLine = _lines[_currentLineIndex].dialogue;
    
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
                    ? Center(
                        child: ElevatedButton.icon(
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
                            _initPlugins(); // This anchors the mic permission prompt to a physical click!
                          },
                        ),
                      )
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
            Text(
              line.character,
              style: TextStyle(
                color: isMyRole ? const Color(0xFFFFC107) : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            
            // Core Display Logic for lines
            if (isActiveLine && isMyRole && _currentState == RehearsalState.evaluation && _evaluatedSpans.isNotEmpty)
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
                      ),
                    ),
                  ],
                ),
              )

            else if (isMyRole && _isChallengeMode && (!isActiveLine || _currentState == RehearsalState.userTurn))
              // CHALLENGE MODE (Hidden)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('Tap to reveal line...', style: TextStyle(color: Colors.white30, fontStyle: FontStyle.italic)),
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
                activeColor: const Color(0xFFFFC107),
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
                  else if (!_isPaused)
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: statusColor, strokeWidth: 2))
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
