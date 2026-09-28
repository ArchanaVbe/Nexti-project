import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

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

    String tripId = rawCode.trim();

    // 1. Extract trip ID from prefix or URL
    if (tripId.startsWith('nexttripia:join:')) {
      tripId = tripId.replaceFirst('nexttripia:join:', '').trim();
    } else if (tripId.contains('code=')) {
      final uri = Uri.tryParse(tripId);
      if (uri != null && uri.queryParameters['code'] != null) {
        tripId = uri.queryParameters['code']!;
      }
    }

    if (tripId.isEmpty) {
      _showFeedback('Invalid QR code format.', isError: true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    // 2. Optionally update Firestore members if logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final tripRef =
            FirebaseFirestore.instance.collection('trips').doc(tripId);
        final tripDoc = await tripRef.get();
        if (tripDoc.exists) {
          await tripRef.update({
            'members': FieldValue.arrayUnion([user.uid]),
          });
        }
      } catch (_) {}
    }

    if (!mounted) return;
    _showFeedback('Trip code scanned: $tripId');
    // Return extracted tripId to caller so it automatically fills the input field
    Navigator.pop(context, tripId);
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final capture = await _scannerController.analyzeImage(pickedFile.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
            _handleBarcodeDetection(barcode.rawValue!);
            return;
          }
        }
      }
      _showFeedback('No QR code found in selected image.', isError: true);
    } catch (e) {
      _showFeedback('Could not scan image: $e', isError: true);
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
            tooltip: 'Pick image from gallery',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _pickImageFromGallery,
          ),
          IconButton(
            tooltip: 'Toggle Flash',
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Switch Camera',
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
                if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
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
              border: Border.all(color: const Color(0xFF6366F1), width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Positioned(
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Align QR code within the frame or pick from gallery',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
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