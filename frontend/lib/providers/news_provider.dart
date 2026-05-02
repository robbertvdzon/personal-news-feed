import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/news_item.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';
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
  Future<List<NewsItem>> build() async {
    final auth = ref.watch(authProvider).valueOrNull;
    if (auth?.isLoggedIn != true) return [];
    final items = await ApiService.fetchNews();
    // Initialiseer lokale read-cache vanuit backend staat
    final alreadyRead = items.where((i) => i.isRead).map((i) => i.id).toSet();
    ref.read(readItemsProvider.notifier).initFromBackend(alreadyRead);
    return items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final items = await AsyncValue.guard(ApiService.fetchNews);
    state = items;
    // Sync read-cache na refresh
    final loaded = items.valueOrNull;
    if (loaded != null) {
      final alreadyRead = loaded.where((i) => i.isRead).map((i) => i.id).toSet();
      ref.read(readItemsProvider.notifier).initFromBackend(alreadyRead);
    }
  }

  void setItems(List<NewsItem> items) {
    state = AsyncData(items);
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
