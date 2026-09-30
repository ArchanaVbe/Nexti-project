import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService {
  static final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize socket heartbeat tracking for the active user
  static void trackUserPresence(String uid) {
    final statusRef = _rtdb.ref('presence/$uid');
    final connectedRef = _rtdb.ref('.info/connected');

    connectedRef.onValue.listen((event) {
      final isConnected = event.snapshot.value as bool? ?? false;
      if (!isConnected) return;

      // 1. If connection drops unexpectedly, Google marks them offline automatically
      statusRef.onDisconnect().set({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });

      // 2. Mark online in RTDB
      statusRef.set({
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
      });

      // 3. Mirror status in Firestore users collection
      _firestore.collection('users').doc(uid).set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // Explicit logout handler
  static Future<void> markOffline(String uid) async {
    final statusRef = _rtdb.ref('presence/$uid');
    await statusRef.set({
      'isOnline': false,
      'lastSeen': ServerValue.timestamp,
    });

    await _firestore.collection('users').doc(uid).set({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}