import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_tab_screen.dart';
import 'trips_screen.dart';
import 'explore_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<int> _navigationHistory = [0];
  DateTime? _lastBackPressTime;

  void _onNavigateTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _navigationHistory.remove(index);
      _navigationHistory.add(index);
      _selectedIndex = index;
    });
  }

  bool _handleBackPress() {
    if (_navigationHistory.length > 1) {
      setState(() {
        _navigationHistory.removeLast();
        _selectedIndex = _navigationHistory.last;
      });
      return false; // Handled: stepped one tab back
    } else if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
        _navigationHistory.clear();
        _navigationHistory.add(0);
      });
      return false; // Handled: return to home
    }

    // Already on Home with no prior history in stack
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false; // Intercept: require second press to close app
    }

    return true; // Allow app to exit
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeTabScreen(onNavigateTab: _onNavigateTab),
      TripsScreen(key: UniqueKey()),
      const ExploreScreen(),
      const ProfileScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        final shouldExit = _handleBackPress();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFC),
        body: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.white,
          elevation: 4,
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onNavigateTab,
          indicatorColor: const Color(0xFFE0E7FF),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: Color(0xFF4338CA),
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              );
            }
            return const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }),
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: Color(0xFF6366F1)),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.luggage_outlined),
              selectedIcon: Icon(Icons.luggage, color: Color(0xFF6366F1)),
              label: 'Trips',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore, color: Color(0xFF6366F1)),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: Color(0xFF6366F1)),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
