import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/create_trip_screen.dart';

class TripInviteService {
  static const String _pendingKey = 'pending_trip_code';

  // 1. Called when a deep link or in-app scan delivers a trip code
  static Future<void> processIncomingTripCode(BuildContext context, String tripCode) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // User is NOT logged in: Save tripCode and route to Login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingKey, tripCode);

      if (context.mounted) {
        Navigator.pushNamed(context, '/login');
      }
    } else {
      // User is ALREADY logged in: Join trip directly
      await joinTripWithUser(context, tripCode, user);
    }
  }

  // 2. Called from LoginScreen immediately after successful authentication
  static Future<bool> completePendingInviteIfAny(BuildContext context, User user) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingCode = prefs.getString(_pendingKey);

    if (pendingCode != null && pendingCode.isNotEmpty) {
      await prefs.remove(_pendingKey);
      if (context.mounted) {
        await joinTripWithUser(context, pendingCode, user);
        return true;
      }
    }
    return false;
  }

  // 3. Adds user's profile to Firestore trip collection & directly navigates to planning room
  static Future<void> joinTripWithUser(BuildContext context, String tripCode, User user) async {
    final tripRef = FirebaseFirestore.instance.collection('trips').doc(tripCode);

    final memberMap = {
      'uid': user.uid,
      'displayName': user.displayName ?? 'Traveler',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'joinedAt': DateTime.now().toIso8601String(),
    };

    try {
      await tripRef.set({
        'memberUids': FieldValue.arrayUnion([user.uid]),
        'approvedMembers': FieldValue.arrayUnion([memberMap]),
        'members': FieldValue.arrayUnion([memberMap]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error joining trip in Firestore: $e');
    }

    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await tripRef.get();
    } catch (_) {}

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CreateTripScreen(
            isHost: false,
            tripCode: tripCode,
            initialTripData: snap?.data(),
            initialStep: 3, // Directly navigate to planning room
          ),
        ),
      );
    }
  }
}