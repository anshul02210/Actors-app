import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/script_service.dart';

class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Progress',
            style: TextStyle(
              fontFamily: 'Georgia',
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Live rehearsal performance from your saved sessions',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: ScriptService.getUserSessions(limit: 60),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                  ),
                );
              }

              final sessions = snapshot.data?.docs ?? const [];
              if (sessions.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.insights_outlined, color: Colors.white70, size: 36),
                      const SizedBox(height: 12),
                      const Text(
                        'No session history yet',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Complete a rehearsal to start seeing your progress trends.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),
                );
              }

              final accuracies = sessions
                  .take(7)
                  .map((doc) => ((doc.data()['accuracy'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0))
                  .toList()
                  .reversed
                  .toList();

              final averageAccuracy =
                  sessions.map((doc) => ((doc.data()['accuracy'] as num?)?.toDouble() ?? 0.0)).fold<double>(0, (a, b) => a + b) /
                      math.max(1, sessions.length);

              final Map<String, List<double>> byScript = <String, List<double>>{};
              for (final doc in sessions) {
                final data = doc.data();
                final title = (data['scriptTitle'] as String?)?.trim();
                if (title == null || title.isEmpty) {
                  continue;
                }
                byScript.putIfAbsent(title, () => <double>[]).add(((data['accuracy'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0));
              }

              final scriptRows = byScript.entries.map((entry) {
                final avg = entry.value.fold<double>(0, (a, b) => a + b) / math.max(1, entry.value.length);
                return _ScriptProgress(
                  title: entry.key,
                  averageAccuracy: avg,
                  sessions: entry.value.length,
                );
              }).toList()
                ..sort((a, b) => b.averageAccuracy.compareTo(a.averageAccuracy));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Accuracy trend', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text(
                              '${(averageAccuracy * 100).toStringAsFixed(0)}% avg',
                              style: const TextStyle(
                                color: Color(0xFFFFC107),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 110,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _SessionLineChartPainter(values: accuracies),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Oldest', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                            Text('Newest', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'By script',
                    style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 16),
                  ...scriptRows.map(_buildScriptProgressCard),
                  const SizedBox(height: 20),
                  const Text(
                    'Recent sessions',
                    style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      children: sessions.take(8).toList().asMap().entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value.data();
                        final title = (data['scriptTitle'] as String?) ?? 'Untitled Script';
                        final role = (data['role'] as String?) ?? 'Role';
                        final score = (((data['accuracy'] as num?)?.toDouble() ?? 0.0) * 100).toStringAsFixed(0);
                        final durationSeconds = (data['durationSeconds'] as num?)?.toInt() ?? 0;
                        final durationMins = math.max(1, (durationSeconds / 60).round());

                        final row = _buildRecentSessionRow(
                          '$title - $role',
                          '$durationMins min',
                          '$score%',
                          const Color(0xFFFFC107),
                        );

                        if (index == sessions.take(8).length - 1) {
                          return row;
                        }

                        return Column(
                          children: [
                            row,
                            Divider(color: Colors.white.withOpacity(0.05), height: 1),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScriptProgressCard(_ScriptProgress row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(row.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  '${(row.averageAccuracy * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2)),
                ),
                FractionallySizedBox(
                  widthFactor: row.averageAccuracy.clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFFFC107), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${row.sessions} session${row.sessions == 1 ? '' : 's'} recorded',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSessionRow(String title, String sub, String score, Color scoreColor) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),
          Text(score, style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _ScriptProgress {
  const _ScriptProgress({
    required this.title,
    required this.averageAccuracy,
    required this.sessions,
  });

  final String title;
  final double averageAccuracy;
  final int sessions;
}

class _SessionLineChartPainter extends CustomPainter {
  _SessionLineChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }

    final linePaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.fill;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : (i / (values.length - 1)) * size.width;
      final y = (1 - values[i].clamp(0.0, 1.0)) * size.height;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 3.5, dotPaint);
    }

    final latest = (values.last * 100).toStringAsFixed(0);
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$latest%',
        style: const TextStyle(color: Color(0xFFFFC107), fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final x = (points.last.dx - textPainter.width - 6).clamp(0.0, size.width - textPainter.width);
    final y = (points.last.dy - textPainter.height - 6).clamp(0.0, size.height - textPainter.height);
    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _SessionLineChartPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) {
      return true;
    }

    for (int i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) {
        return true;
      }
    }

    return false;
  }
}
