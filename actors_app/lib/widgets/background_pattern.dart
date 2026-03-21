import 'package:flutter/material.dart';

// A widget to draw the subtle background film strips/genres
class BackgroundPattern extends StatelessWidget {
  const BackgroundPattern({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top Left
        Positioned(
          left: -40,
          top: 60,
          child: Transform.rotate(
            angle: -0.1,
            child: _buildGenreCard('WESTERN', color: const Color(0xFF1E2A24).withOpacity(0.4), textColor: Colors.cyan.shade600),
          ),
        ),
        // Top Center (Action)
        Positioned(
          left: 120,
          top: -20,
          child: Transform.rotate(
            angle: 0.05,
            child: _buildGenreCard('ACTION', color: const Color(0xFF1B202A).withOpacity(0.5), textColor: Colors.cyan.shade500),
          ),
        ),
        // Middle Right (DRA)
        Positioned(
          right: -40,
          top: 80,
          child: Transform.rotate(
            angle: 0.15,
            child: _buildGenreCard('DRA', color: const Color(0xFF331414).withOpacity(0.5), textColor: Colors.red.shade600),
          ),
        ),
        // Center Left (MUS)
        Positioned(
          left: -60,
          top: 250,
          child: Transform.rotate(
            angle: 0.05,
            child: _buildGenreCard('MUS', color: const Color(0xFF231033).withOpacity(0.4), textColor: Colors.purple.shade500, isCircle: true),
          ),
        ),
        // Center Right (CRIME)
        Positioned(
          right: -30,
          top: 280,
          child: Transform.rotate(
            angle: -0.1,
            child: _buildGenreCard('CRIME', color: const Color(0xFF1A1F2B).withOpacity(0.4), textColor: Colors.grey.shade500),
          ),
        ),
        // Center Bottom (COMEDY)
        Positioned(
          left: 140,
          top: 360,
          child: Transform.rotate(
            angle: -0.05,
            child: _buildGenreCard('COMEDY', color: const Color(0xFF2A2B1A).withOpacity(0.3), textColor: Colors.cyan.shade600),
          ),
        ),
        // Center Center (COM)
        Positioned(
          left: 200,
          top: 220,
          child: Transform.rotate(
            angle: -0.05,
            child: _buildGenreCard('COM', color: const Color(0xFF2A2B1A).withOpacity(0.3), textColor: Colors.yellow.shade600, isCircle: true),
          ),
        ),
        // Bottom Right (HORROR)
        Positioned(
          right: -10,
          bottom: 250,
          child: Transform.rotate(
            angle: 0.0,
            child: _buildGenreCard('HORROR', color: const Color(0xFF151515).withOpacity(0.5), textColor: Colors.amber.shade700),
          ),
        ),
        // Bottom Left (FAN)
        Positioned(
          left: -40,
          bottom: 150,
          child: Transform.rotate(
            angle: 0.05,
            child: _buildGenreCard('FAN', color: const Color(0xFF162B1F).withOpacity(0.4), textColor: Colors.green.shade500, isCircle: true),
          ),
        ),
        // Bottom Center (MYSTERY)
        Positioned(
          left: 120,
          bottom: 50,
          child: Transform.rotate(
            angle: -0.05,
            child: _buildGenreCard('MYSTERY', color: const Color(0xFF1A1A2B).withOpacity(0.4), textColor: Colors.indigo.shade500),
          ),
        ),
        // Very Bottom Right (MYS)
        Positioned(
          right: 50,
          bottom: 120,
          child: Transform.rotate(
            angle: -0.02,
            child: _buildGenreCard('MYS', color: const Color(0xFF1A1A2B).withOpacity(0.3), textColor: Colors.purple.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildGenreCard(String title, {required Color color, required Color textColor, bool isCircle = false}) {
    return Opacity(
      opacity: 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              10,
              (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: Colors.white.withOpacity(0.15), // slightly more visible film strip
              ),
            ),
          ),
          Container(
            width: 140,
            height: 140,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: color,
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircle ? null : BorderRadius.circular(16),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              title,
              style: TextStyle(
                color: textColor, // Specific color applied per genre card
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
