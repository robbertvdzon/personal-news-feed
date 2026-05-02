import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../models/category.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(settingsProvider).valueOrNull ?? [];
    final visibleCategories = categories.where((c) => !c.isSystem).toList();
    final auth = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instellingen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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

          _SectionHeader('Categorieën'),
          const SizedBox(height: 4),
          Text(
            'Kies welke categorieën je wilt zien, pas de naam en aantallen aan.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          ...visibleCategories.map((cat) => _CategoryCard(category: cat)),
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
                ref.read(settingsProvider.notifier).addCategory(controller.text.trim());
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
  late TextEditingController _nameController;
  late TextEditingController _extraController;
  bool _editingExtra = false;
  bool _editingName = false;
  late int _preferredCount;
  late int _maxCount;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
    _extraController = TextEditingController(text: widget.category.extraInstructions);
    _preferredCount = widget.category.preferredCount;
    _maxCount = widget.category.maxCount;
  }

  @override
  void didUpdateWidget(_CategoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editingName) _nameController.text = widget.category.name;
    if (!_editingExtra) _extraController.text = widget.category.extraInstructions;
    if (!_editingExtra) {
      _preferredCount = widget.category.preferredCount;
      _maxCount = widget.category.maxCount;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Categorie verwijderen'),
        content: Text('Wil je "${widget.category.name}" verwijderen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(settingsProvider.notifier).removeCategory(widget.category.id);
              Navigator.of(context).pop();
            },
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
  }

  void _saveName() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.category.name) {
      ref.read(settingsProvider.notifier).updateName(widget.category.id, newName);
    }
    setState(() => _editingName = false);
  }

  void _saveExtra() {
    ref.read(settingsProvider.notifier).updateExtraInstructions(
          widget.category.id, _extraController.text);
    ref.read(settingsProvider.notifier).updateCounts(
          widget.category.id, _preferredCount, _maxCount);
    setState(() => _editingExtra = false);
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
            // ── Titel rij ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _editingName
                      ? TextField(
                          controller: _nameController,
                          autofocus: true,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _saveName(),
                        )
                      : GestureDetector(
                          onTap: () => setState(() => _editingName = true),
                          child: Row(
                            children: [
                              Text(
                                cat.name,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.edit, size: 13, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                ),
                if (_editingName) ...[
                  IconButton(
                    icon: const Icon(Icons.check, size: 18),
                    color: Colors.green,
                    onPressed: _saveName,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _nameController.text = cat.name;
                      setState(() => _editingName = false);
                    },
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.red[400],
                    tooltip: 'Verwijder categorie',
                    onPressed: () => _confirmDelete(context),
                  ),
                  Switch(
                    value: cat.enabled,
                    onChanged: (_) =>
                        ref.read(settingsProvider.notifier).toggleCategory(cat.id),
                  ),
                ],
              ],
            ),

            if (cat.enabled) ...[
              const SizedBox(height: 8),

              // ── Extra instructies + counts ─────────────────────────────
              if (_editingExtra)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Aantallen sliders
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Minimaal: $_preferredCount',
                                  style: Theme.of(context).textTheme.bodySmall),
                              Slider(
                                value: _preferredCount.toDouble(),
                                min: 1,
                                max: 10,
                                divisions: 9,
                                label: '$_preferredCount',
                                onChanged: (v) => setState(() {
                                  _preferredCount = v.round();
                                  if (_maxCount < _preferredCount) _maxCount = _preferredCount;
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Maximaal: $_maxCount',
                                  style: Theme.of(context).textTheme.bodySmall),
                              Slider(
                                value: _maxCount.toDouble(),
                                min: 1,
                                max: 20,
                                divisions: 19,
                                label: '$_maxCount',
                                onChanged: (v) => setState(() {
                                  _maxCount = v.round();
                                  if (_preferredCount > _maxCount) _preferredCount = _maxCount;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Extra instructies
                    TextField(
                      controller: _extraController,
                      decoration: InputDecoration(
                        hintText: 'Extra instructies (optioneel)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      maxLines: 3,
                      minLines: 2,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _saveExtra,
                      child: const Text('Opslaan'),
                    ),
                  ],
                )
              else
                InkWell(
                  onTap: () => setState(() => _editingExtra = true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            cat.extraInstructions.isEmpty
                                ? 'Tik om te bewerken...'
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
                        const SizedBox(width: 8),
                        Text(
                          '${cat.preferredCount}–${cat.maxCount} art.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[500]),
                        ),
                      ],
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
