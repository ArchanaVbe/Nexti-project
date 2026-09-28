import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetection(String rawCode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // 1. Verify app prefix
    if (!rawCode.startsWith('nexttripia:join:')) {
      _showFeedback('Invalid NextTripia QR code.', isError: true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    final String tripId = rawCode.replaceFirst('nexttripia:join:', '').trim();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showFeedback('You must be logged in to join.', isError: true);
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    try {
      final tripRef = FirebaseFirestore.instance.collection('trips').doc(tripId);
      final tripDoc = await tripRef.get();

      if (!tripDoc.exists) {
        _showFeedback('Trip does not exist or has expired.', isError: true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      // 2. Add current user UID to the trip members array in Cloud Firestore
      await tripRef.update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      if (!mounted) return;
      _showFeedback('Successfully joined the trip!');
      Navigator.pop(context, tripId);
    } catch (e) {
      _showFeedback('Failed to join trip: $e', isError: true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scan Trip QR',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleBarcodeDetection(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          // Viewfinder targeting frame
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2.5),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}