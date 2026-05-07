import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feed_provider.dart';
import '../providers/news_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/feed_card.dart';
import '../widgets/news_card.dart';

class NewsFeedScreen extends ConsumerWidget {
  const NewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedTab = ref.watch(selectedFeedTabProvider);
    final isRssTab = feedTab == 'rss';
    final isFeedTab = feedTab == 'feed';

    // Items for current tab
    final rssItems = ref.watch(filteredNewsProvider);
    final feedItems = ref.watch(filteredFeedProvider);

    final isLoading = isFeedTab
        ? ref.watch(feedLoadingProvider)
        : ref.watch(newsLoadingProvider);
    final isRefreshing = ref.watch(sourceRefreshingProvider);
    final showRead = ref.watch(showReadProvider);
    final readCount = ref.watch(readCountProvider);

    void syncRefresh() {
      if (isRssTab) {
        ref.read(rssItemsProvider.notifier).refresh();
      } else if (isFeedTab) {
        ref.read(feedProvider.notifier).refresh();
      } else {
        ref.read(newsProvider.notifier).refresh();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 26, showText: false),
            SizedBox(width: 10),
            Text('Nieuws'),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Herlaad',
            icon: const Icon(Icons.sync, size: 20),
            onPressed: isLoading ? null : syncRefresh,
          ),
          isRefreshing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Ververs RSS-feeds en update feed (AI)',
                  icon: const Icon(Icons.cloud_download_outlined, size: 20),
                  onPressed: () =>
                      ref.read(newsProvider.notifier).refreshFromSource(),
                ),
          TextButton.icon(
            onPressed: () =>
                ref.read(showReadProvider.notifier).state = !showRead,
            icon: Icon(
              showRead
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
            ),
            label: Text(
              showRead
                  ? 'Verberg gelezen'
                  : readCount > 0
                      ? 'Gelezen ($readCount)'
                      : 'Gelezen',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isRefreshing ? 100 : 96),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRefreshing) const LinearProgressIndicator(),
              const _FeedRssTabBar(),
              if (!isRssTab) const _CategoryTabBar() else const SizedBox(height: 48),
            ],
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => syncRefresh(),
              child: isFeedTab
                  ? (feedItems.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: constraints.maxHeight,
                              child: _EmptyState(
                                  showRead: showRead, readCount: readCount),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: feedItems.length,
                          itemBuilder: (context, index) => FeedCard(
                            item: feedItems[index],
                            allItems: feedItems,
                            index: index,
                          ),
                        ))
                  : (rssItems.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: constraints.maxHeight,
                              child: _EmptyState(
                                  showRead: showRead, readCount: readCount),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: rssItems.length,
                          itemBuilder: (context, index) => NewsCard(
                            item: rssItems[index],
                            allItems: rssItems,
                            index: index,
                            showFeedStatus: isRssTab,
                          ),
                        )),
            ),
    );
  }
}

// ── Feed / RSS toggle ──────────────────────────────────────────────────────────

class _FeedRssTabBar extends ConsumerWidget {
  const _FeedRssTabBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedTab = ref.watch(selectedFeedTabProvider);
    final color = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          const SizedBox(width: 12),
          _FeedTabChip(
            label: 'Feed',
            icon: Icons.star_outline,
            selected: feedTab == 'feed',
            color: color,
            onTap: () {
              ref.read(selectedFeedTabProvider.notifier).state = 'feed';
              ref.read(showStarredProvider.notifier).state = false;
            },
          ),
          const SizedBox(width: 8),
          _FeedTabChip(
            label: 'RSS',
            icon: Icons.rss_feed,
            selected: feedTab == 'rss',
            color: color,
            onTap: () {
              ref.read(selectedFeedTabProvider.notifier).state = 'rss';
              ref.read(showStarredProvider.notifier).state = false;
              ref.read(selectedCategoryProvider.notifier).state = null;
            },
          ),
        ],
      ),
    );
  }
}

class _FeedTabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FeedTabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: selected ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[700],
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Categorie-tabbar (alleen zichtbaar in feed-tab) ───────────────────────────

class _CategoryTabBar extends ConsumerWidget {
  const _CategoryTabBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(settingsProvider).valueOrNull ?? [];
    final enabledCategories = categories.where((c) => c.enabled).toList();
    final selected = ref.watch(selectedCategoryProvider);
    final showStarred = ref.watch(showStarredProvider);
    final starredItems = ref.watch(starredItemsProvider);
    final unreadByCategory = ref.watch(unreadCountByCategoryProvider);

    final totalUnread = unreadByCategory.values.fold(0, (a, b) => a + b);

    void selectCategory(String? catId) {
      ref.read(showStarredProvider.notifier).state = false;
      ref.read(selectedCategoryProvider.notifier).state = catId;
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _TabChip(
            label: 'Alles',
            selected: !showStarred && selected == null,
            unreadCount: totalUnread,
            onTap: () => selectCategory(null),
          ),
          ...enabledCategories.map((cat) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _TabChip(
                  label: cat.name,
                  selected: !showStarred && selected == cat.id,
                  unreadCount: unreadByCategory[cat.id] ?? 0,
                  onTap: () => selectCategory(
                      selected == cat.id && !showStarred ? null : cat.id),
                ),
              )),
          if (starredItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _TabChip(
                label: '⭐ Bewaard (${starredItems.length})',
                selected: showStarred,
                onTap: () {
                  ref.read(showStarredProvider.notifier).state = !showStarred;
                  if (!showStarred) {
                    ref.read(selectedCategoryProvider.notifier).state = null;
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int unreadCount;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[700],
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.30)
                      : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool showRead;
  final int readCount;

  const _EmptyState({required this.showRead, required this.readCount});

  @override
  Widget build(BuildContext context) {
    final alleGelezen = !showRead && readCount > 0;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            alleGelezen ? Icons.check_circle_outline : Icons.newspaper_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            alleGelezen ? 'Alles gelezen!' : 'Geen nieuws gevonden',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            alleGelezen
                ? 'Tik op "Gelezen ($readCount)" om eerder gelezen items te bekijken'
                : 'Schakel categorieën in via de instellingen',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
                ),
          ),
        ],
      ),
    );
  }
}
