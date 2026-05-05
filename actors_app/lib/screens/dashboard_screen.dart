import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_context.dart';
import '../services/script_service.dart';
import '../widgets/background_pattern.dart';
import 'add_script_screen.dart';
import 'progress_tab.dart';
import 'rehearsal_screen.dart';
import 'scripts_tab.dart';
import 'settings_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  String _greetingByTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  Widget _buildStatCard(String value, String label, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.description, size: 24, color: Color(0xFFFFC107)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(AuthContextController auth) {
    final user = auth.user;
    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white70, size: 36),
              const SizedBox(height: 12),
              const Text(
                'You are signed out.',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Please sign in again to continue.',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ScriptService.getUserScripts(),
      builder: (context, scriptSnapshot) {
        final scriptDocs = scriptSnapshot.data?.docs ?? const [];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ScriptService.getUserSessions(limit: 120),
          builder: (context, sessionSnapshot) {
            final sessionDocs = sessionSnapshot.data?.docs ?? const [];

            final sessionCount = sessionDocs.length;
            final scriptCount = scriptDocs.length;
            final averageAccuracy = sessionCount == 0
                ? 0.0
                : sessionDocs
                        .map((doc) => ((doc.data()['accuracy'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0))
                        .fold<double>(0, (a, b) => a + b) /
                    sessionCount;

            final latestSession = sessionDocs.isEmpty ? null : sessionDocs.first.data();
            final latestScriptId = latestSession?['scriptId'] as String?;
            final latestRole = latestSession?['role'] as String?;
            final latestTitle = latestSession?['scriptTitle'] as String?;
            final latestAccuracy = ((latestSession?['accuracy'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
            final latestLines = (latestSession?['totalLines'] as num?)?.toInt() ?? 0;

            final scriptById = <String, Map<String, dynamic>>{};
            for (final doc in scriptDocs) {
              scriptById[doc.id] = doc.data();
            }

            final latestScriptData = latestScriptId == null ? null : scriptById[latestScriptId];
            final latestFullText = latestScriptData?['fullText'] as String?;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greetingByTime(),
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Text(
                            auth.displayName.split(RegExp(r'\s+')).first,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'logout') {
                            await auth.signOut();
                          }
                        },
                        offset: const Offset(0, 50),
                        color: const Color(0xFF1B1D22),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout, color: Colors.white70, size: 20),
                                SizedBox(width: 8),
                                Text('Sign Out', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFB5702A),
                              width: 1.5,
                            ),
                            color: const Color(0xFF231A15),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            auth.initials,
                            style: const TextStyle(
                              color: Color(0xFFFFC107),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '${(averageAccuracy * 100).toStringAsFixed(0)}%',
                          'Avg accuracy',
                          const Color(0xFFFFC107),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard('$sessionCount', 'Sessions', Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard('$scriptCount', 'Scripts', Colors.greenAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (latestSession != null) ...[
                    const Text(
                      'RECENT SESSION',
                      style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 16),
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
                              Expanded(
                                child: Text(
                                  latestTitle ?? 'Untitled Script',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.4)),
                                ),
                                child: Text(
                                  '${(latestAccuracy * 100).toStringAsFixed(0)}% Score',
                                  style: const TextStyle(color: Color(0xFFFFC107), fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Role played: ${latestRole ?? 'Unknown'}',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Practiced $latestLines lines',
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                              ),
                              if (latestFullText != null && latestRole != null)
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RehearsalScreen(
                                            scriptId: latestScriptId,
                                            scriptTitle: latestTitle ?? 'Untitled Script',
                                            fullText: latestFullText,
                                            selectedCharacter: latestRole,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFC107).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.3)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.replay, color: Color(0xFFFFC107), size: 14),
                                          SizedBox(width: 6),
                                          Text(
                                            'Repractice',
                                            style: TextStyle(
                                              color: Color(0xFFFFC107),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  'Script not available',
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'MY SCRIPTS',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AddScriptScreen()),
                            );
                          },
                          child: const Text(
                            '+ Add new',
                            style: TextStyle(
                              color: Color(0xFFFFC107),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (scriptDocs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Text(
                        'No scripts uploaded yet. Add a script to start rehearsing.',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    )
                  else
                    Column(
                      children: scriptDocs.take(4).map((doc) {
                        final data = doc.data();
                        final title = (data['title'] as String?) ?? 'Untitled Script';
                        final subtitle = (data['subtitle'] as String?) ?? 'Tap to rehearse';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildScriptCard(
                            title: title,
                            subtitle: subtitle,
                            onTap: () => setState(() => _currentIndex = 1),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      body: Stack(
        children: [
          const Positioned.fill(
            child: BackgroundPattern(),
          ),
          SafeArea(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeTab(auth),
                const ScriptsTab(),
                const ProgressTab(),
                const SettingsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
          child: BottomNavigationBar(
            backgroundColor: const Color(0xFF0B0C10),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFFFFC107),
            unselectedItemColor: Colors.white38,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.space_dashboard_rounded), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.my_library_books_rounded), label: 'Scripts'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Progress'),
              BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}
