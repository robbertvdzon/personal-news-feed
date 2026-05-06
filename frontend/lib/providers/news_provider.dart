import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/news_item.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

// 👍/👎 feedback per item — wordt ook naar de backend gestuurd voor AI-gebruik
class FeedbackNotifier extends Notifier<Map<String, bool?>> {
  @override
  Map<String, bool?> build() => {};

  void initFromBackend(Map<String, bool?> feedback) {
    state = feedback;
  }

  Future<void> setFeedback(String itemId, bool liked) async {
    final current = state[itemId];
    final newValue = current == liked ? null : liked; // zelfde knop = verwijder feedback
    state = {...state, itemId: newValue};
    await ApiService.setFeedback(itemId, newValue);
    // Update ook het item in de news provider
    final items = ref.read(newsProvider).valueOrNull;
    if (items == null) return;
    final index = items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    final updated = [...items];
    updated[index] = updated[index].copyWith(liked: newValue);
    ref.read(newsProvider.notifier).setItems(updated);
  }
}

final feedbackProvider =
    NotifierProvider<FeedbackNotifier, Map<String, bool?>>(FeedbackNotifier.new);

// Bewaarde (gesterrde) items
class StarredItemsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void initFromBackend(Set<String> ids) {
    state = ids;
  }

  Future<void> toggleStar(String itemId) async {
    final isStarred = state.contains(itemId);
    state = isStarred ? ({...state}..remove(itemId)) : {...state, itemId};
    await ApiService.toggleStar(itemId);
    final items = ref.read(newsProvider).valueOrNull;
    if (items == null) return;
    final index = items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    final updated = [...items];
    updated[index] = updated[index].copyWith(starred: !isStarred);
    ref.read(newsProvider.notifier).setItems(updated);
  }
}

final starredItemsProvider =
    NotifierProvider<StarredItemsNotifier, Set<String>>(StarredItemsNotifier.new);

// Gelezen items — alleen lokale cache voor items die in deze sessie gelezen zijn
// De persistent staat komt via isRead op NewsItem vanuit de backend
class ReadItemsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void initFromBackend(Set<String> ids) {
    state = ids;
  }

  Future<void> markRead(String itemId) async {
    if (state.contains(itemId)) return;
    state = {...state, itemId};
    await ApiService.markRead(itemId);
    final items = ref.read(newsProvider).valueOrNull;
    if (items == null) return;
    final index = items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    final updated = [...items];
    updated[index] = updated[index].copyWith(isRead: true);
    ref.read(newsProvider.notifier).setItems(updated);
  }

  Future<void> markUnread(String itemId) async {
    state = {...state}..remove(itemId);
    await ApiService.markUnread(itemId);
    final items = ref.read(newsProvider).valueOrNull;
    if (items == null) return;
    final index = items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    final updated = [...items];
    updated[index] = updated[index].copyWith(isRead: false);
    ref.read(newsProvider.notifier).setItems(updated);
  }
}

final readItemsProvider =
    NotifierProvider<ReadItemsNotifier, Set<String>>(ReadItemsNotifier.new);

// Geselecteerde categorie (null = alles)
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Toon ook al-gelezen items
final showReadProvider = StateProvider<bool>((ref) => false);

// Toon alleen bewaarde (gesterrde) items
final showStarredProvider = StateProvider<bool>((ref) => false);

// Nieuws van de backend
class NewsNotifier extends AsyncNotifier<List<NewsItem>> {
  @override
  Future<List<NewsItem>> build() async {
    final auth = ref.watch(authProvider).valueOrNull;
    if (auth?.isLoggedIn != true) return [];
    final items = await ApiService.fetchNews();
    // Initialiseer lokale caches vanuit backend staat
    final alreadyRead = items.where((i) => i.isRead).map((i) => i.id).toSet();
    ref.read(readItemsProvider.notifier).initFromBackend(alreadyRead);
    final alreadyStarred = items.where((i) => i.starred).map((i) => i.id).toSet();
    ref.read(starredItemsProvider.notifier).initFromBackend(alreadyStarred);
    final feedbackMap = {
      for (final i in items) if (i.liked != null) i.id: i.liked
    };
    ref.read(feedbackProvider.notifier).initFromBackend(feedbackMap);
    return items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final items = await AsyncValue.guard(ApiService.fetchNews);
    state = items;
    // Sync caches na refresh
    final loaded = items.valueOrNull;
    if (loaded != null) {
      final alreadyRead = loaded.where((i) => i.isRead).map((i) => i.id).toSet();
      ref.read(readItemsProvider.notifier).initFromBackend(alreadyRead);
      final alreadyStarred = loaded.where((i) => i.starred).map((i) => i.id).toSet();
      ref.read(starredItemsProvider.notifier).initFromBackend(alreadyStarred);
      final feedbackMap = {
        for (final i in loaded) if (i.liked != null) i.id: i.liked
      };
      ref.read(feedbackProvider.notifier).initFromBackend(feedbackMap);
    }
  }

  void setItems(List<NewsItem> items) {
    state = AsyncData(items);
  }

  Future<int> cleanupNews({
    required int olderThanDays,
    required bool keepStarred,
    required bool keepLiked,
    required bool keepUnread,
  }) async {
    final removed = await ApiService.cleanupNews(
      olderThanDays: olderThanDays,
      keepStarred: keepStarred,
      keepLiked: keepLiked,
      keepUnread: keepUnread,
    );
    if (removed > 0) await refresh();
    return removed;
  }

  Future<void> deleteItem(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((i) => i.id != id).toList());
    await ApiService.deleteNewsItem(id);
  }

  Future<void> refreshFromSource() async {
    ref.read(_sourceRefreshingProvider.notifier).state = true;
    // Poll elke 4 seconden zodat nieuwe artikelen direct zichtbaar zijn
    final pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final items = await ApiService.fetchNews();
        if (state.valueOrNull != null) {
          state = AsyncData(items);
          _syncCaches(items);
        }
      } catch (_) {}
    });
    try {
      await ApiService.refreshNews();
      await refresh();
    } finally {
      pollTimer.cancel();
      ref.read(_sourceRefreshingProvider.notifier).state = false;
    }
  }

  void _syncCaches(List<NewsItem> items) {
    final alreadyRead = items.where((i) => i.isRead).map((i) => i.id).toSet();
    ref.read(readItemsProvider.notifier).initFromBackend(alreadyRead);
    final alreadyStarred = items.where((i) => i.starred).map((i) => i.id).toSet();
    ref.read(starredItemsProvider.notifier).initFromBackend(alreadyStarred);
  }
}

final newsProvider =
    AsyncNotifierProvider<NewsNotifier, List<NewsItem>>(NewsNotifier.new);

final _sourceRefreshingProvider = StateProvider<bool>((ref) => false);

final sourceRefreshingProvider = Provider<bool>((ref) =>
    ref.watch(_sourceRefreshingProvider));

// Gefilterde nieuwslijst (leeg tijdens laden)
final filteredNewsProvider = Provider<List<NewsItem>>((ref) {
  final items = ref.watch(newsProvider).valueOrNull ?? [];
  final enabledIds = ref.watch(enabledCategoryIdsProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final showRead = ref.watch(showReadProvider);
  final showStarred = ref.watch(showStarredProvider);
  final readItems = ref.watch(readItemsProvider);
  final starredItems = ref.watch(starredItemsProvider);

  if (showStarred) {
    // Bewaard-tab: toon alle gesterrde items (ook gelezen), geen categorie-filter
    return items
        .where((item) => starredItems.contains(item.id))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  return items
      .where((item) => item.isSummary || enabledIds.contains(item.category))
      .where((item) =>
          selectedCategory == null ||
          item.category == selectedCategory)
      .where((item) => showRead || !readItems.contains(item.id))
      .toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
});

// Of de nieuws-feed nog aan het laden is
final newsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(newsProvider).isLoading;
});

// Aantal ongelezen items per categorie-ID (voor badges op de tabs)
final unreadCountByCategoryProvider = Provider<Map<String, int>>((ref) {
  final items = ref.watch(newsProvider).valueOrNull ?? [];
  final readItems = ref.watch(readItemsProvider);
  final enabledIds = ref.watch(enabledCategoryIdsProvider);
  final counts = <String, int>{};
  for (final item in items) {
    final isUnread = !readItems.contains(item.id) && !item.isRead;
    if (!isUnread) continue;
    if (item.isSummary) {
      // Dagelijks overzicht telt mee voor de 'dagelijks-overzicht' tab
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    } else if (enabledIds.contains(item.category)) {
      // Gewone items alleen tellen als de categorie actief is
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
  }
  return counts;
});

// Aantal gelezen items in de huidige filtercombinatie
final readCountProvider = Provider<int>((ref) {
  final items = ref.watch(newsProvider).valueOrNull ?? [];
  final enabledIds = ref.watch(enabledCategoryIdsProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final readItems = ref.watch(readItemsProvider);

  return items
      .where((item) => enabledIds.contains(item.category))
      .where((item) =>
          selectedCategory == null || item.category == selectedCategory)
      .where((item) => readItems.contains(item.id))
      .length;
});
