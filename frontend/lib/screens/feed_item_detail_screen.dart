import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/feed_item.dart';
import '../providers/appearance_provider.dart';
import '../providers/feed_provider.dart';

class FeedItemDetailScreen extends ConsumerStatefulWidget {
  final List<FeedItem> items;
  final int initialIndex;

  const FeedItemDetailScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  ConsumerState<FeedItemDetailScreen> createState() =>
      _FeedItemDetailScreenState();
}

class _FeedItemDetailScreenState extends ConsumerState<FeedItemDetailScreen> {
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
          .read(feedReadItemsProvider.notifier)
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
    final starredItems = ref.watch(feedStarredItemsProvider);
    final isStarred = starredItems.contains(currentItem.id);
    final readItems = ref.watch(feedReadItemsProvider);
    final isRead = readItems.contains(currentItem.id);
    final feedback = ref.watch(feedFeedbackProvider);
    final liked = feedback[currentItem.id];
    final appearance = ref.watch(appearanceProvider);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(appearance.textScale),
      ),
      child: Scaffold(
      appBar: AppBar(
        title: Text('${_currentIndex + 1} / $total'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: liked == true ? 'Verwijder interessant' : 'Interessant',
            icon: Icon(
              liked == true ? Icons.thumb_up : Icons.thumb_up_outlined,
              color: liked == true
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[400],
            ),
            onPressed: () {
              final current = feedback[currentItem.id];
              final newValue = current == true ? null : true;
              ref
                  .read(feedFeedbackProvider.notifier)
                  .setFeedback(currentItem.id, newValue);
            },
          ),
          IconButton(
            tooltip: liked == false ? 'Verwijder niet-relevant' : 'Niet relevant',
            icon: Icon(
              liked == false ? Icons.thumb_down : Icons.thumb_down_outlined,
              color: liked == false
                  ? Theme.of(context).colorScheme.error
                  : Colors.grey[400],
            ),
            onPressed: () {
              final current = feedback[currentItem.id];
              final newValue = current == false ? null : false;
              ref
                  .read(feedFeedbackProvider.notifier)
                  .setFeedback(currentItem.id, newValue);
            },
          ),
          IconButton(
            tooltip:
                isRead ? 'Markeer als ongelezen' : 'Markeer als gelezen',
            icon: Icon(
              isRead
                  ? Icons.mark_email_unread_outlined
                  : Icons.mark_email_read_outlined,
              color: isRead ? Colors.blue[400] : null,
            ),
            onPressed: () {
              if (isRead) {
                ref
                    .read(feedReadItemsProvider.notifier)
                    .markUnread(currentItem.id);
              } else {
                ref
                    .read(feedReadItemsProvider.notifier)
                    .markRead(currentItem.id);
              }
            },
          ),
          IconButton(
            tooltip: isStarred ? 'Verwijder uit bewaard' : 'Bewaar artikel',
            icon: Icon(
              isStarred ? Icons.star : Icons.star_border,
              color: isStarred ? Colors.amber[600] : null,
            ),
            onPressed: () => ref
                .read(feedStarredItemsProvider.notifier)
                .toggleStar(currentItem.id),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: total,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          ref
              .read(feedReadItemsProvider.notifier)
              .markRead(widget.items[index].id);
        },
        itemBuilder: (context, index) =>
            _FeedArticlePage(item: widget.items[index]),
      ),
      bottomNavigationBar: _NavBar(
        currentIndex: _currentIndex,
        total: total,
        onPrev: _currentIndex > 0 ? () => _goTo(_currentIndex - 1) : null,
        onNext: _currentIndex < total - 1
            ? () => _goTo(_currentIndex + 1)
            : null,
      ),
      ),   // Scaffold
    );     // MediaQuery
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

class _FeedArticlePage extends StatelessWidget {
  final FeedItem item;

  const _FeedArticlePage({required this.item});

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

  Future<void> _openUrl(BuildContext context, String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
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
  Widget build(BuildContext context) {
    if (item.isSummary) {
      return _SummaryArticlePage(item: item);
    }

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Categorie chip
            if (item.category.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.category,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
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
                Icon(Icons.add_circle_outline,
                    size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  _formatFeedTime(item.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
                if (item.publishedDate != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.newspaper_outlined,
                      size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    _formatPubDate(item.publishedDate),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
                const SizedBox(width: 12),
                Icon(Icons.source_outlined,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  item.source,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
            if (item.feedReason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.feedReason,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
            const Divider(height: 24),
            Text(
              item.summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.8,
                  ),
            ),
            const SizedBox(height: 24),
            // Bronlinks
            if (item.sourceUrls.isNotEmpty) ...[
              ...item.sourceUrls.map((url) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SourceLinkCard(
                      url: url,
                      onTap: () => _openUrl(context, url),
                    ),
                  )),
            ] else if (item.url.isNotEmpty) ...[
              _SourceLinkCard(
                url: item.url,
                onTap: () => _openUrl(context, item.url),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Detailpagina voor dagelijkse AI-samenvatting ───────────────────────────────

class _SummaryArticlePage extends StatelessWidget {
  final FeedItem item;

  const _SummaryArticlePage({required this.item});

  String _formatFeedTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min geleden';
    if (diff.inHours < 24) return '${diff.inHours} uur geleden';
    return '${dt.day}-${dt.month}-${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 20, color: tertiaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                          color: tertiaryColor,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _formatFeedTime(item.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            const Divider(height: 24),
            _MarkdownText(text: item.summary),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Markdown renderer met inline formatting: **bold**, *italic*, ***bold+italic***
class _MarkdownText extends StatelessWidget {
  final String text;

  const _MarkdownText({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 6),
          child: Text(
            line.substring(2),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
          ),
        ));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 6),
          child: Text(
            line.substring(3),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  height: 1.3,
                ),
          ),
        ));
      } else if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(
            line.substring(4),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
          ),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6);
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, top: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: baseStyle),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: baseStyle,
                    children: _parseInline(line.substring(2), baseStyle),
                  ),
                ),
              ),
            ],
          ),
        ));
      } else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else {
        final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7);
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 2),
          child: RichText(
            text: TextSpan(
              style: baseStyle,
              children: _parseInline(line, baseStyle),
            ),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Parset inline markdown: ***bold+italic***, **bold**, *italic*, _italic_
  List<TextSpan> _parseInline(String text, TextStyle? base) {
    final spans = <TextSpan>[];
    // Patroon: ***...*** | **...** | *...* | _..._
    final pattern = RegExp(r'\*\*\*(.+?)\*\*\*|\*\*(.+?)\*\*|\*(.+?)\*|_(.+?)_');
    int last = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      if (match.group(1) != null) {
        // ***bold+italic***
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
        ));
      } else if (match.group(2) != null) {
        // **bold**
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (match.group(3) != null || match.group(4) != null) {
        // *italic* of _italic_
        spans.add(TextSpan(
          text: match.group(3) ?? match.group(4),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      }
      last = match.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
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
