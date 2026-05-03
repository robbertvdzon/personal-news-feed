import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class AudioLoadState {
  final String? podcastId;
  final String? podcastTitle;
  final bool isLoading;
  final String? errorMessage;

  const AudioLoadState({
    this.podcastId,
    this.podcastTitle,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasContent =>
      podcastId != null && !isLoading && errorMessage == null;

  AudioLoadState withLoading(String id, String title) =>
      AudioLoadState(podcastId: id, podcastTitle: title, isLoading: true);

  AudioLoadState withReady(String id, String title) =>
      AudioLoadState(podcastId: id, podcastTitle: title);

  AudioLoadState withError(String id, String title, String msg) =>
      AudioLoadState(podcastId: id, podcastTitle: title, errorMessage: msg);
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class AudioPlayerNotifier extends Notifier<AudioLoadState> {
  late final AudioPlayer _player;

  @override
  AudioLoadState build() {
    _player = AudioPlayer();
    ref.onDispose(_player.dispose);
    return const AudioLoadState();
  }

  AudioPlayer get player => _player;

  bool isCurrentPodcast(String id) => state.podcastId == id;

  Future<void> loadAndPlay(String podcastId, String title) async {
    // Zelfde podcast al geladen → alleen toggle play/pause
    if (state.podcastId == podcastId &&
        !state.isLoading &&
        state.errorMessage == null) {
      await togglePlayPause();
      return;
    }

    state = state.withLoading(podcastId, title);
    try {
      await _player.stop();

      // Audio-URL bevat het JWT-token als query-param.
      // AudioSource.uri() werkt op alle platforms inclusief web
      // (StreamAudioSource is niet ondersteund door webbrowsers).
      final url = ApiService.podcastAudioUrl(podcastId);
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));

      state = state.withReady(podcastId, title);
      await _player.play();
    } catch (e) {
      state = state.withError(podcastId, title, e.toString());
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);
}

final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioLoadState>(
  AudioPlayerNotifier.new,
);
