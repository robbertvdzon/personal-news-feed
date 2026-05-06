import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rss_feeds_settings.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class RssFeedsNotifier extends AsyncNotifier<RssFeedsSettings> {
  @override
  Future<RssFeedsSettings> build() async {
    final auth = ref.watch(authProvider).valueOrNull;
    if (auth?.isLoggedIn != true) return const RssFeedsSettings();
    return ApiService.fetchRssFeeds();
  }

  Future<void> addFeed(String url) async {
    final current = state.valueOrNull ?? const RssFeedsSettings();
    if (current.feeds.contains(url)) return;
    final updated = current.copyWith(feeds: [...current.feeds, url]);
    state = AsyncData(updated);
    await ApiService.saveRssFeeds(updated);
  }

  Future<void> removeFeed(String url) async {
    final current = state.valueOrNull ?? const RssFeedsSettings();
    final updated = current.copyWith(
      feeds: current.feeds.where((f) => f != url).toList(),
    );
    state = AsyncData(updated);
    await ApiService.saveRssFeeds(updated);
  }

  Future<void> setFeeds(List<String> feeds) async {
    final updated = RssFeedsSettings(feeds: feeds);
    state = AsyncData(updated);
    await ApiService.saveRssFeeds(updated);
  }
}

final rssFeedsProvider =
    AsyncNotifierProvider<RssFeedsNotifier, RssFeedsSettings>(RssFeedsNotifier.new);
