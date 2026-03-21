import 'package:flutter/material.dart';
import '../widgets/background_pattern.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10), // Deep dark background
      body: Stack(
        children: [
        // Background Pattern
        const Positioned.fill(
          child: BackgroundPattern(),
        ),
          
          // Foreground Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),
                  
                  // App Icon
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1c1e26).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: 18,
                            top: 20,
                            child: Icon(
                              Icons.theater_comedy,
                              size: 38,
                              color: Colors.blueAccent.shade200,
                            ),
                          ),
                          Positioned(
                            right: 18,
                            bottom: 20,
                            child: Icon(
                              Icons.theater_comedy,
                              size: 38,
                              color: Colors.orangeAccent.shade200,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // App Name
                  const Center(
                    child: Text(
                      'LineReady',
                      style: TextStyle(
                        fontFamily: 'Georgia', // Serif font approximation
                        fontSize: 42,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Subtitle
                  const Center(
                    child: Text(
                      'Your AI scene partner.\nRehearse anywhere, anytime.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        color: Color(0xFF9E9EA5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Feature Tags
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFeatureTag('Speech recognition'),
                      const SizedBox(width: 12),
                      _buildFeatureTag('AI feedback'),
                    ],
                  ),
                  
                  const Spacer(flex: 4),
                  
                  // Action Buttons
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Create free account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Sign in to existing account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Terms and Privacy Text
                  Center(
                    child: Text(
                      'By continuing you agree to our Terms & Privacy Policy',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFC107).withOpacity(0.4), // Yellowish border
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: const Color(0xFFFFC107), // Yellowish text
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
