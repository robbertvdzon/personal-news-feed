import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/news_item.dart';
import '../data/mock_data.dart';
import 'settings_provider.dart';

// Bijhoudt welke items geliked of gedisliked zijn: id -> true (liked) / false (disliked)
class FeedbackNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};

  void setFeedback(String itemId, bool liked) {
    final current = state[itemId];
    if (current == liked) {
      // Tweede klik op hetzelfde knopje verwijdert de feedback
      state = {...state}..remove(itemId);
    } else {
      state = {...state, itemId: liked};
    }
  }
}

final feedbackProvider =
    NotifierProvider<FeedbackNotifier, Map<String, bool>>(
  FeedbackNotifier.new,
);

final filteredNewsProvider = Provider<List<NewsItem>>((ref) {
  final enabledIds = ref.watch(enabledCategoryIdsProvider);
  return mockNewsItems
      .where((item) => enabledIds.contains(item.category))
      .toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
});
