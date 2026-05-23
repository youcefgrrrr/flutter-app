import 'dart:async'; // Timer

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/surah_category.dart';
import 'stats_service.dart';

class AudioPlayerService extends ChangeNotifier {
  AudioPlayerService() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durationSub;

  AudioTrack? currentTrack;
  bool isPlaying = false;
  bool repeatOne = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  Duration bufferedPosition = Duration.zero;
  int _sessionSeconds = 0;

  StatsService? _statsService;

  void bindStats(StatsService stats) => _statsService = stats;

  Future<void> _init() async {
    await AudioService.init(
      builder: () => _BackgroundHandler(_player),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.secureaudio.player',
        androidNotificationChannelName: 'Lecture audio',
        androidNotificationOngoing: true,
      ),
    );

    _positionSub = _player.positionStream.listen((pos) {
      position = pos;
      bufferedPosition = _player.bufferedPosition;
      final detected = _player.duration;
      if (duration == Duration.zero &&
          detected != null &&
          detected > Duration.zero) {
        duration = detected;
      }
      notifyListeners();
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        duration = dur;
        notifyListeners();
      }
    });

    _stateSub = _player.playerStateStream.listen((state) async {
      isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        await _onTrackCompleted();
      }
      notifyListeners();
    });

    Timer.periodic(const Duration(seconds: 1), (_) {
      if (_player.playing) _sessionSeconds++;
    });
  }

  Future<void> playTrack(AudioTrack track) async {
    if (currentTrack?.id != track.id) {
      await _flushSession();
      currentTrack = track;
      _sessionSeconds = 0;
      position = Duration.zero;
      duration = Duration.zero;
      notifyListeners();
      final loadedDuration = await _player.setUrl(track.audioUrl);
      if (loadedDuration != null && loadedDuration > Duration.zero) {
        duration = loadedDuration;
      } else {
        final fromPlayer = _player.duration;
        if (fromPlayer != null && fromPlayer > Duration.zero) {
          duration = fromPlayer;
        }
      }
      notifyListeners();
      final mediaItem = MediaItem(
        id: track.id,
        title: track.reciter,
        artist: track.surahName,
        extras: {'url': track.audioUrl},
      );
      await AudioService.updateMediaItem(mediaItem);
    }
    await _player.play();
    notifyListeners();
  }

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await _player.play();
    }
  }

  void toggleRepeatOne() {
    repeatOne = !repeatOne;
    _player.setLoopMode(repeatOne ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  Future<void> seek(Duration target) async {
    var clamped = target;
    if (clamped < Duration.zero) {
      clamped = Duration.zero;
    } else if (duration > Duration.zero && clamped > duration) {
      clamped = duration;
    }
    position = clamped;
    notifyListeners();
    await _player.seek(clamped);
  }

  Future<void> seekRelative(int seconds) async {
    await seek(position + Duration(seconds: seconds));
  }

  Future<void> _onTrackCompleted() async {
    await _flushSession();
    if (repeatOne && currentTrack != null) {
      await _player.seek(Duration.zero);
      await _player.play();
    }
  }

  Future<void> _flushSession() async {
    if (currentTrack != null && _sessionSeconds > 0) {
      await _statsService?.recordListening(
        track: currentTrack!,
        listenedSeconds: _sessionSeconds,
      );
      _sessionSeconds = 0;
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

class _BackgroundHandler extends BaseAudioHandler with SeekHandler {
  _BackgroundHandler(this._player) {
    _player.playbackEventStream.listen((_) => _broadcastState());
  }

  final AudioPlayer _player;

  void _broadcastState() {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          _player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: 0,
      ),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);
}
