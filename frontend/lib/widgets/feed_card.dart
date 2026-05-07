import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feed_item.dart';
import '../providers/feed_provider.dart';
import '../screens/feed_item_detail_screen.dart';

class FeedCard extends ConsumerWidget {
  final FeedItem item;
  final List<FeedItem> allItems;
  final int index;

  const FeedCard({
    super.key,
    required this.item,
    required this.allItems,
    required this.index,
  });

  String _formatFeedTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m geleden';
    if (diff.inHours < 24) return '${diff.inHours}u geleden';
    return '${dt.day}-${dt.month}-${dt.year}';
  }

  String _formatArticlePubDate(DateTime? pubDate) {
    if (pubDate == null) return 'onbekend';
    return '${pubDate.day}-${pubDate.month}-${pubDate.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.isSummary) {
      return _SummaryFeedCard(item: item, allItems: allItems, index: index);
    }

    final feedback = ref.watch(feedFeedbackProvider);
    final liked = feedback[item.id];
    final readItems = ref.watch(feedReadItemsProvider);
    final isRead = readItems.contains(item.id);
    final starredItems = ref.watch(feedStarredItemsProvider);
    final isStarred = starredItems.contains(item.id);

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
      onDismissed: (_) =>
          ref.read(feedProvider.notifier).deleteItem(item.id),
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
              builder: (_) => FeedItemDetailScreen(
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
                          if (item.category.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.category,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatFeedTime(item.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                              ),
                              Text(
                                'art: ${_formatArticlePubDate(item.publishedDate)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[400],
                                      fontSize: 10,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                  color: isRead ? Colors.grey[600] : null,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.summary,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isRead
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  height: 1.4,
                                ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            item.source,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                          const Spacer(),
                          _FeedbackButton(
                            icon: '👍',
                            active: liked == true,
                            onTap: () {
                              final current = feedback[item.id];
                              final newValue = current == true ? null : true;
                              ref
                                  .read(feedFeedbackProvider.notifier)
                                  .setFeedback(item.id, newValue);
                            },
                          ),
                          const SizedBox(width: 4),
                          _FeedbackButton(
                            icon: '👎',
                            active: liked == false,
                            onTap: () {
                              final current = feedback[item.id];
                              final newValue = current == false ? null : false;
                              ref
                                  .read(feedFeedbackProvider.notifier)
                                  .setFeedback(item.id, newValue);
                            },
                          ),
                          const SizedBox(width: 4),
                          _StarButton(
                            active: isStarred,
                            onTap: () => ref
                                .read(feedStarredItemsProvider.notifier)
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
      ),
    );
  }
}

// ── Speciale kaart voor de dagelijkse AI-samenvatting ─────────────────────────

class _SummaryFeedCard extends ConsumerWidget {
  final FeedItem item;
  final List<FeedItem> allItems;
  final int index;

  const _SummaryFeedCard({
    required this.item,
    required this.allItems,
    required this.index,
  });

  String _formatFeedTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m geleden';
    if (diff.inHours < 24) return '${diff.inHours}u geleden';
    return '${dt.day}-${dt.month}-${dt.year}';
  }

  /// Strips markdown markers zodat de preview-tekst schoon leesbaar is.
  String _plainPreview(String markdown) {
    return markdown
        .split('\n')
        .map((line) {
          if (line.startsWith('# '))   return line.substring(2);
          if (line.startsWith('## '))  return line.substring(3);
          if (line.startsWith('### ')) return line.substring(4);
          if (line.startsWith('- ') || line.startsWith('* ')) return '• ${line.substring(2)}';
          return line;
        })
        .join(' ')
        .replaceAll(RegExp(r'\*\*\*(.+?)\*\*\*'), r'$1')
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll(RegExp(r'_(.+?)_'), r'$1')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readItems = ref.watch(feedReadItemsProvider);
    final isRead = readItems.contains(item.id);
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: isRead ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: tertiaryColor.withValues(alpha: isRead ? 0.15 : 0.4),
          width: 1.5,
        ),
      ),
      color: isRead
          ? Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.08)
          : Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.25),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FeedItemDetailScreen(
              items: allItems,
              initialIndex: index,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: isRead ? Colors.grey[400] : tertiaryColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.w700,
                            color: isRead ? Colors.grey[500] : tertiaryColor,
                          ),
                    ),
                  ),
                  Text(
                    _formatFeedTime(item.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _plainPreview(item.summary),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isRead ? Colors.grey[400] : Colors.grey[700],
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Lees volledige samenvatting →',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isRead ? Colors.grey[400] : tertiaryColor,
                          fontWeight: FontWeight.w500,
                        ),
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
