import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/news_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/news_card.dart';

class NewsFeedScreen extends ConsumerWidget {
  const NewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(filteredNewsProvider);
    final isLoading = ref.watch(newsLoadingProvider);
    final isRefreshing = ref.watch(sourceRefreshingProvider);
    final showRead = ref.watch(showReadProvider);
    final readCount = ref.watch(readCountProvider);

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
            onPressed: isLoading
                ? null
                : () => ref.read(newsProvider.notifier).refresh(),
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
                  tooltip: 'Ververs alle categorieën (RSS + AI)',
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
          preferredSize: Size.fromHeight(isRefreshing ? 52 : 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRefreshing) const LinearProgressIndicator(),
              const _CategoryTabBar(),
            ],
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? _EmptyState(showRead: showRead, readCount: readCount)
          : RefreshIndicator(
              onRefresh: () => ref.read(newsProvider.notifier).refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, index) => NewsCard(
                  item: items[index],
                  allItems: items,
                  index: index,
                ),
              ),
            ),
    );
  }
}

class _CategoryTabBar extends ConsumerWidget {
  const _CategoryTabBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(settingsProvider).valueOrNull ?? [];
    final enabledCategories = categories.where((c) => c.enabled).toList();
    final selected = ref.watch(selectedCategoryProvider);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _TabChip(
            label: 'Alles',
            selected: selected == null,
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state = null,
          ),
          ...enabledCategories.map((cat) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _TabChip(
                  label: cat.name,
                  selected: selected == cat.id,
                  onTap: () => ref.read(selectedCategoryProvider.notifier).state =
                      selected == cat.id ? null : cat.id,
                ),
              )),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
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
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey[700],
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
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
