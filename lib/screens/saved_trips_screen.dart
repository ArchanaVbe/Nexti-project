import 'package:flutter/material.dart';

class SavedTripsScreen extends StatelessWidget {
  const SavedTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Trips & Groups'),
      ),
      body: const Center(
        child: Text('Group Management will go here'),
      ),
    );
  }
}
