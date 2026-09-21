import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'home_screen.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}