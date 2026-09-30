import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;

class TripQrScreen extends StatefulWidget {
  final String tripId;
  final String tripName;

  const TripQrScreen({
    super.key,
    required this.tripId,
    required this.tripName,
  });

  @override
  State<TripQrScreen> createState() => _TripQrScreenState();
}

class _TripQrScreenState extends State<TripQrScreen> {
  final GlobalKey _qrCardKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareQrCode() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      await Future.delayed(const Duration(milliseconds: 60));

      final boundary = _qrCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not locate QR render boundary.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (byteData == null) {
        throw Exception('Failed to capture QR image bytes.');
      }

      final img.Image convertedImage = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: byteData.buffer,
        order: img.ChannelOrder.rgba,
      );

      final List<int> jpegBytes = img.encodeJpg(convertedImage, quality: 95);

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/trip_qr_${widget.tripId}.jpeg';
      final file = File(filePath);
      await file.writeAsBytes(jpegBytes, flush: true);

      final xFile = XFile(
        file.path,
        mimeType: 'image/jpeg',
        name: 'trip_qr_${widget.tripId}.jpeg',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text:
              'Join my trip "${widget.tripName}" on NextTripia!\nTrip Code: ${widget.tripId}\nLink: nexttripia://trip/join?code=${widget.tripId}',
          subject: 'Trip Invite: ${widget.tripName}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing QR Code: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Formatted as custom URI scheme so external camera and Google Lens trigger your app
    final String qrPayload = 'nexttripia://trip/join?code=${widget.tripId}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Trip Invite QR',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.tripName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Let members scan this code to join your trip',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF94A3B8) : Colors.black54,
                ),
              ),
              const SizedBox(height: 28),

              // RepaintBoundary capturing the QR card for high-resolution JPEG sharing
              RepaintBoundary(
                key: _qrCardKey,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 240.0,
                        backgroundColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Trip ID pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: SelectableText(
                  'Trip ID: ${widget.tripId}',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Share QR Code Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSharing ? null : _shareQrCode,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.share_rounded, size: 20, color: Colors.white),
                  label: Text(
                    _isSharing ? 'Preparing Image...' : 'Share QR Code',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}