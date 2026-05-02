import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/news_item.dart';
import '../services/api_service.dart';
import 'settings_provider.dart';

// 👍/👎 feedback per item
class FeedbackNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};

  void setFeedback(String itemId, bool liked) {
    final current = state[itemId];
    if (current == liked) {
      state = {...state}..remove(itemId);
    } else {
      state = {...state, itemId: liked};
    }
  }
}

final feedbackProvider =
    NotifierProvider<FeedbackNotifier, Map<String, bool>>(FeedbackNotifier.new);

// Gelezen items
class ReadItemsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void markRead(String itemId) {
    if (!state.contains(itemId)) {
      state = {...state, itemId};
    }
  }
}

final readItemsProvider =
    NotifierProvider<ReadItemsNotifier, Set<String>>(ReadItemsNotifier.new);

// Geselecteerde categorie (null = alles)
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Toon ook al-gelezen items
final showReadProvider = StateProvider<bool>((ref) => false);

// Nieuws van de backend
class NewsNotifier extends AsyncNotifier<List<NewsItem>> {
  @override
  Future<List<NewsItem>> build() => ApiService.fetchNews();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(ApiService.fetchNews);
  }
}

final newsProvider =
    AsyncNotifierProvider<NewsNotifier, List<NewsItem>>(NewsNotifier.new);

// Gefilterde nieuwslijst (leeg tijdens laden)
final filteredNewsProvider = Provider<List<NewsItem>>((ref) {
  final items = ref.watch(newsProvider).valueOrNull ?? [];
  final enabledIds = ref.watch(enabledCategoryIdsProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final showRead = ref.watch(showReadProvider);
  final readItems = ref.watch(readItemsProvider);

  return items
      .where((item) => enabledIds.contains(item.category))
      .where((item) =>
          selectedCategory == null || item.category == selectedCategory)
      .where((item) => showRead || !readItems.contains(item.id))
      .toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
});

// Of de nieuws-feed nog aan het laden is
final newsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(newsProvider).isLoading;
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
