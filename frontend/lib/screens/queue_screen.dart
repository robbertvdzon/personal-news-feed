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
          : requests.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Geen verzoeken', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                return _RequestTile(request: requests[index]);
              },
            ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _AddRequestDialog(
        onSubmit: ({
          required String subject,
          required int preferredCount,
          required int maxCount,
        }) {
          ref.read(requestProvider.notifier).addRequest(
                subject: subject,
                preferredCount: preferredCount,
                maxCount: maxCount,
              );
        },
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final NewsRequest request;

  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                Text(
                  '  ${request.preferredCount}–${request.maxCount} artikelen',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
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
      RequestStatus.processing => (
          'Verwerken',
          Colors.orange[50]!,
          Colors.orange[800]!
        ),
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
  final void Function({
    required String subject,
    required int preferredCount,
    required int maxCount,
  }) onSubmit;

  const _AddRequestDialog({required this.onSubmit});

  @override
  State<_AddRequestDialog> createState() => _AddRequestDialogState();
}

class _AddRequestDialogState extends State<_AddRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  int _preferredCount = 3;
  int _maxCount = 5;

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(
        subject: _subjectController.text.trim(),
        preferredCount: _preferredCount,
        maxCount: _maxCount,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nieuw verzoek'),
      content: Form(
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
                          if (_maxCount < _preferredCount) {
                            _maxCount = _preferredCount;
                          }
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
                          if (_preferredCount > _maxCount) {
                            _preferredCount = _maxCount;
                          }
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
