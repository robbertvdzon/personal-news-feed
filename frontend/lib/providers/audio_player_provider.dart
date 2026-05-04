import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class AudioLoadState {
  final String? podcastId;
  final String? podcastTitle;
  final bool isLoading;
  final String? errorMessage;
  /// Bekende duur uit de podcast-metadata — fallback als de speler het niet detecteert
  final int? knownDurationSeconds;

  const AudioLoadState({
    this.podcastId,
    this.podcastTitle,
    this.isLoading = false,
    this.errorMessage,
    this.knownDurationSeconds,
  });

  bool get hasContent =>
      podcastId != null && !isLoading && errorMessage == null;

  Duration? get knownDuration => knownDurationSeconds != null
      ? Duration(seconds: knownDurationSeconds!)
      : null;

  AudioLoadState withLoading(String id, String title, int? durationSecs) =>
      AudioLoadState(podcastId: id, podcastTitle: title, isLoading: true, knownDurationSeconds: durationSecs);

  AudioLoadState withReady(String id, String title, int? durationSecs) =>
      AudioLoadState(podcastId: id, podcastTitle: title, knownDurationSeconds: durationSecs);

  AudioLoadState withError(String id, String title, String msg) =>
      AudioLoadState(podcastId: id, podcastTitle: title, errorMessage: msg);
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class AudioPlayerNotifier extends Notifier<AudioLoadState> {
  late final AudioPlayer _player;
  Timer? _saveTimer;

  static const _prefPrefix = 'podcast_pos_';

  @override
  AudioLoadState build() {
    _player = AudioPlayer();
    ref.onDispose(() {
      _saveTimer?.cancel();
      _player.dispose();
    });
    return const AudioLoadState();
  }

  AudioPlayer get player => _player;

  bool isCurrentPodcast(String id) => state.podcastId == id;

  Duration? get knownDuration => state.knownDuration;

  // Sla positie op in SharedPreferences
  Future<void> _savePosition(String podcastId, Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        '$_prefPrefix$podcastId', position.inSeconds);
  }

  // Laad opgeslagen positie (null = onbekend of begin)
  Future<Duration?> _loadPosition(String podcastId) async {
    final prefs = await SharedPreferences.getInstance();
    final secs = prefs.getInt('$_prefPrefix$podcastId');
    return secs != null ? Duration(seconds: secs) : null;
  }

  // Start periodiek opslaan (elke 5 seconden)
  void _startSaving(String podcastId) {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final pos = _player.position;
      // Gebruik de echte duur of de bekende duur als fallback
      final dur = _player.duration ?? state.knownDuration;
      // Niet opslaan als bijna aan het einde (zodat hij opnieuw begint)
      if (dur != null && dur.inSeconds > 10 &&
          pos.inSeconds < dur.inSeconds - 10) {
        _savePosition(podcastId, pos);
      }
    });
  }

  Future<void> loadAndPlay(String podcastId, String title, {int? durationSeconds}) async {
    // Zelfde podcast al geladen → alleen toggle play/pause
    if (state.podcastId == podcastId &&
        !state.isLoading &&
        state.errorMessage == null) {
      await togglePlayPause();
      return;
    }

    _saveTimer?.cancel();
    state = state.withLoading(podcastId, title, durationSeconds);
    try {
      await _player.stop();

      final url = ApiService.podcastAudioUrl(podcastId);
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));

      // Herstel opgeslagen positie
      final savedPos = await _loadPosition(podcastId);
      if (savedPos != null && savedPos.inSeconds > 0) {
        await _player.seek(savedPos);
      }

      state = state.withReady(podcastId, title, durationSeconds);
      _startSaving(podcastId);
      await _player.play();
    } catch (e) {
      state = state.withError(podcastId, title, e.toString());
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      // Opslaan bij pauze
      final id = state.podcastId;
      if (id != null) await _savePosition(id, _player.position);
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    final id = state.podcastId;
    if (id != null) await _savePosition(id, position);
  }
}

final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioLoadState>(
  AudioPlayerNotifier.new,
);
