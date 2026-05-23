import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/surah_category.dart';
import '../services/audio_player_service.dart';
import '../services/biometric_service.dart';
import '../services/favorites_service.dart';
import '../services/quran_api_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _api = QuranApiService();
  List<SurahCategory> _categories = [];
  List<AudioTrack> _tracks = [];
  SurahCategory? _selectedCategory;
  bool _loadingCategories = true;
  bool _loadingTracks = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _error = null;
    });
    try {
      final data = await _api.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = data;
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingCategories = false;
      });
    }
  }

  Future<void> _selectCategory(SurahCategory category) async {
    setState(() {
      _selectedCategory = category;
      _loadingTracks = true;
      _tracks = [];
    });
    try {
      final tracks = await _api.fetchTracksForSurah(category);
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _loadingTracks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTracks = false;
      });
    }
  }

  Future<void> _toggleFavorite(AudioTrack track) async {
    final favorites = context.read<FavoritesService>();
    if (favorites.isFavorite(track.id)) {
      final biometric = context.read<BiometricService>();
      final ok = await biometric.authenticate(
        reason: 'Confirmez votre empreinte pour supprimer ce favori',
      );
      if (!ok || !mounted) return;
      await favorites.removeFavorite(track.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Favori supprimé')),
        );
      }
    } else {
      await favorites.addFavorite(track);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajouté aux favoris')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerService>();
    final favorites = context.watch<FavoritesService>();

    return Column(
      children: [
        Expanded(child: _buildLibrary(favorites)),
        _PlayerControls(player: player),
      ],
    );
  }

  Widget _buildLibrary(FavoritesService favorites) {
    if (_loadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            FilledButton(onPressed: _loadCategories, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ListView.builder(
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final selected = _selectedCategory?.index == cat.index;
              return ListTile(
                selected: selected,
                title: Text(cat.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(cat.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => _selectCategory(cat),
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child: _selectedCategory == null
              ? const Center(child: Text('Choisissez une catégorie (sourate)'))
              : _loadingTracks
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _tracks.length,
                      itemBuilder: (_, i) {
                        final track = _tracks[i];
                        final isCurrent =
                            playerTrackId(context, track.id);
                        return ListTile(
                          selected: isCurrent,
                          title: Text(track.reciter),
                          subtitle: Text(track.surahName),
                          trailing: IconButton(
                            icon: Icon(
                              favorites.isFavorite(track.id)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: favorites.isFavorite(track.id)
                                  ? Colors.red
                                  : null,
                            ),
                            onPressed: () => _toggleFavorite(track),
                          ),
                          onTap: () =>
                              context.read<AudioPlayerService>().playTrack(track),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  bool playerTrackId(BuildContext context, String id) =>
      context.watch<AudioPlayerService>().currentTrack?.id == id;
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({required this.player});

  final AudioPlayerService player;

  @override
  Widget build(BuildContext context) {
    final track = player.currentTrack;
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              track?.reciter ?? 'Aucun morceau',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (track != null)
              Text(track.surahName, style: Theme.of(context).textTheme.bodySmall),
            if (track != null) _AudioSeekBar(player: player),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Reculer de 10 s',
                  icon: const Icon(Icons.replay_10),
                  onPressed: track == null
                      ? null
                      : () => player.seekRelative(-10),
                ),
                IconButton(
                  tooltip: 'Répéter',
                  icon: Icon(
                    Icons.repeat_one,
                    color: player.repeatOne
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: player.toggleRepeatOne,
                ),
                IconButton(
                  iconSize: 48,
                  icon: Icon(
                    player.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  ),
                  onPressed: track == null
                      ? null
                      : () => player.togglePlayPause(),
                ),
                IconButton(
                  tooltip: 'Avancer de 10 s',
                  icon: const Icon(Icons.forward_10),
                  onPressed: track == null
                      ? null
                      : () => player.seekRelative(10),
                ),
              ],
            ),
            if (context.watch<FavoritesService>().favorites.isNotEmpty) ...[
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Favoris (suppression = empreinte)'),
              ),
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: context
                      .watch<FavoritesService>()
                      .favorites
                      .map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            label: Text(
                              f.reciter,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () => context
                                .read<AudioPlayerService>()
                                .playTrack(f.toAudioTrack()),
                            onDeleted: () async {
                              final biometric =
                                  context.read<BiometricService>();
                              final ok = await biometric.authenticate(
                                reason:
                                    'Empreinte requise pour supprimer un favori',
                              );
                              if (ok && context.mounted) {
                                await context
                                    .read<FavoritesService>()
                                    .removeFavorite(f.id);
                              }
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AudioSeekBar extends StatefulWidget {
  const _AudioSeekBar({required this.player});

  final AudioPlayerService player;

  @override
  State<_AudioSeekBar> createState() => _AudioSeekBarState();
}

class _AudioSeekBarState extends State<_AudioSeekBar> {
  double? _dragValue;
  bool _isDragging = false;
  String? _trackId;

  String _formatDuration(double milliseconds) {
    final totalSeconds = (milliseconds / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void didUpdateWidget(covariant _AudioSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final trackId = widget.player.currentTrack?.id;
    if (trackId != _trackId) {
      setState(() {
        _trackId = trackId;
        _isDragging = false;
        _dragValue = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;

    final durationMs = player.duration.inMilliseconds;
    final bufferedMs = player.bufferedPosition.inMilliseconds;
    final maxMs = durationMs > 0
        ? durationMs
        : (bufferedMs > 0 ? bufferedMs : 0);
    final canSeek = maxMs > 0;
    final maxValue = canSeek ? maxMs.toDouble() : 1.0;
    final liveMs =
        player.position.inMilliseconds.toDouble().clamp(0, maxValue);
    final sliderValue = (_isDragging ? (_dragValue ?? liveMs) : liveMs)
        .clamp(0.0, maxValue)
        .toDouble();

    return Column(
      children: [
        Slider(
          value: sliderValue,
          max: maxValue,
          onChangeStart: canSeek
              ? (_) => setState(() => _isDragging = true)
              : null,
          onChanged: canSeek
              ? (value) => setState(() => _dragValue = value)
              : null,
          onChangeEnd: canSeek
              ? (value) async {
                  setState(() {
                    _isDragging = false;
                    _dragValue = null;
                  });
                  await player.seek(
                    Duration(milliseconds: value.round()),
                  );
                }
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(sliderValue),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                canSeek ? _formatDuration(maxValue) : '--:--',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
