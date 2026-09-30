import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }
  await AppTheme.initializeTheme();
  runApp(const NextTripiaApp());
}

class NextTripiaApp extends StatelessWidget {
  const NextTripiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppTheme.themeModeNotifier,
        AppTheme.fontFamilyNotifier,
        AppTheme.fontScaleNotifier,
      ]),
      builder: (context, _) {
        return MaterialApp(
          title: 'NextTripia AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getLightTheme(AppTheme.fontFamilyNotifier.value),
          darkTheme: AppTheme.getDarkTheme(AppTheme.fontFamilyNotifier.value),
          themeMode: AppTheme.themeModeNotifier.value,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(AppTheme.fontScaleNotifier.value),
              ),
              child: child ?? const SizedBox(),
            );
          },
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
          },
        );
      },
    );
  }
}