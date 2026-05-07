import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feed_item.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';
import 'news_provider.dart' show showReadProvider;

// Feed items van de backend (/api/feed)
class FeedNotifier extends AsyncNotifier<List<FeedItem>> {
  @override
  Future<List<FeedItem>> build() async {
    final auth = ref.watch(authProvider).valueOrNull;
    if (auth?.isLoggedIn != true) return [];
    return ApiService.fetchFeedItems();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(ApiService.fetchFeedItems);
  }

  Future<void> deleteItem(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((i) => i.id != id).toList());
    await ApiService.deleteFeedItem(id);
  }
}

final feedProvider =
    AsyncNotifierProvider<FeedNotifier, List<FeedItem>>(FeedNotifier.new);

// Gelezen staat voor feed items
class FeedReadNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final items = ref.watch(feedProvider).valueOrNull ?? [];
    return items.where((i) => i.isRead).map((i) => i.id).toSet();
  }

  void markRead(String id) {
    state = {...state, id};
    ApiService.markFeedRead(id);
  }

  void markUnread(String id) {
    state = Set.from(state)..remove(id);
    ApiService.markFeedUnread(id);
  }
}

final feedReadItemsProvider =
    NotifierProvider<FeedReadNotifier, Set<String>>(FeedReadNotifier.new);

// Ster-staat voor feed items
class FeedStarredNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final items = ref.watch(feedProvider).valueOrNull ?? [];
    return items.where((i) => i.starred).map((i) => i.id).toSet();
  }

  void toggleStar(String id) {
    final current = Set<String>.from(state);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = current;
    ApiService.toggleFeedStar(id);
  }
}

final feedStarredItemsProvider =
    NotifierProvider<FeedStarredNotifier, Set<String>>(FeedStarredNotifier.new);

// Feedback (liked/disliked) voor feed items
class FeedFeedbackNotifier extends Notifier<Map<String, bool?>> {
  @override
  Map<String, bool?> build() {
    final items = ref.watch(feedProvider).valueOrNull ?? [];
    return {for (final i in items) if (i.liked != null) i.id: i.liked};
  }

  void setFeedback(String id, bool? liked) {
    state = {...state, id: liked};
    ApiService.setFeedItemFeedback(id, liked);
  }
}

final feedFeedbackProvider =
    NotifierProvider<FeedFeedbackNotifier, Map<String, bool?>>(
        FeedFeedbackNotifier.new);

// Gefilterde feed items (respecteert showRead toggle + geselecteerde categorie)
final filteredFeedProvider = Provider<List<FeedItem>>((ref) {
  final items = ref.watch(feedProvider).valueOrNull ?? [];
  final showRead = ref.watch(showReadProvider);
  final readItems = ref.watch(feedReadItemsProvider);
  final showStarred = ref.watch(feedShowStarredProvider);
  final starredItems = ref.watch(feedStarredItemsProvider);
  final showSummary = ref.watch(feedShowSummaryProvider);
  final selectedCategory = ref.watch(selectedFeedCategoryProvider);

  if (showStarred) {
    return items.where((i) => starredItems.contains(i.id)).toList();
  }

  if (showSummary) {
    return items
        .where((i) => i.isSummary)
        .where((i) => showRead || !readItems.contains(i.id))
        .toList();
  }

  // Reguliere tabs: sluit samenvatting-items uit
  return items
      .where((i) => !i.isSummary)
      .where((i) => selectedCategory == null || i.category == selectedCategory)
      .where((i) => showRead || !readItems.contains(i.id))
      .toList();
});

// Toon alleen bewaarde feed-items
final feedShowStarredProvider = StateProvider<bool>((ref) => false);

// Toon alleen dagelijkse samenvatting-items
final feedShowSummaryProvider = StateProvider<bool>((ref) => false);

// Geselecteerde categorie in de feed-tab (null = alles)
final selectedFeedCategoryProvider = StateProvider<String?>((ref) => null);

// Ongelezen feed-items per categorie (exclusief samenvatting-items)
final feedUnreadCountByCategoryProvider = Provider<Map<String, int>>((ref) {
  final items = ref.watch(feedProvider).valueOrNull ?? [];
  final readItems = ref.watch(feedReadItemsProvider);
  final counts = <String, int>{};
  for (final item in items) {
    if (item.isSummary) continue;
    if (readItems.contains(item.id)) continue;
    counts[item.category] = (counts[item.category] ?? 0) + 1;
  }
  return counts;
});

// Ongelezen samenvatting-items
final feedUnreadSummaryCountProvider = Provider<int>((ref) {
  final items = ref.watch(feedProvider).valueOrNull ?? [];
  final readItems = ref.watch(feedReadItemsProvider);
  return items.where((i) => i.isSummary && !readItems.contains(i.id)).length;
});

// Samenvatting-items (voor zichtbaarheid van de tab)
final feedSummaryItemsProvider = Provider<List<FeedItem>>((ref) {
  return ref.watch(feedProvider).valueOrNull?.where((i) => i.isSummary).toList() ?? [];
});

// Aantal gelezen items in huidige feed-filtercombinatie
final feedReadCountProvider = Provider<int>((ref) {
  final items = ref.watch(feedProvider).valueOrNull ?? [];
  final readItems = ref.watch(feedReadItemsProvider);
  final showSummary = ref.watch(feedShowSummaryProvider);
  final selectedCategory = ref.watch(selectedFeedCategoryProvider);

  if (showSummary) {
    return items.where((i) => i.isSummary && readItems.contains(i.id)).length;
  }
  return items
      .where((i) => !i.isSummary)
      .where((i) => selectedCategory == null || i.category == selectedCategory)
      .where((i) => readItems.contains(i.id))
      .length;
});

// Of de feed nog aan het laden is
final feedLoadingProvider = Provider<bool>((ref) {
  return ref.watch(feedProvider).isLoading;
});

// Aantal ongelezen feed items
final feedUnreadCountProvider = Provider<int>((ref) {
  final items = ref.watch(feedProvider).valueOrNull ?? [];
  final readItems = ref.watch(feedReadItemsProvider);
  return items.where((i) => !readItems.contains(i.id)).length;
});
