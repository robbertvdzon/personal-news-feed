import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/news_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/news_card.dart';

class RssScreen extends ConsumerWidget {
  const RssScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(filteredRssItemsProvider);
    final isLoading = ref.watch(rssLoadingProvider);
    final showRead = ref.watch(showReadProvider);
    final readCount = ref.watch(rssReadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RSS'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Herlaad',
            icon: const Icon(Icons.sync, size: 20),
            onPressed: isLoading ? null : () => ref.read(rssItemsProvider.notifier).refresh(),
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
          child: _RssCategoryTabBar(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => ref.read(rssItemsProvider.notifier).refresh(),
              child: items.isEmpty
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
                      itemCount: items.length,
                      itemBuilder: (context, index) => NewsCard(
                        item: items[index],
                        allItems: items,
                        index: index,
                        showFeedStatus: true,
                      ),
                    ),
            ),
    );
  }
}

// ── Categorie-tabbar voor RSS met "Overig" ────────────────────────────────────

class _RssCategoryTabBar extends ConsumerWidget {
  const _RssCategoryTabBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(settingsProvider).valueOrNull ?? [];
    final enabledCategories = categories.where((c) => c.enabled && !c.isSystem).toList();
    final selected = ref.watch(selectedRssCategoryProvider);
    final unreadByCategory = ref.watch(rssUnreadCountByCategoryProvider);
    final totalUnread = unreadByCategory.values.fold(0, (a, b) => a + b);
    final hasOverig = unreadByCategory.containsKey(kRssOverigCategory) ||
        (ref.watch(rssItemsProvider).valueOrNull ?? []).any((item) {
          final enabledIds = ref.watch(enabledCategoryIdsProvider);
          return item.category.isEmpty || !enabledIds.contains(item.category);
        });

    void selectCategory(String? catId) {
      ref.read(selectedRssCategoryProvider.notifier).state = catId;
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _TabChip(
            label: 'Alles',
            selected: selected == null,
            unreadCount: totalUnread,
            onTap: () => selectCategory(null),
          ),
          ...enabledCategories.map((cat) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _TabChip(
                  label: cat.name,
                  selected: selected == cat.id,
                  unreadCount: unreadByCategory[cat.id] ?? 0,
                  onTap: () => selectCategory(selected == cat.id ? null : cat.id),
                ),
              )),
          if (hasOverig)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _TabChip(
                label: 'Overig',
                selected: selected == kRssOverigCategory,
                unreadCount: unreadByCategory[kRssOverigCategory] ?? 0,
                onTap: () => selectCategory(
                    selected == kRssOverigCategory ? null : kRssOverigCategory),
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
            alleGelezen ? Icons.check_circle_outline : Icons.rss_feed,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            alleGelezen ? 'Alles gelezen!' : 'Geen RSS-items gevonden',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            alleGelezen
                ? 'Tik op "Gelezen ($readCount)" om eerder gelezen items te bekijken'
                : 'RSS-feeds worden elk uur verwerkt',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
