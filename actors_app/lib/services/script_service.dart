import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScriptService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get _user => _auth.currentUser;

  static String? get currentUserId => _user?.uid;

  static Future<String?> saveScript({
    required String title,
    required String subtitle,
    required String fullText,
    required List<String> characters,
    Map<String, dynamic>? formatted,
  }) async {
    final user = _user;
    if (user == null) return null;

    final existing = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('scripts')
        .where('title', isEqualTo: title)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final existingDoc = existing.docs.first;
      await existingDoc.reference.set({
        'subtitle': subtitle,
        'fullText': fullText,
        'characters': characters,
        if (formatted != null) 'formatted': formatted,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return existingDoc.id;
    }

    final created = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('scripts')
        .add({
      'title': title,
      'subtitle': subtitle,
      'fullText': fullText,
      'characters': characters,
      if (formatted != null) 'formatted': formatted,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return created.id;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserScripts() {
    final user = _user;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('scripts')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        )
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> saveSession({
    required String scriptId,
    required String scriptTitle,
    required String role,
    required double accuracy,
    required int totalLines,
    required int durationSeconds,
  }) async {
    final user = _user;
    if (user == null) {
      return;
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .add({
      'scriptId': scriptId,
      'scriptTitle': scriptTitle,
      'role': role,
      'accuracy': accuracy,
      'totalLines': totalLines,
      'durationSeconds': durationSeconds,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserSessions({
    int? limit,
  }) {
    final user = _user;
    if (user == null) {
      return const Stream.empty();
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        )
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> getUserSettings() {
    final user = _user;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('app')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        )
        .snapshots();
  }

  static Future<Map<String, dynamic>> getUserSettingsOnce() async {
    final user = _user;
    if (user == null) {
      return <String, dynamic>{};
    }

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('app')
        .get();

    return doc.data() ?? <String, dynamic>{};
  }

  static Future<void> updateUserSettings(Map<String, dynamic> values) async {
    final user = _user;
    if (user == null) {
      return;
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('app')
        .set({
      ...values,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Delete a script and optionally its sessions
  static Future<void> deleteScript(String scriptId, {bool removeSessions = false}) async {
    final user = _user;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid).collection('scripts').doc(scriptId);
    await docRef.delete();

    if (removeSessions) {
      final sessionsColl = _firestore.collection('users').doc(user.uid).collection('sessions');
      final snaps = await sessionsColl.where('scriptId', isEqualTo: scriptId).get();
      for (final s in snaps.docs) {
        await s.reference.delete();
      }
    }
  }

  /// Fetch a single script document once
  static Future<Map<String, dynamic>?> getScriptOnce(String scriptId) async {
    final user = _user;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).collection('scripts').doc(scriptId).get();
    return doc.exists ? (doc.data() ?? <String, dynamic>{}) : null;
  }
}
