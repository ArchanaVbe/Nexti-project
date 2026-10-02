import 'package:flutter/material.dart';
import 'trip_details_screen.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  int _currentTabIndex = 0;

  final List<Tab> _tabs = const [
    Tab(text: 'Details'),
    Tab(text: 'Group'),
    Tab(text: 'Preferences'),
    Tab(text: 'Show trip'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Trip'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            tabs: _tabs,
            onTap: (index) {
              setState(() {
                _currentTabIndex = index;
              });
            },
          ),
        ),
        body: TabBarView(
          children: [
            const TripDetailsScreen(),
            Center(
              child: Text('Group Tab - Index $_currentTabIndex'),
            ),
            Center(
              child: Text('Preferences Tab - Index $_currentTabIndex'),
            ),
            Center(
              child: Text('Show Trip Tab - Index $_currentTabIndex'),
            ),
          ],
        ),
      ),
    );
  }
}
