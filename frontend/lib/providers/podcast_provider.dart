import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/podcast.dart' show Podcast, TtsProvider;
import '../services/api_service.dart';
import 'auth_provider.dart';

class PodcastNotifier extends AsyncNotifier<List<Podcast>> {
  Timer? _pollTimer;

  @override
  Future<List<Podcast>> build() async {
    ref.onDispose(() => _pollTimer?.cancel());
    final auth = ref.watch(authProvider).valueOrNull;
    if (auth?.isLoggedIn != true) return [];
    final podcasts = await ApiService.fetchPodcasts();
    _schedulePollIfNeeded(podcasts);
    return podcasts;
  }

  void _schedulePollIfNeeded(List<Podcast> podcasts) {
    _pollTimer?.cancel();
    final hasActive = podcasts.any((p) => p.status.isGenerating);
    if (hasActive) {
      _pollTimer = Timer(const Duration(seconds: 4), () async {
        try {
          final updated = await ApiService.fetchPodcasts();
          state = AsyncData(updated);
          _schedulePollIfNeeded(updated);
        } catch (_) {}
      });
    }
  }

  Future<void> refresh() async {
    final result = await AsyncValue.guard(ApiService.fetchPodcasts);
    state = result;
    _schedulePollIfNeeded(result.valueOrNull ?? []);
  }

  Future<Podcast> create({
    required int periodDays,
    required int durationMinutes,
    List<String> customTopics = const [],
    TtsProvider ttsProvider = TtsProvider.openai,
  }) async {
    final podcast = await ApiService.createPodcast(
      periodDays: periodDays,
      durationMinutes: durationMinutes,
      customTopics: customTopics,
      ttsProvider: ttsProvider,
    );
    final current = state.valueOrNull ?? [];
    state = AsyncData([podcast, ...current]);
    _schedulePollIfNeeded([podcast]);
    return podcast;
  }

  Future<void> delete(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((p) => p.id != id).toList());
    await ApiService.deletePodcast(id);
  }
}

final podcastProvider =
    AsyncNotifierProvider<PodcastNotifier, List<Podcast>>(PodcastNotifier.new);
