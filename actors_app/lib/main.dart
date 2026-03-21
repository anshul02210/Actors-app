import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/add_script_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            User? user = snapshot.data;
            if (user == null) {
              return const WelcomeScreen();
            }
            return const DashboardScreen();
          }
          return const Scaffold(
            backgroundColor: Color(0xFF0B0C10),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFFC107)),
            ),
          );
        },
      ),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/add_script': (context) => const AddScriptScreen(),
      },
    );
  }
}
