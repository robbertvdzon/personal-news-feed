import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/news_item.dart';
import '../providers/news_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/item_detail_screen.dart';
import 'category_badge.dart';

class NewsCard extends ConsumerWidget {
  final NewsItem item;

  const NewsCard({super.key, required this.item});

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min geleden';
    if (diff.inHours < 24) return '${diff.inHours} uur geleden';
    return '${diff.inDays} dag${diff.inDays == 1 ? '' : 'en'} geleden';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(feedbackProvider);
    final liked = feedback[item.id];
    final categories = ref.watch(settingsProvider);
    final category = categories.firstWhere(
      (c) => c.id == item.category,
      orElse: () => categories.first,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(item: item),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                item.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    item.source,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
