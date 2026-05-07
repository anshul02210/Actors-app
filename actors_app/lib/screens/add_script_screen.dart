import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../widgets/background_pattern.dart';
import 'rehearsal_screen.dart';
import '../services/script_service.dart';

class AddScriptScreen extends StatefulWidget {
  const AddScriptScreen({super.key});

  @override
  State<AddScriptScreen> createState() => _AddScriptScreenState();
}

class _AddScriptScreenState extends State<AddScriptScreen> {
  final _titleController = TextEditingController();
  final _scriptTextController = TextEditingController();
  
  List<String> _detectedCharacters = [];
  String? _selectedCharacter;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _scriptTextController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'docx'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          _isLoading = true;
          // Set title as the filename automatically without the extension
          _titleController.text = result.files.single.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        });

        String rawText = '';
        final fileBytes = result.files.single.bytes;
        final path = result.files.single.path;
        final extension = result.files.single.extension?.toLowerCase();

        Uint8List? fileData = fileBytes;
        if (fileData == null && path != null) {
          fileData = await File(path).readAsBytes();
        }

        if (fileData != null) {
          if (extension == 'pdf') {
             rawText = await _extractPdfText(fileData);
          } else if (extension == 'txt') {
             rawText = utf8.decode(fileData);
          } else if (extension == 'docx') {
             rawText = await _extractDocxText(fileData);
          }
        }

        setState(() {
          _scriptTextController.text = rawText;
          _extractCharacters(rawText);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error analyzing file: $e'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String> _extractPdfText(Uint8List bytes) async {
    // Uses syncfusion_flutter_pdf
    PdfDocument document = PdfDocument(inputBytes: bytes);
    String text = PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  Future<String> _extractDocxText(Uint8List bytes) async {
    // A DOCX is a zip file. We use the archive package to extract word/document.xml
    Archive archive = ZipDecoder().decodeBytes(bytes);
    String rawXml = '';
    for (var file in archive) {
      if (file.name == 'word/document.xml') {
        final content = file.content as List<int>;
        rawXml = utf8.decode(content);
        break;
      }
    }
    
    // Strip XML tags using simple regex to recover just the plain text format
    final RegExp exp = RegExp(r'<[^>]*>', multiLine: true);
    String plainText = rawXml.replaceAll(exp, ' ');
    // Remove extra spaces
    return plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _extractCharacters(String text) {
     if (text.trim().isEmpty) {
       setState(() {
         _detectedCharacters = [];
         _selectedCharacter = null;
       });
       return;
     }

     Set<String> characters = {};

     // Format 1: Standard "CHARACTER: dialogue" format
     // Examples: "HAMLET:", "MR. SMITH:", "JULIET:"
    // Accept typical capitalized names (e.g. Arjun) and ALL-CAPS variants
    final standardRegex = RegExp(r"^([A-Za-z][A-Za-z0-9\s.\-']*?):(.+)$", multiLine: true);
     final standardMatches = standardRegex.allMatches(text);
     
     for (final match in standardMatches) {
       String charName = match.group(1)?.trim() ?? '';
       if (charName.length > 1 && charName.length < 50) {
         characters.add(charName);
       }
     }

     // Format 2: Screenplay format (CHARACTER on its own line, ALL CAPS)
     if (characters.isEmpty) {
       final lines = text.split('\n');
       for (final line in lines) {
         final trimmed = line.trim();
         if (trimmed == trimmed.toUpperCase() && 
             trimmed.length > 2 && 
             trimmed.length < 50 &&
             !trimmed.startsWith('(')) {
           characters.add(trimmed);
         }
       }
     }

     setState(() {
        _detectedCharacters = characters.toList()..sort();
        // Clear selection if the chosen character disappears
        if (_selectedCharacter != null && !_detectedCharacters.contains(_selectedCharacter)) {
          _selectedCharacter = null;
        }
     });
  }

  @override
  void initState() {
    super.initState();
    // Re-detect characters if they manually paste or type into the box!
    _scriptTextController.addListener(() {
      // Debounce this in a real app, but for now we'll do it instantly
      _extractCharacters(_scriptTextController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      body: Stack(
        children: [
          const Positioned.fill(child: BackgroundPattern()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Bar
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          mouseCursor: SystemMouseCursors.click,
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.08),
                            ),
                            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                      const Text(
                        'Add script',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Import File Box
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _isLoading ? null : _pickFile,
                      child: CustomPaint(
                        painter: _DashedRectPainter(
                          color: _isLoading ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.3),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isLoading)
                                const CircularProgressIndicator(color: Color(0xFFFFC107))
                              else ...[
                                const Icon(Icons.folder, color: Color(0xFFFFC107), size: 48),
                                const SizedBox(height: 16),
                                const Text(
                                  'Import file',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '.txt · .pdf · .docx supported',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or type it in',
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // SCRIPT TITLE
                  const Text(
                    'SCRIPT TITLE',
                    style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Hamlet Act II',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFFFC107)),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // PASTE SCRIPT TEXT
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SCRIPT TEXT', // renamed slightly to fit dynamic nature
                        style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      if (_scriptTextController.text.isNotEmpty)
                         Text(
                          '${_scriptTextController.text.length} characters',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                         )
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _scriptTextController,
                    maxLines: 8,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'Paste script text here... \nExample:\nHAMLET: To be or not to be...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFFC107)),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // DETECTED CHARACTERS
                  _detectedCharacters.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DETECTED CHARACTERS',
                              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _detectedCharacters.map((c) => _buildCharacterPill(c)).toList(),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                  
                  const SizedBox(height: 40),
                  
                  // Continue Button
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: OutlinedButton(
                      onPressed: (_selectedCharacter == null || _titleController.text.isEmpty || _scriptTextController.text.trim().isEmpty)
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);

                              setState(() => _isLoading = true);
                              try {
                                final scriptId = await ScriptService.saveScript(
                                  title: _titleController.text.trim(),
                                  subtitle: '${_detectedCharacters.length} active roles detected',
                                  fullText: _scriptTextController.text,
                                  characters: _detectedCharacters,
                                );

                                if (!mounted) {
                                  return;
                                }

                                await navigator.push(
                                  MaterialPageRoute(
                                    builder: (_) => RehearsalScreen(
                                      scriptId: scriptId,
                                      scriptTitle: _titleController.text.trim(),
                                      fullText: _scriptTextController.text,
                                      selectedCharacter: _selectedCharacter!,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Could not save script: $e'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                }
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white.withOpacity(0.03),
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue to role selection',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterPill(String name) {
    final isSelected = _selectedCharacter == name;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCharacter = name;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFC107) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.5)),
        ),
        child: Text(
          name,
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

class _DashedRectPainter extends CustomPainter {
  final Color color;

  _DashedRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    final RRect rrect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(16));
    
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
