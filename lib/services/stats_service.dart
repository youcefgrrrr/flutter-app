import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/surah_category.dart';

class StatsService extends ChangeNotifier {
  static const _goalKey = 'monthly_goal_hours';
  static const defaultGoalHours = 20;
  static const Duration _networkTimeout = Duration(seconds: 20);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int monthlyGoalHours = defaultGoalHours;
  int totalMinutes = 0;
  List<DailyListening> dailyStats = [];
  List<TopTrackStat> topTracks = [];
  bool isLoading = true;
  String? loadError;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    monthlyGoalHours = prefs.getInt(_goalKey) ?? defaultGoalHours;
    await refresh();
  }

  Future<void> setMonthlyGoalHours(int hours) async {
    monthlyGoalHours = hours;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_goalKey, hours);
    notifyListeners();
  }

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  CollectionReference<Map<String, dynamic>>? _userStatsRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('listening_stats');
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      loadError = null;
      notifyListeners();
    }

    final ref = _userStatsRef();
    if (ref == null) {
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final now = DateTime.now();
      final monthDoc = await ref
          .doc(_monthKey(now))
          .get()
          .timeout(_networkTimeout);
      final monthData = monthDoc.data() ?? {};

      totalMinutes = monthData['totalMinutes'] as int? ?? 0;

      final daysMap = monthData['days'] as Map<String, dynamic>? ?? {};
      dailyStats = daysMap.entries.map((e) {
        return DailyListening(
          date: DateTime.parse('${e.key}T12:00:00'),
          minutes: (e.value as num).toInt(),
        );
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final topList = monthData['topTracks'] as List<dynamic>? ?? [];
      topTracks = topList.map((item) {
        final map = item as Map<String, dynamic>;
        return TopTrackStat(
          trackId: map['trackId'] as String? ?? '',
          title: map['title'] as String? ?? '',
          subtitle: map['subtitle'] as String? ?? '',
          playCount: map['playCount'] as int? ?? 0,
          totalMinutes: map['totalMinutes'] as int? ?? 0,
        );
      }).toList();
      loadError = null;
    } on TimeoutException {
      loadError =
          'Chargement trop long. Vérifiez Internet et que Firestore est activé.';
    } catch (e) {
      loadError = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> recordListening({
    required AudioTrack track,
    required int listenedSeconds,
  }) async {
    if (listenedSeconds <= 0) return;
    final ref = _userStatsRef();
    if (ref == null) return;

    final now = DateTime.now();
    final monthId = _monthKey(now);
    final dayId = _dayKey(now);
    final minutes = (listenedSeconds / 60).ceil().clamp(1, 9999);

    final monthRef = ref.doc(monthId);

    try {
      await _db.runTransaction((tx) async {
      final snap = await tx.get(monthRef);
      final data = snap.data() ?? {};
      final days = Map<String, dynamic>.from(
        data['days'] as Map<String, dynamic>? ?? {},
      );
      days[dayId] = ((days[dayId] as num?)?.toInt() ?? 0) + minutes;

      final top = List<Map<String, dynamic>>.from(
        (data['topTracks'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );

      final index =
          top.indexWhere((t) => t['trackId'] == track.id);
      if (index >= 0) {
        top[index]['playCount'] =
            (top[index]['playCount'] as int? ?? 0) + 1;
        top[index]['totalMinutes'] =
            (top[index]['totalMinutes'] as int? ?? 0) + minutes;
      } else {
        top.add({
          'trackId': track.id,
          'title': track.reciter,
          'subtitle': track.surahName,
          'playCount': 1,
          'totalMinutes': minutes,
        });
      }
      top.sort((a, b) =>
          (b['playCount'] as int).compareTo(a['playCount'] as int));

      tx.set(monthRef, {
        'totalMinutes':
            ((data['totalMinutes'] as num?)?.toInt() ?? 0) + minutes,
        'days': days,
        'topTracks': top.take(10).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }).timeout(_networkTimeout);
    } catch (_) {
      // Ne bloque pas la lecture si Firestore est indisponible.
    }

    await refresh(silent: true);
  }

  double get goalProgress {
    final goalMinutes = monthlyGoalHours * 60;
    if (goalMinutes == 0) return 0;
    return (totalMinutes / goalMinutes).clamp(0.0, 1.0);
  }

  int get totalHours => totalMinutes ~/ 60;
  int get remainingMinutes => totalMinutes % 60;
}
