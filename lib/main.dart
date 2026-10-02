import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'login_screen.dart';
import 'home_screen.dart';
import 'theme/app_theme.dart';
import 'services/presence_service.dart';
import 'services/trip_invite_service.dart';
import 'screens/google_maps_selection.dart';
import 'screens/hotel_booking_maps.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }

  await AppTheme.initializeTheme();

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    PresenceService.trackUserPresence(currentUser.uid);
  }

  runApp(const NextTripiaApp());
}

class NextTripiaApp extends StatefulWidget {
  const NextTripiaApp({super.key});

  @override
  State<NextTripiaApp> createState() => _NextTripiaAppState();
}

class _NextTripiaAppState extends State<NextTripiaApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'nexttripia' && uri.host == 'trip' && uri.path == '/join') {
        final code = uri.queryParameters['code'];
        if (code != null && _navigatorKey.currentContext != null) {
          TripInviteService.processIncomingTripCode(_navigatorKey.currentContext!, code);
        }
      }
    }, onError: (err) {
      debugPrint('Deep Link listener error: $err');
    });
  }

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
          navigatorKey: _navigatorKey,
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
          initialRoute: FirebaseAuth.instance.currentUser != null ? '/home' : '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
            '/trip_details': (context) => const Scaffold(
                  body: Center(
                    child: Text('Trip Details Screen'),
                  ),
                ),
            '/google_maps_selection': (context) => const GoogleMapsSelection(),
            '/hotel_booking_maps': (context) => const HotelBookingMaps(
                  userLocation: LatLng(14.4644, 75.9218),
                ),
          },
        );
      },
    );
  }
}