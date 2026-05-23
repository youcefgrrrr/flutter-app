import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/surah_category.dart';

class FavoritesService extends ChangeNotifier {
  static const Duration _networkTimeout = Duration(seconds: 20);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<FavoriteTrack> favorites = [];
  bool isLoading = false;
  String? lastError;

  CollectionReference<Map<String, dynamic>>? _favoritesRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('favorites');
  }

  Future<void> load() async {
    final ref = _favoritesRef();
    if (ref == null) return;

    isLoading = true;
    notifyListeners();

    try {
      final snap = await ref
          .orderBy('addedAt', descending: true)
          .get()
          .timeout(_networkTimeout);
      favorites = snap.docs
          .map((d) => FavoriteTrack.fromMap(d.id, d.data()))
          .toList();
    } catch (e) {
      lastError = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  bool isFavorite(String trackId) =>
      favorites.any((f) => f.id == trackId);

  Future<bool> addFavorite(AudioTrack track) async {
    final ref = _favoritesRef();
    if (ref == null) return false;

    if (isFavorite(track.id)) return true;

    try {
      await ref.doc(track.id).set(
        FavoriteTrack(
          id: track.id,
          surahIndex: track.surahIndex,
          surahName: track.surahName,
          reciter: track.reciter,
          audioUrl: track.audioUrl,
          addedAt: DateTime.now(),
        ).toMap(),
      );
      await load();
      return true;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeFavorite(String trackId) async {
    final ref = _favoritesRef();
    if (ref == null) return false;

    try {
      await ref.doc(trackId).delete();
      await load();
      return true;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }
}
