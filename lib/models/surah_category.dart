class SurahCategory {
  const SurahCategory({
    required this.index,
    required this.name,
    required this.translation,
    required this.arabicName,
  });

  final int index;
  final String name;
  final String translation;
  final String arabicName;

  String get displayTitle => '$index. $name';
  String get subtitle => translation;
}

class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.surahIndex,
    required this.surahName,
    required this.reciter,
    required this.audioUrl,
  });

  final String id;
  final int surahIndex;
  final String surahName;
  final String reciter;
  final String audioUrl;

  String get title => reciter;
  String get subtitle => surahName;
}

class FavoriteTrack {
  const FavoriteTrack({
    required this.id,
    required this.surahIndex,
    required this.surahName,
    required this.reciter,
    required this.audioUrl,
    required this.addedAt,
  });

  final String id;
  final int surahIndex;
  final String surahName;
  final String reciter;
  final String audioUrl;
  final DateTime addedAt;

  Map<String, dynamic> toMap() => {
        'surahIndex': surahIndex,
        'surahName': surahName,
        'reciter': reciter,
        'audioUrl': audioUrl,
        'addedAt': addedAt.toIso8601String(),
      };

  factory FavoriteTrack.fromMap(String id, Map<String, dynamic> map) {
    return FavoriteTrack(
      id: id,
      surahIndex: map['surahIndex'] as int? ?? 0,
      surahName: map['surahName'] as String? ?? '',
      reciter: map['reciter'] as String? ?? '',
      audioUrl: map['audioUrl'] as String? ?? '',
      addedAt: DateTime.tryParse(map['addedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  AudioTrack toAudioTrack() => AudioTrack(
        id: id,
        surahIndex: surahIndex,
        surahName: surahName,
        reciter: reciter,
        audioUrl: audioUrl,
      );
}

class DailyListening {
  const DailyListening({required this.date, required this.minutes});

  final DateTime date;
  final int minutes;
}

class TopTrackStat {
  const TopTrackStat({
    required this.trackId,
    required this.title,
    required this.subtitle,
    required this.playCount,
    required this.totalMinutes,
  });

  final String trackId;
  final String title;
  final String subtitle;
  final int playCount;
  final int totalMinutes;
}
