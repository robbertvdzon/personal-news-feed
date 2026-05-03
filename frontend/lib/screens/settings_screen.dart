import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      appBar: AppBar(title: const Text('Instellingen')),
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
            'Tik op een categorie om hem te bewerken.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          ...visibleCategories.map((cat) => _CategoryRow(category: cat)),
          const SizedBox(height: 8),
          _AddCategoryButton(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
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

// ─────────────────────────────────────────────────────────────────────────────
// Category row — tap to edit
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryRow extends ConsumerWidget {
  final Category category;
  const _CategoryRow({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = category;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showDialog(
          context: context,
          builder: (_) => _EditCategoryDialog(category: cat),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  cat.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cat.enabled ? null : Colors.grey[400],
                      ),
                ),
              ),
              Text(
                '${cat.preferredCount}–${cat.maxCount} art.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[500]),
              ),
              const SizedBox(width: 8),
              Switch(
                value: cat.enabled,
                onChanged: (_) =>
                    ref.read(settingsProvider.notifier).toggleCategory(cat.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit dialog
// ─────────────────────────────────────────────────────────────────────────────

class _EditCategoryDialog extends ConsumerStatefulWidget {
  final Category category;
  const _EditCategoryDialog({required this.category});

  @override
  ConsumerState<_EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends ConsumerState<_EditCategoryDialog> {
  late TextEditingController _nameController;
  late TextEditingController _extraController;
  late TextEditingController _preferredController;
  late TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
    _extraController = TextEditingController(text: widget.category.extraInstructions);
    _preferredController = TextEditingController(text: '${widget.category.preferredCount}');
    _maxController = TextEditingController(text: '${widget.category.maxCount}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _extraController.dispose();
    _preferredController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _save() {
    final notifier = ref.read(settingsProvider.notifier);
    final id = widget.category.id;
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.category.name) {
      notifier.updateName(id, newName);
    }
    notifier.updateExtraInstructions(id, _extraController.text.trim());
    final preferred = int.tryParse(_preferredController.text) ?? widget.category.preferredCount;
    final max = int.tryParse(_maxController.text) ?? widget.category.maxCount;
    notifier.updateCounts(id, preferred, max.clamp(preferred, 99));
    Navigator.of(context).pop();
  }

  void _delete() {
    Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Categorie bewerken'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Naam
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Naam',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // Extra instructies
            TextField(
              controller: _extraController,
              decoration: const InputDecoration(
                labelText: 'Extra instructies (optioneel)',
                hintText: 'Bijv. focus op praktische tutorials',
                border: OutlineInputBorder(),
              ),
              maxLines: 6,
              minLines: 4,
            ),
            const SizedBox(height: 16),

            // Gewenst en maximaal aantal
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _preferredController,
                    decoration: const InputDecoration(
                      labelText: 'Gewenst aantal',
                      hintText: '3',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    decoration: const InputDecoration(
                      labelText: 'Maximum',
                      hintText: '5',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Verwijderen'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuleren'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _save,
              child: const Text('Opslaan'),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add category button
// ─────────────────────────────────────────────────────────────────────────────

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
