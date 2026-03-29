import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScriptService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> saveScript(String title, String subtitle, String fullText) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Check if script already exists to avoid duplicates
    final existing = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('scripts')
        .where('title', isEqualTo: title)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('scripts')
          .add({
        'title': title,
        'subtitle': subtitle,
        'fullText': fullText,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Stream<QuerySnapshot> getUserScripts() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('scripts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
