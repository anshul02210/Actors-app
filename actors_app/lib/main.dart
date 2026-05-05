import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/add_script_screen.dart';
import 'services/auth_context.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ActorsApp());
}

class ActorsApp extends StatefulWidget {
  const ActorsApp({super.key});

  @override
  State<ActorsApp> createState() => _ActorsAppState();
}

class _ActorsAppState extends State<ActorsApp> {
  late final AuthContextController _authContext;

  @override
  void initState() {
    super.initState();
    _authContext = AuthContextController();
  }

  @override
  void dispose() {
    _authContext.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      notifier: _authContext,
      child: MaterialApp(
        title: 'Actors Line Learning Task',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: AnimatedBuilder(
          animation: _authContext,
          builder: (context, _) {
            if (_authContext.isLoading) {
              return const Scaffold(
                backgroundColor: Color(0xFF0B0C10),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                ),
              );
            }

            if (_authContext.user == null) {
              return const WelcomeScreen();
            }

            return const DashboardScreen();
          },
        ),
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/add_script': (context) => const AddScriptScreen(),
        },
      ),
    );
  }
}
