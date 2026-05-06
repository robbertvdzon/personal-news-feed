import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_item.dart';
import '../providers/news_provider.dart';
import '../providers/request_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/category_badge.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final List<NewsItem> items;
  final int initialIndex;

  const ItemDetailScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _markCurrentRead();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _markCurrentRead() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(readItemsProvider.notifier)
          .markRead(widget.items[_currentIndex].id);
    });
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;

    final currentItem = widget.items[_currentIndex];
    final starredItems = ref.watch(starredItemsProvider);
    final isStarred = starredItems.contains(currentItem.id);
    final readItems = ref.watch(readItemsProvider);
    final isRead = readItems.contains(currentItem.id);
    final feedback = ref.watch(feedbackProvider);
    final liked = feedback[currentItem.id];

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentIndex + 1} / $total'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: liked == true ? 'Verwijder interessant' : 'Interessant',
            icon: Text(
              '👍',
              style: TextStyle(
                fontSize: 18,
                color: liked == true ? null : Colors.grey[400],
              ),
            ),
            onPressed: () => ref
                .read(feedbackProvider.notifier)
                .setFeedback(currentItem.id, true),
          ),
          IconButton(
            tooltip: liked == false ? 'Verwijder niet-relevant' : 'Niet relevant',
            icon: Text(
              '👎',
              style: TextStyle(
                fontSize: 18,
                color: liked == false ? null : Colors.grey[400],
              ),
            ),
            onPressed: () => ref
                .read(feedbackProvider.notifier)
                .setFeedback(currentItem.id, false),
          ),
          IconButton(
            tooltip: isRead ? 'Markeer als ongelezen' : 'Markeer als gelezen',
            icon: Icon(
              isRead ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined,
              color: isRead ? Colors.blue[400] : null,
            ),
            onPressed: () {
              if (isRead) {
                ref.read(readItemsProvider.notifier).markUnread(currentItem.id);
              } else {
                ref.read(readItemsProvider.notifier).markRead(currentItem.id);
              }
            },
          ),
          IconButton(
            tooltip: isStarred ? 'Verwijder uit bewaard' : 'Bewaar artikel',
            icon: Icon(
              isStarred ? Icons.star : Icons.star_border,
              color: isStarred ? Colors.amber[600] : null,
            ),
            onPressed: () =>
                ref.read(starredItemsProvider.notifier).toggleStar(currentItem.id),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: total,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          ref
              .read(readItemsProvider.notifier)
              .markRead(widget.items[index].id);
        },
        itemBuilder: (context, index) =>
            _ArticlePage(item: widget.items[index]),
      ),
      bottomNavigationBar: _NavBar(
        currentIndex: _currentIndex,
        total: total,
        onPrev: _currentIndex > 0 ? () => _goTo(_currentIndex - 1) : null,
        onNext:
            _currentIndex < total - 1 ? () => _goTo(_currentIndex + 1) : null,
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _NavBar({
    required this.currentIndex,
    required this.total,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: onPrev,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Vorige'),
            ),
            const Spacer(),
            // Paginadots
            Row(
              children: List.generate(
                total > 7 ? 0 : total,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == currentIndex ? 10 : 6,
                  height: i == currentIndex ? 10 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == currentIndex
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300],
                  ),
                ),
              ),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Volgende'),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticlePage extends ConsumerWidget {
  final NewsItem item;

  const _ArticlePage({required this.item});

  String _formatFeedTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min geleden';
    if (diff.inHours < 24) return '${diff.inHours} uur geleden';
    return '${dt.day}-${dt.month}-${dt.year}';
  }

  String _formatPubDate(DateTime? pubDate) {
    if (pubDate == null) return 'onbekend';
    return '${pubDate.day}-${pubDate.month}-${pubDate.year}';
  }

  Future<void> _openUrl(BuildContext context) async {
    if (item.url.isEmpty) return;
    final uri = Uri.parse(item.url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kan de link niet openen')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(settingsProvider).valueOrNull ?? [];
    final category = categories.firstWhere(
      (c) => c.id == item.category,
      orElse: () => categories.first,
    );

    return SelectionArea(
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryBadge(
            categoryId: item.category,
            categoryName: category.name,
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.add_circle_outline, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                _formatFeedTime(item.timestamp),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.newspaper_outlined, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                _formatPubDate(item.publishedDate),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  final feedUrl = item.feedUrl;
                  if (feedUrl != null && feedUrl.isNotEmpty) {
                    launchUrl(Uri.parse(feedUrl), mode: LaunchMode.externalApplication);
                  } else {
                    _openUrl(context);
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.source_outlined, size: 14, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      item.source,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontStyle: FontStyle.italic,
                            decoration: TextDecoration.underline,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            item.summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.7,
                ),
          ),
          const SizedBox(height: 24),
          _SourceLinkCard(
            url: item.url,
            onTap: () => _openUrl(context),
          ),
          const SizedBox(height: 16),
          _MeerHieroverButton(item: item),
          const SizedBox(height: 16),
        ],
      ),
    )); // SelectionArea + SingleChildScrollView
  }
}

class _MeerHieroverButton extends ConsumerWidget {
  final NewsItem item;

  const _MeerHieroverButton({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => _showDialog(context, ref),
        icon: const Icon(Icons.search, size: 18),
        label: const Text('Meer hierover'),
      ),
    );
  }

  void _showDialog(BuildContext context, WidgetRef ref) {
    int preferredCount = 3;
    int maxCount = 5;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Meer hierover'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voorkeur: $preferredCount artikelen',
                      style: Theme.of(context).textTheme.bodySmall),
                  Slider(
                    value: preferredCount.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$preferredCount',
                    onChanged: (v) => setState(() {
                      preferredCount = v.round();
                      if (maxCount < preferredCount) maxCount = preferredCount;
                    }),
                  ),
                  Text('Maximum: $maxCount artikelen',
                      style: Theme.of(context).textTheme.bodySmall),
                  Slider(
                    value: maxCount.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '$maxCount',
                    onChanged: (v) => setState(() {
                      maxCount = v.round();
                      if (preferredCount > maxCount) preferredCount = maxCount;
                    }),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(requestProvider.notifier).addRequest(
                      subject: item.title,
                      sourceItemId: item.id,
                      sourceItemTitle: item.title,
                      preferredCount: preferredCount,
                      maxCount: maxCount,
                    );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Verzoek toegevoegd aan wachtrij'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Toevoegen'),
            ),
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
            Icon(Icons.open_in_new,
                size: 18, color: Theme.of(context).colorScheme.primary),
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
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
