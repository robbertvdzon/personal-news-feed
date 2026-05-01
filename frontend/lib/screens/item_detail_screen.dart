import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_item.dart';
import '../providers/news_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/category_badge.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final NewsItem item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Item markeren als gelezen zodra het scherm opent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(readItemsProvider.notifier).markRead(widget.item.id);
    });
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}-${dt.month}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openUrl() async {
    final uri = Uri.parse(widget.item.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kan de link niet openen')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = ref.watch(feedbackProvider);
    final liked = feedback[widget.item.id];
    final categories = ref.watch(settingsProvider);
    final category = categories.firstWhere(
      (c) => c.id == widget.item.category,
      orElse: () => categories.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Artikel'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryBadge(
              categoryId: widget.item.category,
              categoryName: category.name,
            ),
            const SizedBox(height: 12),
            Text(
              widget.item.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(widget.item.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.source_outlined, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  widget.item.source,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              widget.item.summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 24),
            _SourceLinkCard(url: widget.item.url, onTap: _openUrl),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Wat vind je van dit artikel?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LargeFeedbackButton(
                  icon: '👍',
                  label: 'Interessant',
                  active: liked == true,
                  onTap: () => ref
                      .read(feedbackProvider.notifier)
                      .setFeedback(widget.item.id, true),
                ),
                const SizedBox(width: 16),
                _LargeFeedbackButton(
                  icon: '👎',
                  label: 'Niet relevant',
                  active: liked == false,
                  onTap: () => ref
                      .read(feedbackProvider.notifier)
                      .setFeedback(widget.item.id, false),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SourceLinkCard extends StatelessWidget {
  final String url;
  final VoidCallback onTap;

  const _SourceLinkCard({required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link gekopieerd')),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.open_in_new,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lees origineel artikel',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeFeedbackButton extends StatelessWidget {
  final String icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LargeFeedbackButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
