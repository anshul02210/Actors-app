import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const ActorsApp());
}

class ActorsApp extends StatelessWidget {
  const ActorsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Actors Line Learning Task',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        // '/register': (context) => const RegisterScreen(),
        // '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
