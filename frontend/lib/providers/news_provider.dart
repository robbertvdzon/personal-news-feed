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

// Geselecteerde categorie voor RSS-scherm (null = alles, '__overig__' = overig)
const kRssOverigCategory = '__overig__';
final selectedRssCategoryProvider = StateProvider<String?>((ref) => null);

// Toon ook al-gelezen items
final showReadProvider = StateProvider<bool>((ref) => false);

// Toon alleen bewaarde (gesterrde) items
final showStarredProvider = StateProvider<bool>((ref) => false);

// Nieuws van de backend (feed-items: inFeed=true)
class NewsNotifier extends AsyncNotifier<List<NewsItem>> {
  @override
  Future<List<NewsItem>> build() async {
    final auth = ref.watch(authProvider).valueOrNull;
    if (auth?.isLoggedIn != true) return [];
    final items = await ApiService.fetchNews();
    _syncCachesFromItems(items);
    return items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final items = await AsyncValue.guard(ApiService.fetchNews);
    state = items;
    final loaded = items.valueOrNull;
    if (loaded != null) _syncCachesFromItems(loaded);
  }

  void _syncCachesFromItems(List<NewsItem> items) {
    final alreadyRead = items.where((i) => i.isRead).map((i) => i.id).toSet();
    ref.read(readItemsProvider.notifier).initFromBackend(alreadyRead);
    final alreadyStarred = items.where((i) => i.starred).map((i) => i.id).toSet();
    ref.read(starredItemsProvider.notifier).initFromBackend(alreadyStarred);
    final feedbackMap = {
      for (final i in items) if (i.liked != null) i.id: i.liked
    };
    ref.read(feedbackProvider.notifier).initFromBackend(feedbackMap);
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
        final feedItems = await ApiService.fetchNews();
        final rssItems = await ApiService.fetchRssItems();
        if (state.valueOrNull != null) {
          state = AsyncData(feedItems);
          _syncCachesFromItems(feedItems);
        }
        ref.read(rssItemsProvider.notifier).setItems(rssItems);
      } catch (_) {}
    });
    try {
      await ApiService.refreshNews();
      await refresh();
      // Ververs ook de RSS-items
      ref.read(rssItemsProvider.notifier).refresh();
    } finally {
      pollTimer.cancel();
      ref.read(_sourceRefreshingProvider.notifier).state = false;
    }
  }
}

final newsProvider =
    AsyncNotifierProvider<NewsNotifier, List<NewsItem>>(NewsNotifier.new);

final _sourceRefreshingProvider = StateProvider<bool>((ref) => false);

final sourceRefreshingProvider = Provider<bool>((ref) =>
    ref.watch(_sourceRefreshingProvider));

// Alle RSS-items (inclusief niet-feed items)
class RssItemsNotifier extends AsyncNotifier<List<NewsItem>> {
  @override
  Future<List<NewsItem>> build() async {
    final auth = ref.watch(authProvider).valueOrNull;
    if (auth?.isLoggedIn != true) return [];
    return ApiService.fetchRssItems();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(ApiService.fetchRssItems);
  }

  void setItems(List<NewsItem> items) {
    state = AsyncData(items);
  }
}

final rssItemsProvider =
    AsyncNotifierProvider<RssItemsNotifier, List<NewsItem>>(RssItemsNotifier.new);

// Gefilterde RSS-items — per categorie + gelezen filter
// Items zonder bekende categorie vallen onder kRssOverigCategory
final filteredRssItemsProvider = Provider<List<NewsItem>>((ref) {
  final items = ref.watch(rssItemsProvider).valueOrNull ?? [];
  final readItems = ref.watch(readItemsProvider);
  final enabledIds = ref.watch(enabledCategoryIdsProvider);
  final selectedCategory = ref.watch(selectedRssCategoryProvider);
  final showRead = ref.watch(showReadProvider);

  bool matchesCategory(NewsItem item) {
    if (selectedCategory == null) return true;
    final isOverig = item.category.isEmpty || !enabledIds.contains(item.category);
    if (selectedCategory == kRssOverigCategory) return isOverig;
    return item.category == selectedCategory;
  }

  return items
      .where(matchesCategory)
      .where((item) => showRead || !readItems.contains(item.id))
      .toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
});

// Of de RSS-feed nog aan het laden is
final rssLoadingProvider = Provider<bool>((ref) =>
    ref.watch(rssItemsProvider).isLoading);

// Ongelezen RSS-items per categorie-ID + '__overig__'
final rssUnreadCountByCategoryProvider = Provider<Map<String, int>>((ref) {
  final items = ref.watch(rssItemsProvider).valueOrNull ?? [];
  final readItems = ref.watch(readItemsProvider);
  final enabledIds = ref.watch(enabledCategoryIdsProvider);
  final counts = <String, int>{};
  for (final item in items) {
    if (readItems.contains(item.id) || item.isRead) continue;
    final isOverig = item.category.isEmpty || !enabledIds.contains(item.category);
    final key = isOverig ? kRssOverigCategory : item.category;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
});

// Aantal gelezen RSS-items in huidige filtercombinatie
final rssReadCountProvider = Provider<int>((ref) {
  final items = ref.watch(rssItemsProvider).valueOrNull ?? [];
  final readItems = ref.watch(readItemsProvider);
  final enabledIds = ref.watch(enabledCategoryIdsProvider);
  final selectedCategory = ref.watch(selectedRssCategoryProvider);

  bool matchesCategory(NewsItem item) {
    if (selectedCategory == null) return true;
    final isOverig = item.category.isEmpty || !enabledIds.contains(item.category);
    if (selectedCategory == kRssOverigCategory) return isOverig;
    return item.category == selectedCategory;
  }

  return items.where(matchesCategory).where((i) => readItems.contains(i.id)).length;
});
