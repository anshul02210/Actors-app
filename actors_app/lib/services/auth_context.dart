import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

class AuthContextController extends ChangeNotifier {
  AuthContextController({
    AuthService? authService,
    FirebaseFirestore? firestore,
  })  : _authService = authService ?? AuthService(),
        _firestore = firestore ?? FirebaseFirestore.instance {
    _authSub = _authService.authStateChanges.listen(_onAuthChanged);
  }

  final AuthService _authService;
  final FirebaseFirestore _firestore;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  User? _user;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get email => _user?.email ?? '';

  String get displayName {
    final first = (profile?['firstName'] as String?)?.trim();
    final last = (profile?['lastName'] as String?)?.trim();

    final fullName = [first, last]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .join(' ');

    if (fullName.isNotEmpty) {
      return fullName;
    }

    final authName = (_user?.displayName ?? '').trim();
    if (authName.isNotEmpty) {
      return authName;
    }

    if (email.contains('@')) {
      return email.split('@').first;
    }

    return 'Actor';
  }

  String get initials {
    final parts = displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      return 'AC';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  Future<void> _onAuthChanged(User? nextUser) async {
    _error = null;
    _user = nextUser;
    _profile = null;
    await _profileSub?.cancel();
    _profileSub = null;

    if (nextUser == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _profileSub = _firestore
        .collection('users')
        .doc(nextUser.uid)
        .snapshots()
        .listen((doc) {
      _profile = doc.data();
      _isLoading = false;
      notifyListeners();
    }, onError: (Object err) {
      _error = err.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
  }) async {
    if (_user == null) {
      return;
    }

    final String cleanedFirst = firstName.trim();
    final String cleanedLast = lastName.trim();
    final String fullName = '$cleanedFirst $cleanedLast'.trim();

    await _firestore.collection('users').doc(_user!.uid).set({
      'firstName': cleanedFirst,
      'lastName': cleanedLast,
      'email': _user!.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _user!.updateDisplayName(fullName);
  }

  Future<void> signOut() {
    return _authService.signOut();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}

class AuthScope extends InheritedNotifier<AuthContextController> {
  const AuthScope({
    super.key,
    required AuthContextController notifier,
    required Widget child,
  }) : super(notifier: notifier, child: child);

  static AuthContextController of(BuildContext context) {
    final AuthScope? scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope not found in widget tree.');
    return scope!.notifier!;
  }
}
