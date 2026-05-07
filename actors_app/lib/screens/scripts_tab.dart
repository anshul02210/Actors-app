// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';

// import '../services/script_service.dart';
// import 'rehearsal_screen.dart';

// class ScriptsTab extends StatelessWidget {
//   const ScriptsTab({super.key});

//   List<String> _extractCharactersFromText(String text) {
//     final RegExp characterRegex = RegExp(r'^([A-Z\s\.]+)[\w\s]*:', multiLine: true);
//     final matches = characterRegex.allMatches(text);
//     final names = <String>{};

//     for (final match in matches) {
//       final String value = (match.group(1) ?? '').trim();
//       if (value.isNotEmpty && value.length < 30) {
//         names.add(value);
//       }
//     }

//     return names.toList()..sort();
//   }

//   Future<void> _openScript(
    import 'package:cloud_firestore/cloud_firestore.dart';
    import 'package:flutter/material.dart';

    import '../services/script_service.dart';
    import 'rehearsal_screen.dart';

    class ScriptsTab extends StatelessWidget {
      const ScriptsTab({super.key});

      List<String> _extractCharactersFromText(String text) {
final RegExp characterRegex = RegExp(
  r"^([A-Za-z][A-Za-z0-9\s.\-']*?):",
  multiLine: true,
);        final matches = characterRegex.allMatches(text);
        final names = <String>{};

        for (final match in matches) {
          final value = (match.group(1) ?? '').trim();
          if (value.isNotEmpty && value.length < 30) {
            names.add(value);
          }
        }

        return names.toList()..sort();
      }

      Future<void> _openScript(
        BuildContext context,
        String scriptId,
        String title,
        String fullText,
        List<String> characters,
      ) async {
        final picked = await showDialog<String>(
          context: context,
          builder: (dialogContext) {
            String? selectedCharacter = characters.isNotEmpty ? characters.first : null;

            return AlertDialog(
              backgroundColor: const Color(0xFF1B1D22),
              title: const Text('Choose your role', style: TextStyle(color: Colors.white)),
              content: StatefulBuilder(
                builder: (context, setModalState) {
                  return SizedBox(
                    width: 360,
                    child: characters.isEmpty
                        ? const Text('No characters were detected in this script.', style: TextStyle(color: Colors.white70))
                        : ListView(
                            shrinkWrap: true,
                            children: characters
                                .map(
                                  (role) => RadioListTile<String>(
                                    value: role,
                                    groupValue: selectedCharacter,
                                    activeColor: const Color(0xFFFFC107),
                                    title: Text(role, style: const TextStyle(color: Colors.white)),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setModalState(() => selectedCharacter = value);
                                      }
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                  );
                },
              ),
              actions: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: selectedCharacter == null ? null : () => Navigator.pop(dialogContext, selectedCharacter),
                    child: const Text('Start'),
                  ),
                ),
              ],
            );
          },
        );

        if (picked == null || !context.mounted) {
          return;
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RehearsalScreen(
              scriptId: scriptId,
              scriptTitle: title,
              fullText: fullText,
              selectedCharacter: picked,
            ),
          ),
        );
      }

      @override
      Widget build(BuildContext context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scripts',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/add_script'),
                      icon: const Icon(Icons.add, color: Color(0xFFFFC107)),
                      label: const Text('Add', style: TextStyle(color: Color(0xFFFFC107))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'All scripts from your account',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              ),
              const SizedBox(height: 24),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ScriptService.getUserScripts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? const [];
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.library_books_outlined, color: Colors.white70, size: 36),
                          const SizedBox(height: 12),
                          const Text(
                            'No scripts yet',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add your first script to begin rehearsing.',
                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final title = (data['title'] as String?)?.trim() ?? 'Untitled Script';
                      final subtitle = (data['subtitle'] as String?)?.trim() ?? '';
                      final fullText = (data['fullText'] as String?) ?? '';
                      final rawChars = (data['characters'] as List?)?.cast<String>() ?? const <String>[];
                      final characters = rawChars.isEmpty ? _extractCharactersFromText(fullText) : rawChars;
                      final createdAt = data['createdAt'];

                      final String createdLabel;
                      if (createdAt is Timestamp) {
                        final dt = createdAt.toDate();
                        createdLabel =
                            '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                      } else {
                        createdLabel = 'Recently added';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openScript(context, doc.id, title, fullText, characters),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFC107).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.description_outlined, color: Color(0xFFFFC107)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle.isEmpty
                                              ? '${characters.length} roles · $createdLabel'
                                              : '$subtitle · $createdLabel',
                                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.play_arrow_rounded, color: Color(0xFFFFC107)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    }
