import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

class AuthService extends ChangeNotifier {
  AuthService() {
    _auth.authStateChanges().listen((user) {
      currentUser = user;
      if (user != null) {
        if (profile?.uid != user.uid) {
          _loadProfile(user.uid);
        } else {
          isLoading = false;
          notifyListeners();
        }
      } else {
        profile = null;
        isLoading = false;
        notifyListeners();
      }
    });
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Duration _networkTimeout = Duration(seconds: 25);

  User? currentUser;
  UserProfile? profile;
  bool isLoading = true;
  String? lastError;

  Future<T> _withTimeout<T>(Future<T> future, String label) {
    return future.timeout(
      _networkTimeout,
      onTimeout: () => throw TimeoutException(
        '$label : délai dépassé (${_networkTimeout.inSeconds}s). '
        'Vérifiez Internet et que Firestore est créé dans la console Firebase.',
      ),
    );
  }

  Future<UserProfile?> _loadProfile(String uid) async {
    try {
      final doc = await _withTimeout(
        _db.collection('users').doc(uid).get(),
        'Chargement du profil',
      );
      if (doc.exists) {
        profile = UserProfile.fromMap(uid, doc.data()!);
      }
    } catch (e) {
      lastError = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return profile;
  }

  Future<void> _saveProfile(UserProfile userProfile) async {
    await _withTimeout(
      _db.collection('users').doc(userProfile.uid).set(userProfile.toMap()),
      'Enregistrement Firestore',
    );
  }

  static int ageFromBirthDate(DateTime birth) {
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    String? phone,
    String? city,
  }) async {
    lastError = null;
    if (ageFromBirthDate(birthDate) < 13) {
      lastError = 'Vous devez avoir au moins 13 ans pour vous inscrire.';
      notifyListeners();
      return false;
    }

    try {
      final cred = await _withTimeout(
        _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
        'Création du compte',
      );
      final uid = cred.user!.uid;
      final userProfile = UserProfile(
        uid: uid,
        email: email.trim(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        birthDate: birthDate,
        phone: phone?.trim(),
        city: city?.trim(),
      );
      profile = userProfile;
      isLoading = false;
      notifyListeners();

      try {
        await _saveProfile(userProfile);
      } catch (e) {
        lastError =
            'Compte créé, mais profil non sauvegardé en ligne : $e';
      }
      return true;
    } on FirebaseAuthException catch (e) {
      lastError = _mapAuthError(e);
      notifyListeners();
      return false;
    } on TimeoutException catch (e) {
      lastError = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    lastError = null;
    try {
      await _withTimeout(
        _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
        'Connexion',
      );
      return true;
    } on FirebaseAuthException catch (e) {
      lastError = _mapAuthError(e);
      notifyListeners();
      return false;
    } on TimeoutException catch (e) {
      lastError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    lastError = null;
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      lastError = _mapAuthError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    profile = null;
    notifyListeners();
  }

  String _mapAuthError(FirebaseAuthException e) {
    final msg = e.message ?? '';
    if (e.code == 'internal-error' &&
        msg.contains('CONFIGURATION_NOT_FOUND')) {
      return 'Firebase Authentication n\'est pas activé. '
          'Console Firebase → projet test-ba845 → Authentication → '
          'Commencer → activer E-mail/Mot de passe.';
    }

    switch (e.code) {
      case 'email-already-in-use':
        return 'Cet e-mail est déjà utilisé.';
      case 'invalid-email':
        return 'Adresse e-mail invalide.';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères minimum).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou mot de passe incorrect.';
      default:
        return e.message ?? 'Erreur d\'authentification.';
    }
  }
}
