import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/news_provider.dart';
import '../widgets/news_card.dart';
import 'settings_screen.dart';

class NewsFeedScreen extends ConsumerWidget {
  const NewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(filteredNewsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nieuws'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Instellingen',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: items.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              onRefresh: () async {
                // Simuleer vernieuwen (mock: geen echte data)
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.newspaper_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Geen nieuws gevonden',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Schakel categorieën in via de instellingen',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
                ),
          ),
        ],
      ),
    );
  }
}
