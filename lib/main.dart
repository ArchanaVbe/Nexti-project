import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const NextTripiaApp());
}

class NextTripiaApp extends StatelessWidget {
  const NextTripiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextTripia AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}