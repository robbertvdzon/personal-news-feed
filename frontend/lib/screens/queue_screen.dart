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
                        return _RequestTile(request: requests[index]);
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
        }) {
          ref.read(requestProvider.notifier).addRequest(
                subject: subject,
                preferredCount: preferredCount,
                maxCount: maxCount,
                extraInstructions: extraInstructions,
              );
        },
      ),
    );
  }
}

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
                    Text(
                      '${request.newItemCount} artikel${request.newItemCount != 1 ? 'en' : ''} toegevoegd',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
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
                        Text(
                          'Bezig...',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.orange[700],
                              ),
                        ),
                      ],
                    ),
                  if (request.status == RequestStatus.done ||
                      request.status == RequestStatus.failed) ...[
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
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sluiten'),
          ),
          if (request.status == RequestStatus.done || request.status == RequestStatus.failed)
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

class _AddRequestDialog extends StatefulWidget {
  final NewsRequest? prefill;
  final void Function({
    required String subject,
    required int preferredCount,
    required int maxCount,
    required String extraInstructions,
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

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.prefill?.subject ?? '');
    _extraController = TextEditingController(text: widget.prefill?.extraInstructions ?? '');
    _preferredCount = widget.prefill?.preferredCount ?? 3;
    _maxCount = widget.prefill?.maxCount ?? 5;
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
              const SizedBox(height: 20),
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
