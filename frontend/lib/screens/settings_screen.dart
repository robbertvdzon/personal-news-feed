import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../models/category.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instellingen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Categorieën',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kies welke categorieën je wilt zien en voeg optioneel extra instructies toe.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 16),
          ...categories.map(
            (cat) => _CategoryCard(category: cat),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends ConsumerStatefulWidget {
  final Category category;

  const _CategoryCard({required this.category});

  @override
  ConsumerState<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends ConsumerState<_CategoryCard> {
  late TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.category.extraInstructions);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cat.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Switch(
                  value: cat.enabled,
                  onChanged: (_) => ref
                      .read(settingsProvider.notifier)
                      .toggleCategory(cat.id),
                ),
              ],
            ),
            if (cat.enabled) ...[
              const SizedBox(height: 8),
              if (_editing)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Extra instructies (optioneel)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      maxLines: 3,
                      minLines: 2,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        ref
                            .read(settingsProvider.notifier)
                            .updateExtraInstructions(
                              cat.id,
                              _controller.text,
                            );
                        setState(() => _editing = false);
                      },
                      child: const Text('Opslaan'),
                    ),
                  ],
                )
              else
                InkWell(
                  onTap: () => setState(() => _editing = true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      cat.extraInstructions.isEmpty
                          ? 'Tik om extra instructies toe te voegen...'
                          : cat.extraInstructions,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cat.extraInstructions.isEmpty
                                ? Colors.grey[400]
                                : Colors.grey[700],
                            fontStyle: cat.extraInstructions.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
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
