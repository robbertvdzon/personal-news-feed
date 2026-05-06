import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/appearance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/news_provider.dart';
import '../providers/rss_feeds_provider.dart';
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

          _SectionHeader('Weergave'),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lettergrootte',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 10),
                  _FontSizePicker(),
                ],
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

          const SizedBox(height: 24),
          _SectionHeader('RSS Feeds'),
          const SizedBox(height: 4),
          Text(
            'Globale lijst van RSS feeds die gebruikt worden voor nieuws ophalen.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          _RssFeedsSection(),

          const SizedBox(height: 24),
          _SectionHeader('Opruimen'),
          const SizedBox(height: 4),
          Text(
            'Verwijder oude nieuwsartikelen om ruimte vrij te maken.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('Artikelen opruimen'),
              subtitle: const Text('Verwijder artikelen ouder dan een opgegeven aantal dagen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showDialog(
                context: context,
                builder: (_) => const _CleanupDialog(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Font size picker
// ─────────────────────────────────────────────────────────────────────────────

class _FontSizePicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLarge = ref.watch(appearanceProvider).fontSizeLarge;
    final notifier = ref.read(appearanceProvider.notifier);
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('Normaal'),
          icon: Icon(Icons.text_fields, size: 18),
        ),
        ButtonSegment(
          value: true,
          label: Text('Groot'),
          icon: Icon(Icons.format_size, size: 20),
        ),
      ],
      selected: {isLarge},
      onSelectionChanged: (s) => notifier.setFontSizeLarge(s.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
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
    // Capture alles vóór de pop, zodat ref en navigators geldig blijven
    final notifier = ref.read(settingsProvider.notifier);
    final categoryId = widget.category.id;
    final categoryName = widget.category.name;
    final editNav = Navigator.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Categorie verwijderen'),
        content: Text('Wil je "$categoryName" verwijderen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              notifier.removeCategory(categoryId);
              Navigator.of(ctx).pop(); // sluit bevestiging
              editNav.pop();           // sluit edit-dialog
            },
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 560,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Titel
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                'Categorie bewerken',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 16),
            // Scrollbare content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
    ), // Flexible + SingleChildScrollView
    const Divider(height: 1),
    // Altijd-zichtbare actions
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
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
          const SizedBox(width: 8),
        ],
      ),
    ),
            const SizedBox(height: 4),
          ], // outer Column children
        ), // outer Column
      ), // ConstrainedBox
    ); // Dialog
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

// ─────────────────────────────────────────────────────────────────────────────
// RSS Feeds section
// ─────────────────────────────────────────────────────────────────────────────

class _RssFeedsSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RssFeedsSection> createState() => _RssFeedsSectionState();
}

class _RssFeedsSectionState extends ConsumerState<_RssFeedsSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    ref.read(rssFeedsProvider.notifier).addFeed(url);
    _controller.clear();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final feeds = ref.watch(rssFeedsProvider).valueOrNull?.feeds ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (feeds.isEmpty)
              Text(
                'Geen RSS feeds geconfigureerd',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[500], fontStyle: FontStyle.italic),
              )
            else
              ...feeds.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.rss_feed, size: 14, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openUrl(f),
                            child: Text(
                              f.replaceAll(RegExp(r'^https?://'), ''),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: 'Verwijderen',
                          onPressed: () =>
                              ref.read(rssFeedsProvider.notifier).removeFeed(f),
                        ),
                      ],
                    ),
                  )),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'https://blog.example.com/feed',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  tooltip: 'Toevoegen',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cleanup dialog
// ─────────────────────────────────────────────────────────────────────────────

class _CleanupDialog extends ConsumerStatefulWidget {
  const _CleanupDialog();

  @override
  ConsumerState<_CleanupDialog> createState() => _CleanupDialogState();
}

class _CleanupDialogState extends ConsumerState<_CleanupDialog> {
  int _days = 14;
  bool _keepStarred = true;
  bool _keepLiked = true;
  bool _keepUnread = true;
  bool _running = false;

  final _daysController = TextEditingController(text: '14');

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _runCleanup() async {
    final days = int.tryParse(_daysController.text.trim()) ?? _days;
    if (days < 0) return;
    setState(() => _running = true);
    try {
      final removed = await ref.read(newsProvider.notifier).cleanupNews(
            olderThanDays: days,
            keepStarred: _keepStarred,
            keepLiked: _keepLiked,
            keepUnread: _keepUnread,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(removed == 0
              ? 'Geen artikelen verwijderd.'
              : '$removed artikel${removed == 1 ? '' : 'en'} verwijderd.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Artikelen opruimen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verwijder artikelen ouder dan:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _daysController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onChanged: (v) {
                    final d = int.tryParse(v);
                    if (d != null && d >= 0) setState(() => _days = d);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'dagen',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Bewaar toch:',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          CheckboxListTile(
            value: _keepStarred,
            onChanged: (v) => setState(() => _keepStarred = v ?? true),
            title: const Text('Artikelen met ster ⭐'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
          CheckboxListTile(
            value: _keepLiked,
            onChanged: (v) => setState(() => _keepLiked = v ?? true),
            title: const Text('Gelikte artikelen 👍'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
          CheckboxListTile(
            value: _keepUnread,
            onChanged: (v) => setState(() => _keepUnread = v ?? true),
            title: const Text('Ongelezen artikelen 📖'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _running ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
          onPressed: _running ? null : _runCleanup,
          child: _running
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Opruimen'),
        ),
      ],
    );
  }
}
