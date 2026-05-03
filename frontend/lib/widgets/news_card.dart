import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../models/news_item.dart';
import '../providers/news_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/item_detail_screen.dart';
import 'category_badge.dart';

class NewsCard extends ConsumerWidget {
  final NewsItem item;
  final List<NewsItem> allItems;
  final int index;

  const NewsCard({
    super.key,
    required this.item,
    required this.allItems,
    required this.index,
  });

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min geleden';
    if (diff.inHours < 24) return '${diff.inHours} uur geleden';
    return '${diff.inDays} dag${diff.inDays == 1 ? '' : 'en'} geleden';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(feedbackProvider);
    final liked = feedback[item.id]; // bool? — null=geen, true=👍, false=👎
    final readItems = ref.watch(readItemsProvider);
    final isRead = readItems.contains(item.id);
    final starredItems = ref.watch(starredItemsProvider);
    final isStarred = starredItems.contains(item.id);
    final categories = ref.watch(settingsProvider).valueOrNull ?? [];
    final category = categories.isEmpty
        ? Category(id: item.category, name: item.category)
        : categories.firstWhere(
            (c) => c.id == item.category,
            orElse: () => categories.first,
          );

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => ref.read(newsProvider.notifier).deleteItem(item.id),
      child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: isRead ? 0 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isRead ? Colors.grey[50] : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(
              items: allItems,
              initialIndex: index,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRead
                        ? Colors.transparent
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CategoryBadge(
                          categoryId: item.category,
                          categoryName: category.name,
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(item.timestamp),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.w600,
                            color: isRead ? Colors.grey[600] : null,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                isRead ? Colors.grey[400] : Colors.grey[600],
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          item.source,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                        ),
                        const Spacer(),
                        _FeedbackButton(
                          icon: '👍',
                          active: liked == true,
                          onTap: () => ref
                              .read(feedbackProvider.notifier)
                              .setFeedback(item.id, true),
                        ),
                        const SizedBox(width: 4),
                        _FeedbackButton(
                          icon: '👎',
                          active: liked == false,
                          onTap: () => ref
                              .read(feedbackProvider.notifier)
                              .setFeedback(item.id, false),
                        ),
                        const SizedBox(width: 4),
                        _StarButton(
                          active: isStarred,
                          onTap: () => ref
                              .read(starredItemsProvider.notifier)
                              .toggleStar(item.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ), // Card
    ); // Dismissible
  }
}

class _FeedbackButton extends StatelessWidget {
  final String icon;
  final bool active;
  final VoidCallback onTap;

  const _FeedbackButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(icon, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _StarButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _StarButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.amber[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          active ? Icons.star : Icons.star_border,
          size: 18,
          color: active ? Colors.amber[600] : Colors.grey[400],
        ),
      ),
    );
  }
}
