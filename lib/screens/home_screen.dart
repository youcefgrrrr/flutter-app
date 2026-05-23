import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/audio_player_service.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/favorites_service.dart';
import '../services/stats_service.dart';
import 'player_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final stats = context.read<StatsService>();
      final favorites = context.read<FavoritesService>();
      final audio = context.read<AudioPlayerService>();
      audio.bindStats(stats);
      await Future.wait([
        stats.init(),
        favorites.load(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const StatsScreen(),
      const PlayerScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Statistiques' : 'Lecteur audio'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthService>().signOut();
              if (!context.mounted) return;
              context.read<BiometricService>().lockSession();
            },
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.music_note),
            label: 'Lecteur',
          ),
        ],
      ),
    );
  }
}
