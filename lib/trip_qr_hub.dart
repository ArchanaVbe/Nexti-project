import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trip_qr_screen.dart';
import 'qr_scanner_screen.dart';

class TripQrHub extends StatefulWidget {
  const TripQrHub({super.key});

  @override
  State<TripQrHub> createState() => _TripQrHubState();
}

class _TripQrHubState extends State<TripQrHub> {
  bool _isCreatingTrip = false;

  // Creates a sample trip in Firestore so we have a real tripId to test
  Future<void> _createAndShowSampleTrip() async {
    setState(() => _isCreatingTrip = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final docRef = await FirebaseFirestore.instance.collection('trips').add({
        'tripName': 'NextTripia Expedition',
        'destination': 'Gokarna Beach Trail',
        'createdBy': user?.uid ?? 'anonymous',
        'members': [user?.uid ?? 'anonymous'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isCreatingTrip = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TripQrScreen(
            tripId: docRef.id,
            tripName: 'NextTripia Expedition',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isCreatingTrip = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating trip: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Trip QR Management', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_2_rounded, size: 70, color: Colors.black87),
              const SizedBox(height: 16),
              const Text(
                'NextTripia QR Hub',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Generate invite codes or scan to join trips',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 36),

              // Button 1: Create trip & show QR
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: _isCreatingTrip
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code),
                  label: const Text('Generate Trip QR Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isCreatingTrip ? null : _createAndShowSampleTrip,
                ),
              ),

              const SizedBox(height: 16),

              // Button 2: Scan QR
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan to Join Trip'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black87),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final joinedTripId = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                    );

                    if (joinedTripId != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Joined trip ID: $joinedTripId'),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}