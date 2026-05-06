import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/news_request.dart';
import '../providers/request_provider.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(requestProvider);
    final requests = requestsAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verzoeken'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Vernieuwen',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(requestProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nieuw verzoek'),
      ),
      body: requestsAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(requestProvider.notifier).refresh(),
              child: requests.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('Geen verzoeken', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        if (request.isDailyUpdate) {
                          return _DailyUpdateTile(request: request);
                        }
                        return _RequestTile(request: request);
                      },
                    ),
            ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, {NewsRequest? prefill}) {
    showDialog(
      context: context,
      builder: (context) => _AddRequestDialog(
        prefill: prefill,
        onSubmit: ({
          required String subject,
          required int preferredCount,
          required int maxCount,
          required String extraInstructions,
          required int maxAgeDays,
        }) {
          ref.read(requestProvider.notifier).addRequest(
                subject: subject,
                preferredCount: preferredCount,
                maxCount: maxCount,
                extraInstructions: extraInstructions,
                maxAgeDays: maxAgeDays,
              );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily Update Tile (pinned, cannot be deleted)
// ─────────────────────────────────────────────────────────────────────────────

class _DailyUpdateTile extends ConsumerWidget {
  final NewsRequest request;

  const _DailyUpdateTile({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusIcon(status: request.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              request.subject,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.push_pin, size: 12, color: Colors.grey[500]),
                          ],
                        ),
                        if (request.status == RequestStatus.done && request.costUsd > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Kosten: \$${request.costUsd.toStringAsFixed(4)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _StatusChip(status: request.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(request.createdAt),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  if (request.status == RequestStatus.done)
                    Row(
                      children: [
                        Text(
                          '${request.newItemCount} art.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        if (request.costUsd > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            _formatCents(request.costUsd),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                        if (request.durationSeconds > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            _formatDuration(request.durationSeconds),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ],
                    ),
                  if (request.status == RequestStatus.processing)
                    Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange[600],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _ElapsedTimeText(since: request.processingStartedAt ?? request.createdAt),
                      ],
                    ),
                  if (request.status == RequestStatus.processing ||
                      request.status == RequestStatus.pending) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => ref.read(requestProvider.notifier).cancelRequest(request.id),
                      child: Row(
                        children: [
                          Icon(Icons.stop_circle_outlined, size: 14, color: Colors.red[400]),
                          const SizedBox(width: 4),
                          Text(
                            'Annuleren',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.red[400],
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (request.status == RequestStatus.done ||
                      request.status == RequestStatus.failed ||
                      request.status == RequestStatus.cancelled) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => ref.read(requestProvider.notifier).rerunRequest(request),
                      child: Row(
                        children: [
                          Icon(Icons.replay, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            'Opnieuw',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[500],
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Text(request.subject),
            const SizedBox(width: 8),
            Icon(Icons.push_pin, size: 16, color: Colors.grey[500]),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_formatTime(request.createdAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ]),
              if (request.status == RequestStatus.done) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.article, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('${request.newItemCount} artikelen toegevoegd',
                      style: const TextStyle(color: Colors.green, fontSize: 12)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.euro, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Totale kosten: \$${request.costUsd.toStringAsFixed(4)}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                if (request.categoryResults.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Uitsplitsing per categorie:',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  ...request.categoryResults.map((cat) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(cat.categoryName,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                ),
                                Text('\$${cat.costUsd.toStringAsFixed(4)}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 16, top: 2),
                              child: Row(
                                children: [
                                  _StatPill(label: 'gevonden', value: cat.searchResultCount, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  if (cat.filteredCount < cat.searchResultCount) ...[
                                    _StatPill(label: 'na filter', value: cat.filteredCount, color: Colors.orange),
                                    const SizedBox(width: 4),
                                  ],
                                  _StatPill(label: 'in feed', value: cat.articleCount, color: Colors.green),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sluiten'),
          ),
          if (request.status == RequestStatus.done ||
              request.status == RequestStatus.failed ||
              request.status == RequestStatus.cancelled)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(requestProvider.notifier).rerunRequest(request);
              },
              icon: const Icon(Icons.replay, size: 16),
              label: const Text('Opnieuw'),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min geleden';
    if (diff.inHours < 24) return '${diff.inHours} uur geleden';
    return '${diff.inDays} dag${diff.inDays != 1 ? 'en' : ''} geleden';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Regular Request Tile (dismissible)
// ─────────────────────────────────────────────────────────────────────────────

class _RequestTile extends ConsumerWidget {
  final NewsRequest request;

  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(request.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => ref.read(requestProvider.notifier).deleteRequest(request.id),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetail(context, ref),
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusIcon(status: request.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.subject,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (request.sourceItemTitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Gebaseerd op: ${request.sourceItemTitle}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                        if (request.extraInstructions.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            request.extraInstructions,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[500], fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _StatusChip(status: request.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(request.createdAt),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  if (request.status == RequestStatus.done)
                    Row(
                      children: [
                        Text(
                          '${request.newItemCount} art.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        if (request.costUsd > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            _formatCents(request.costUsd),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                        if (request.durationSeconds > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            _formatDuration(request.durationSeconds),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ],
                    ),
                  if (request.status == RequestStatus.processing)
                    Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange[600],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _ElapsedTimeText(since: request.processingStartedAt ?? request.createdAt),
                      ],
                    ),
                  if (request.status == RequestStatus.processing ||
                      request.status == RequestStatus.pending) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => ref.read(requestProvider.notifier).cancelRequest(request.id),
                      child: Row(
                        children: [
                          Icon(Icons.stop_circle_outlined, size: 14, color: Colors.red[400]),
                          const SizedBox(width: 4),
                          Text(
                            'Annuleren',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.red[400],
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (request.status == RequestStatus.done ||
                      request.status == RequestStatus.failed ||
                      request.status == RequestStatus.cancelled) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => ref.read(requestProvider.notifier).rerunRequest(request),
                      child: Row(
                        children: [
                          Icon(Icons.replay, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            'Opnieuw',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[500],
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    '${request.preferredCount}–${request.maxCount} art.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ),
        ),
        ), // InkWell
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(request.subject),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (request.sourceItemTitle != null) ...[
              Text('Gebaseerd op:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 2),
              Text(request.sourceItemTitle!, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
            ],
            if (request.extraInstructions.isNotEmpty) ...[
              Text('Extra instructies:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 2),
              Text(request.extraInstructions, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
            ],
            Row(children: [
              const Icon(Icons.tune, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${request.preferredCount}–${request.maxCount} artikelen',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.schedule, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(_formatTime(request.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ]),
            if (request.status == RequestStatus.done) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.article, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text('${request.newItemCount} artikelen toegevoegd',
                    style: const TextStyle(color: Colors.green, fontSize: 12)),
              ]),
              if (request.costUsd > 0) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.euro, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Kosten: \$${request.costUsd.toStringAsFixed(4)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ]),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sluiten'),
          ),
          if (request.status == RequestStatus.done ||
              request.status == RequestStatus.failed ||
              request.status == RequestStatus.cancelled)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(requestProvider.notifier).rerunRequest(request);
              },
              icon: const Icon(Icons.replay, size: 16),
              label: const Text('Opnieuw'),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min geleden';
    if (diff.inHours < 24) return '${diff.inHours} uur geleden';
    return '${diff.inDays} dag${diff.inDays != 1 ? 'en' : ''} geleden';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  final RequestStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      RequestStatus.pending => (Icons.hourglass_empty, Colors.grey),
      RequestStatus.processing => (Icons.sync, Colors.orange),
      RequestStatus.done => (Icons.check_circle, Colors.green),
      RequestStatus.failed => (Icons.error_outline, Colors.red),
      RequestStatus.cancelled => (Icons.cancel_outlined, Colors.grey),
    };
    return Icon(icon, color: color, size: 20);
  }
}

class _StatusChip extends StatelessWidget {
  final RequestStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      RequestStatus.pending => ('Wachtend', Colors.grey[100]!, Colors.grey[700]!),
      RequestStatus.processing => ('Verwerken', Colors.orange[50]!, Colors.orange[800]!),
      RequestStatus.done => ('Klaar', Colors.green[50]!, Colors.green[800]!),
      RequestStatus.failed => ('Mislukt', Colors.red[50]!, Colors.red[800]!),
      RequestStatus.cancelled => ('Geannuleerd', Colors.grey[100]!, Colors.grey[600]!),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Request Dialog
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _formatCents(double costUsd) {
  final cents = costUsd * 100;
  return cents < 1 ? '${(cents * 10).round() / 10}¢' : '${cents.toStringAsFixed(1)}¢';
}

String _formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return m > 0 ? '${m}m ${s}s' : '${s}s';
}

// ─────────────────────────────────────────────────────────────────────────────
// Elapsed time widget — telt de verstreken tijd elke seconde
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final MaterialColor color;

  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(fontSize: 10, color: color.shade700, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _ElapsedTimeText extends StatefulWidget {
  final DateTime since;
  const _ElapsedTimeText({required this.since});

  @override
  State<_ElapsedTimeText> createState() => _ElapsedTimeTextState();
}

class _ElapsedTimeTextState extends State<_ElapsedTimeText> {
  late Timer _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.since);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(widget.since));
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _label {
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    return m > 0 ? 'Bezig... ${m}m ${s}s' : 'Bezig... ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.orange[700],
          ),
    );
  }
}

class _AddRequestDialog extends StatefulWidget {
  final NewsRequest? prefill;
  final void Function({
    required String subject,
    required int preferredCount,
    required int maxCount,
    required String extraInstructions,
    required int maxAgeDays,
  }) onSubmit;

  const _AddRequestDialog({required this.onSubmit, this.prefill});

  @override
  State<_AddRequestDialog> createState() => _AddRequestDialogState();
}

class _AddRequestDialogState extends State<_AddRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subjectController;
  late final TextEditingController _extraController;
  late int _preferredCount;
  late int _maxCount;
  late int _maxAgeDays;

  static const _ageOptions = [
    (label: 'Vandaag', days: 1),
    (label: '3 dagen', days: 3),
    (label: '1 week', days: 7),
    (label: '1 maand', days: 30),
  ];

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.prefill?.subject ?? '');
    _extraController = TextEditingController(text: widget.prefill?.extraInstructions ?? '');
    _preferredCount = widget.prefill?.preferredCount ?? 3;
    _maxCount = widget.prefill?.maxCount ?? 5;
    _maxAgeDays = widget.prefill?.maxAgeDays ?? 3;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(
        subject: _subjectController.text.trim(),
        preferredCount: _preferredCount,
        maxCount: _maxCount,
        extraInstructions: _extraController.text.trim(),
        maxAgeDays: _maxAgeDays,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nieuw verzoek'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Onderwerp',
                  hintText: 'Bijv. Rust async runtime',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Verplicht veld' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _extraController,
                decoration: const InputDecoration(
                  labelText: 'Extra instructies (optioneel)',
                  hintText: 'Bijv. focus op security aspecten',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Tijdsrange artikelen',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _ageOptions.map((opt) {
                  final selected = _maxAgeDays == opt.days;
                  return ChoiceChip(
                    label: Text(opt.label),
                    selected: selected,
                    onSelected: (_) => setState(() => _maxAgeDays = opt.days),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Voorkeur: $_preferredCount',
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
                        Text('Maximum: $_maxCount',
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Toevoegen'),
        ),
      ],
    );
  }
}
