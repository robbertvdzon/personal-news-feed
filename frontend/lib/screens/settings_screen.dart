import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../models/category.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instellingen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account section
          _SectionHeader('Account'),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(auth?.username ?? 'Gebruiker'),
              subtitle: const Text('Ingelogd'),
              trailing: TextButton(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                child: const Text('Uitloggen'),
              ),
            ),
          ),

          // Categories section
          _SectionHeader('Categorieën'),
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
          const SizedBox(height: 8),
          _AddCategoryButton(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
      ),
    );
  }
}

class _AddCategoryButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () => _showAddDialog(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Categorie toevoegen'),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nieuwe categorie'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Naam',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ref.read(settingsProvider.notifier).addCategory(value.trim());
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref
                    .read(settingsProvider.notifier)
                    .addCategory(controller.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('Toevoegen'),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, Category cat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Categorie verwijderen'),
        content: Text('Wil je "${cat.name}" verwijderen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              ref.read(settingsProvider.notifier).removeCategory(cat.id);
              Navigator.of(context).pop();
            },
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
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
                if (!cat.isSystem)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.red[400],
                    tooltip: 'Verwijder categorie',
                    onPressed: () => _confirmDelete(context, ref, cat),
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
