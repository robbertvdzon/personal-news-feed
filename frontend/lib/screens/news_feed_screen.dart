import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feed_provider.dart';
import '../providers/news_provider.dart' show showReadProvider;
import '../providers/settings_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/feed_card.dart';

class NewsFeedScreen extends ConsumerWidget {
  const NewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedItems = ref.watch(filteredFeedProvider);
    final isLoading = ref.watch(feedLoadingProvider);
    final showRead = ref.watch(showReadProvider);
    final readCount = ref.watch(feedReadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 26, showText: false),
            SizedBox(width: 10),
            Text('Feed'),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Herlaad',
            icon: const Icon(Icons.sync, size: 20),
            onPressed: isLoading ? null : () => ref.read(feedProvider.notifier).refresh(),
          ),
          TextButton.icon(
            onPressed: () => ref.read(showReadProvider.notifier).state = !showRead,
            icon: Icon(
              showRead ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: _FeedCategoryTabBar(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => ref.read(feedProvider.notifier).refresh(),
              child: feedItems.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: _EmptyState(showRead: showRead, readCount: readCount),
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
                    ),
            ),
    );
  }
}

// ── Categorie-tabbar voor de feed ─────────────────────────────────────────────

class _FeedCategoryTabBar extends ConsumerWidget {
  const _FeedCategoryTabBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(settingsProvider).valueOrNull ?? [];
    final enabledCategories = categories.where((c) => c.enabled && !c.isSystem).toList();
    final selected = ref.watch(selectedFeedCategoryProvider);
    final showStarred = ref.watch(feedShowStarredProvider);
    final showSummary = ref.watch(feedShowSummaryProvider);
    final starredItems = ref.watch(feedStarredItemsProvider);
    final summaryItems = ref.watch(feedSummaryItemsProvider);
    final unreadByCategory = ref.watch(feedUnreadCountByCategoryProvider);
    final unreadSummaryCount = ref.watch(feedUnreadSummaryCountProvider);
    final totalUnread = unreadByCategory.values.fold(0, (a, b) => a + b);

    void selectCategory(String? catId) {
      ref.read(feedShowStarredProvider.notifier).state = false;
      ref.read(feedShowSummaryProvider.notifier).state = false;
      ref.read(selectedFeedCategoryProvider.notifier).state = catId;
    }

    void selectSummary() {
      final wasActive = showSummary;
      ref.read(feedShowSummaryProvider.notifier).state = !wasActive;
      if (!wasActive) {
        ref.read(feedShowStarredProvider.notifier).state = false;
        ref.read(selectedFeedCategoryProvider.notifier).state = null;
      }
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _TabChip(
            label: 'Alles',
            selected: !showStarred && !showSummary && selected == null,
            unreadCount: totalUnread,
            onTap: () => selectCategory(null),
          ),
          ...enabledCategories.map((cat) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _TabChip(
                  label: cat.name,
                  selected: !showStarred && !showSummary && selected == cat.id,
                  unreadCount: unreadByCategory[cat.id] ?? 0,
                  onTap: () => selectCategory(selected == cat.id && !showStarred && !showSummary ? null : cat.id),
                ),
              )),
          if (summaryItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _TabChip(
                label: '✨ Samenvatting',
                selected: showSummary,
                unreadCount: unreadSummaryCount,
                isSummaryTab: true,
                onTap: selectSummary,
              ),
            ),
          if (starredItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _TabChip(
                label: '⭐ Bewaard (${starredItems.length})',
                selected: showStarred,
                onTap: () {
                  ref.read(feedShowStarredProvider.notifier).state = !showStarred;
                  if (!showStarred) {
                    ref.read(feedShowSummaryProvider.notifier).state = false;
                    ref.read(selectedFeedCategoryProvider.notifier).state = null;
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Gedeelde widgets ──────────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int unreadCount;
  final VoidCallback onTap;
  final bool isSummaryTab;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.unreadCount = 0,
    this.isSummaryTab = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tertiary = Theme.of(context).colorScheme.tertiary;
    final color = isSummaryTab ? tertiary : primary;

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
            alleGelezen ? 'Alles gelezen!' : 'Geen feed-items gevonden',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            alleGelezen
                ? 'Tik op "Gelezen ($readCount)" om eerder gelezen items te bekijken'
                : 'Start een uurlijkse update via Verzoeken',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
