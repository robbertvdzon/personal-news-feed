import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/news_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/news_card.dart';
import 'settings_screen.dart';

class NewsFeedScreen extends ConsumerWidget {
  const NewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(filteredNewsProvider);
    final showRead = ref.watch(showReadProvider);
    final readCount = ref.watch(readCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nieuws'),
        centerTitle: false,
        actions: [
          if (readCount > 0)
            TextButton.icon(
              onPressed: () =>
                  ref.read(showReadProvider.notifier).state = !showRead,
              icon: Icon(
                showRead ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
              ),
              label: Text(
                showRead ? 'Verberg gelezen' : 'Gelezen ($readCount)',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Instellingen',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: _CategoryTabBar(),
        ),
      ),
      body: items.isEmpty
          ? _EmptyState(showRead: showRead, readCount: readCount)
          : RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 800));
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, index) => NewsCard(item: items[index]),
              ),
            ),
    );
  }
}

class _CategoryTabBar extends ConsumerWidget {
  const _CategoryTabBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(settingsProvider);
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
