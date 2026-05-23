import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/surah_category.dart';

/// API liée à https://quran.yousefheiba.com (quranapi.pages.dev)
class QuranApiService {
  static const String _baseUrl = 'https://quranapi.pages.dev/api';

  Future<List<SurahCategory>> fetchCategories() async {
    final response = await http.get(Uri.parse('$_baseUrl/surah.json'));
    if (response.statusCode != 200) {
      throw Exception('Impossible de charger les catégories audio.');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return List.generate(data.length, (i) {
      final item = data[i] as Map<String, dynamic>;
      return SurahCategory(
        index: i + 1,
        name: item['surahName'] as String? ?? 'Sourate ${i + 1}',
        translation: item['surahNameTranslation'] as String? ?? '',
        arabicName: item['surahNameArabic'] as String? ?? '',
      );
    });
  }

  Future<List<AudioTrack>> fetchTracksForSurah(SurahCategory category) async {
    final response =
        await http.get(Uri.parse('$_baseUrl/audio/${category.index}.json'));
    if (response.statusCode != 200) {
      throw Exception('Impossible de charger les morceaux.');
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    return data.entries.map((entry) {
      final track = entry.value as Map<String, dynamic>;
      final reciter = track['reciter'] as String? ?? 'Récitateur';
      final url = (track['originalUrl'] ?? track['url']) as String? ?? '';
      return AudioTrack(
        id: '${category.index}_${entry.key}',
        surahIndex: category.index,
        surahName: category.name,
        reciter: reciter,
        audioUrl: url,
      );
    }).toList();
  }
}
