import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/destination.dart';
import 'create_trip_screen.dart';
import '../qr_scanner_screen.dart';

class HomeTabScreen extends StatelessWidget {
  final void Function(int index)? onNavigateTab;

  const HomeTabScreen({
    super.key,
    this.onNavigateTab,
  });

  void _navigateToCreateTrip(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTripScreen()),
    );
    if (result == true) {
      onNavigateTab?.call(1);
    }
  }

  void _showJoinTripModal(BuildContext context) {
    final codeController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final hasCode = codeController.text.trim().isNotEmpty;
            final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: bottomInset > 0 ? bottomInset + 20 : 32,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.group_add_rounded,
                          color: Color(0xFF6366F1),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join Trip',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Enter host code to join planning room',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Enter Trip Code',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          letterSpacing: 0.2,
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          final scannedCode = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                          );
                          if (scannedCode != null && scannedCode.isNotEmpty) {
                            codeController.text = scannedCode;
                            setModalState(() {});
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF6366F1)),
                              SizedBox(width: 4),
                              Text(
                                'Scan QR',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. TRIP-295145',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.pin_rounded,
                        color: Color(0xFF6366F1),
                        size: 22,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasCode)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              onPressed: () {
                                codeController.clear();
                                setModalState(() {});
                              },
                            )
                          else ...[
                            IconButton(
                              tooltip: 'Scan QR Code',
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Color(0xFF6366F1)),
                              onPressed: () async {
                                final scannedCode = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                                );
                                if (scannedCode != null && scannedCode.isNotEmpty) {
                                  codeController.text = scannedCode;
                                  setModalState(() {});
                                }
                              },
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data?.text != null && data!.text!.trim().isNotEmpty) {
                                  String cleanText = data.text!.trim();
                                  if (cleanText.startsWith('nexttripia:join:')) {
                                    cleanText = cleanText.replaceFirst('nexttripia:join:', '').trim();
                                  }
                                  codeController.text = cleanText;
                                  setModalState(() {});
                                }
                              },
                              icon: const Icon(Icons.content_paste_rounded, size: 16, color: Color(0xFF6366F1)),
                              label: const Text(
                                'Paste',
                                style: TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                        ],
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      setModalState(() {});
                    },
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _handleJoinTrip(sheetContext, context, value.trim());
                      }
                    },
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: hasCode
                        ? Container(
                            key: const ValueKey('join_button_active'),
                            width: double.infinity,
                            height: 52,
                            margin: const EdgeInsets.only(top: 20),
                            child: ElevatedButton(
                              onPressed: () {
                                _handleJoinTrip(sheetContext, context, codeController.text.trim());
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Join',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('join_button_placeholder'),
                            height: 8,
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleJoinTrip(
    BuildContext sheetContext,
    BuildContext homeContext,
    String rawCode,
  ) async {
    String cleanCode = rawCode.trim().toUpperCase();
    if (cleanCode.startsWith('NEXTTRIPIA:JOIN:')) {
      cleanCode = cleanCode.replaceFirst('NEXTTRIPIA:JOIN:', '').trim();
    }
    if (cleanCode.isEmpty) return;

    // Close bottom sheet
    Navigator.pop(sheetContext);

    final currentUser = FirebaseAuth.instance.currentUser;
    final myUid = currentUser?.uid ?? 'traveler_${DateTime.now().millisecondsSinceEpoch}';
    final myName = currentUser?.displayName ?? (currentUser?.email?.split('@').first ?? 'Traveler');
    final myPhoto = currentUser?.photoURL ?? '';

    // Check Firestore for trip
    final docRef = FirebaseFirestore.instance.collection('trips').doc(cleanCode);
    DocumentSnapshot<Map<String, dynamic>>? docSnap;
    try {
      docSnap = await docRef.get();
    } catch (e) {
      debugPrint('Error getting trip doc: $e');
    }

    Map<String, dynamic>? matchingTrip;

    if (docSnap != null && docSnap.exists && docSnap.data() != null) {
      final data = docSnap.data()!;
      matchingTrip = {
        'id': docSnap.id,
        'tripCode': cleanCode,
        'destination': data['destination'] ?? data['tripName'] ?? '',
        'startDate': data['startDate'] ?? '',
        'endDate': data['endDate'] ?? '',
        'groupSize': data['groupSize'] ?? '',
        'places': data['places'] ?? <String>[],
        'hostUid': data['hostUid'],
        'approvedMembers': data['approvedMembers'],
        'pendingRequests': data['pendingRequests'],
      };
    } else {
      // Local fallback lookup
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedTrips = prefs.getStringList('saved_trips') ?? [];
        for (final tripStr in savedTrips) {
          try {
            final Map<String, dynamic> trip = jsonDecode(tripStr);
            final id = (trip['id'] ?? '').toString().toUpperCase();
            final code = (trip['tripCode'] ?? '').toString().toUpperCase();
            if (id == cleanCode || code == cleanCode || id.contains(cleanCode) || code.contains(cleanCode)) {
              matchingTrip = trip;
              break;
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    if (matchingTrip == null) {
      if (homeContext.mounted) {
        ScaffoldMessenger.of(homeContext).showSnackBar(
          SnackBar(
            content: Text('Trip code "$cleanCode" not found. Please check with the host.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final hostUid = (matchingTrip['hostUid'] ?? '').toString();
    final approvedList = (matchingTrip['approvedMembers'] as List?) ?? [];
    
    final bool isHost = (hostUid.isNotEmpty && hostUid == myUid);
    final bool isAlreadyApproved = isHost || approvedList.any((m) => m is Map && m['uid'] == myUid);

    if (isAlreadyApproved) {
      if (!homeContext.mounted) return;
      final result = await Navigator.push(
        homeContext,
        MaterialPageRoute(
          builder: (context) => CreateTripScreen(
            isHost: isHost,
            tripCode: cleanCode,
            initialTripData: matchingTrip,
          ),
        ),
      );
      if (result == true) {
        onNavigateTab?.call(1);
      }
      return;
    }

    // User is NOT yet approved: Send join request to host!
    final requestMap = {
      'uid': myUid,
      'name': myName,
      'photoUrl': myPhoto,
      'requestedAt': Timestamp.now(),
    };

    try {
      final pendingList = (matchingTrip['pendingRequests'] as List?) ?? [];
      final bool alreadyPending = pendingList.any((r) => r is Map && r['uid'] == myUid);
      if (!alreadyPending) {
        await docRef.update({
          'pendingRequests': FieldValue.arrayUnion([requestMap]),
        });
      }
    } catch (e) {
      debugPrint('Error updating pendingRequests: $e');
    }

    if (!homeContext.mounted) return;

    // Show waiting for approval dialog with real-time Firestore listener
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
    bool hasHandledResponse = false;

    await showDialog(
      context: homeContext,
      barrierDismissible: false,
      builder: (waitingCtx) {
        final isDark = Theme.of(waitingCtx).brightness == Brightness.dark;

        sub ??= docRef.snapshots().listen((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) return;
          final currentData = snapshot.data()!;
          final currentApproved = (currentData['approvedMembers'] as List?) ?? [];
          final currentPending = (currentData['pendingRequests'] as List?) ?? [];

          final isNowApproved = currentApproved.any((m) => m is Map && m['uid'] == myUid);
          final isStillPending = currentPending.any((r) => r is Map && r['uid'] == myUid);

          if (isNowApproved && !hasHandledResponse) {
            hasHandledResponse = true;
            sub?.cancel();
            if (waitingCtx.mounted) {
              Navigator.of(waitingCtx).pop();
            }
            if (homeContext.mounted) {
              ScaffoldMessenger.of(homeContext).showSnackBar(
                const SnackBar(
                  content: Text('Host approved your request! Welcome to the planning room.'),
                  backgroundColor: Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.push(
                homeContext,
                MaterialPageRoute(
                  builder: (context) => CreateTripScreen(
                    isHost: false,
                    tripCode: cleanCode,
                    initialTripData: currentData,
                  ),
                ),
              ).then((result) {
                if (result == true) {
                  onNavigateTab?.call(1);
                }
              });
            }
          } else if (!isStillPending && !isNowApproved && !hasHandledResponse) {
            // Request was denied by the host
            hasHandledResponse = true;
            sub?.cancel();
            if (waitingCtx.mounted) {
              Navigator.of(waitingCtx).pop();
            }
            if (homeContext.mounted) {
              ScaffoldMessenger.of(homeContext).showSnackBar(
                const SnackBar(
                  content: Text('The host declined your request to join this trip.'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        });

        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: Color(0xFF6366F1),
                      strokeWidth: 3.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Waiting for Host Approval',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A join request has been sent to the host for $cleanCode.\nYou will enter the planning room as soon as the host allows you in.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        sub?.cancel();
                        docRef.update({
                          'pendingRequests': FieldValue.arrayRemove([requestMap]),
                        }).catchError((_) {});
                        Navigator.pop(waitingCtx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    sub?.cancel();
  }


  @override
  Widget build(BuildContext context) {
    final destinations = DestinationItem.sampleDestinations;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Top Header Bar
              _buildTopHeader(context),
              const SizedBox(height: 20),

              // Greeting & Subtitle
              _buildGreeting(context),
              const SizedBox(height: 20),

              // Search Bar
              _buildSearchBar(context),
              const SizedBox(height: 20),

              // Quick Actions (Create Trip & Join Trip)
              _buildQuickActions(context),
              const SizedBox(height: 28),

              // Popular Destinations Header
              _buildDestinationsHeader(context),
              const SizedBox(height: 16),

              // Popular Destinations Horizontal List
              _buildDestinationsList(context, destinations),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // App Logo & Name
        Row(
          children: [
            Transform.rotate(
              angle: -0.4,
              child: const Icon(
                Icons.send_rounded,
                color: Color(0xFF6366F1),
                size: 26,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'NexTripia-AI',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B),
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        // Action Icons: Notifications & Profile Avatar
        Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_none_rounded,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B),
                size: 26,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No new notifications')),
                );
              },
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => onNavigateTab?.call(3), // Navigate to Profile tab
              child: Builder(
                builder: (context) {
                  final user = FirebaseAuth.instance.currentUser;
                  final photoUrl = user?.photoURL;
                  final initial = (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
                      ? user.displayName!.trim()[0].toUpperCase()
                      : ((user?.email != null && user!.email!.isNotEmpty)
                          ? user.email![0].toUpperCase()
                          : 'U');

                  return Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (photoUrl != null && photoUrl.isNotEmpty)
                        ? Image.network(
                            photoUrl,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          )
                        : Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    String greetingName = 'Explorer';
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      greetingName = user.displayName!.trim().split(' ').first;
    } else if (user?.email != null && user!.email!.isNotEmpty) {
      greetingName = user.email!.split('@').first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, $greetingName \u{1F44B}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Plan. Explore. Travel Together.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      child: TextField(
        style: TextStyle(
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: const Color(0xFF6366F1),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          icon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF4F46E5),
            size: 22,
          ),
          hintText: 'Where in Karnataka do you want to go?',
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildWideActionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? bgColor.withValues(alpha: 0.2) : bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 24),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildWideActionCard(
            context,
            icon: Icons.groups_rounded,
            iconColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF3E8FF),
            label: 'Create Trip',
            subtitle: 'Plan with friends',
            onTap: () => _navigateToCreateTrip(context),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildWideActionCard(
            context,
            icon: Icons.group_add_rounded,
            iconColor: const Color(0xFF0284C7),
            bgColor: const Color(0xFFE0F2FE),
            label: 'Join Trip',
            subtitle: 'Enter trip code',
            onTap: () => _showJoinTripModal(context),
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationsHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Popular Destinations',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B),
            letterSpacing: -0.3,
          ),
        ),
        GestureDetector(
          onTap: () => onNavigateTab?.call(2), // Navigate to Explore tab
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'See All',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6366F1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationsList(BuildContext context, List<DestinationItem> destinations) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: destinations.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = destinations[index];
          return _buildDestinationCard(context, item);
        },
      ),
    );
  }

  Widget _buildDestinationCard(BuildContext context, DestinationItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 144,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              item.imageUrl,
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.7),
                        const Color(0xFF0284C7).withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: double.infinity,
                  height: 120,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '${item.district}, Karnataka',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
