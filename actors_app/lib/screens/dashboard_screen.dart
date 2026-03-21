import 'package:flutter/material.dart';
import '../widgets/background_pattern.dart';
import 'progress_tab.dart'; // import the new tab

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good evening,',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    'Anshul',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
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
                child: const Text(
                  'AK',
                  style: TextStyle(
                    color: Color(0xFFFFC107),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard('87%', 'Avg accuracy', const Color(0xFFFFC107)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('14', 'Sessions', Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('3', 'Scripts', Colors.greenAccent),
              ),
            ],
          ),
          const SizedBox(height: 40),
          
          // Continue Rehearsing Section
          const Text(
            'CONTINUE REHEARSING',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          
          // Progress Card
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
                    const Text(
                      'Hamlet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFFC107).withOpacity(0.4),
                        ),
                      ),
                      child: const Text(
                        'In progress',
                        style: TextStyle(
                          color: Color(0xFFFFC107),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Playing: Hamlet · Act II, Scene 2',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Progress Bar
                Stack(
                  children: [
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      height: 4,
                      width: 200, 
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '62% complete',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Scene 5 of 8',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          // My Scripts Section
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
              GestureDetector(
                onTap: () {
                  // Navigate to the "Add Script" screen
                  Navigator.pushNamed(context, '/add_script');
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
            ],
          ),
          const SizedBox(height: 16),
          
          // Scripts List
          _buildScriptCard(
            title: 'Romeo & Juliet',
            subtitle: '2 chars · 5 scenes',
            icon: Icons.theater_comedy,
            iconColor: Colors.blueAccent.shade200,
            iconColor2: Colors.orangeAccent.shade200,
          ),
          const SizedBox(height: 12),
          _buildScriptCard(
            title: 'Death of a Salesman',
            subtitle: '3 chars · Not started',
            icon: Icons.description,
            iconColor: Colors.purple.shade200,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
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
    required IconData icon,
    required Color iconColor,
    Color? iconColor2,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          // Custom Icon Box
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (iconColor2 != null)
                  Positioned(
                    left: 12,
                    top: 14,
                    child: Icon(icon, size: 20, color: iconColor),
                  )
                else
                  Icon(icon, size: 24, color: iconColor),
                if (iconColor2 != null)
                  Positioned(
                    right: 12,
                    bottom: 14,
                    child: Icon(icon, size: 20, color: iconColor2),
                  ),
              ],
            ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
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
                _buildHomeTab(),
                const Center(child: Text('Scripts Tab Placeholder', style: TextStyle(color: Colors.white))), // placeholder for Scripts Tab
                const ProgressTab(),
                const Center(child: Text('Settings Placeholder', style: TextStyle(color: Colors.white))),
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
            onTap: (index) {
              if (index == 1) {
                // If they click 'Scripts' in the bottom navigation tab, navigate to the Add Scripts Screen
                // Or just switch tabs. Let's switch tabs for now. We can modify later.
              }
              setState(() {
                _currentIndex = index;
              });
            },
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
