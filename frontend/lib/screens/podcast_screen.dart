import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import '../models/podcast.dart';
import '../providers/podcast_provider.dart';
import '../services/api_service.dart';

class PodcastScreen extends ConsumerWidget {
  const PodcastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcastsAsync = ref.watch(podcastProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Podcast'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Vernieuwen',
            onPressed: () => ref.read(podcastProvider.notifier).refresh(),
          ),
        ],
      ),
      body: podcastsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fout: $e')),
        data: (podcasts) => podcasts.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: podcasts.length,
                itemBuilder: (context, index) =>
                    _PodcastCard(podcast: podcasts[index]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.mic),
        label: const Text('Nieuwe podcast'),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _CreatePodcastDialog(
        onConfirm: (periodDays, durationMinutes) async {
          await ref.read(podcastProvider.notifier).create(
                periodDays: periodDays,
                durationMinutes: durationMinutes,
              );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Podcast kaart
// ─────────────────────────────────────────────────────────────────────────────

class _PodcastCard extends ConsumerWidget {
  final Podcast podcast;
  const _PodcastCard({required this.podcast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = podcast.status == PodcastStatus.done;
    final isFailed = podcast.status == PodcastStatus.failed;

    return Dismissible(
      key: ValueKey(podcast.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => ref.read(podcastProvider.notifier).delete(podcast.id),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: isDone ? 1 : 0,
        color: isFailed ? Colors.red[50] : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: titel + status
              Row(
                children: [
                  Icon(
                    isDone ? Icons.podcasts : Icons.mic_none,
                    color: isDone
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[400],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      podcast.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _StatusChip(status: podcast.status),
                ],
              ),
              const SizedBox(height: 6),
              // Meta: datum + duur
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(podcast.createdAt),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.timer_outlined, size: 13, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    isDone && podcast.durationSeconds != null
                        ? _formatDuration(
                            Duration(seconds: podcast.durationSeconds!))
                        : '${podcast.durationMinutes} min',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[500]),
                  ),
                  if (podcast.costUsd > 0) ...[
                    const SizedBox(width: 12),
                    Text(
                      '\$${podcast.costUsd.toStringAsFixed(3)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[400]),
                    ),
                  ],
                ],
              ),

              // Audio player als de podcast klaar is
              if (isDone) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _AudioPlayerWidget(podcastId: podcast.id),
              ],

              // Laadindicator tijdens genereren
              if (podcast.status.isGenerating) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Text(
                  podcast.status.label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[400]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min geleden';
    if (diff.inHours < 24) return '${diff.inHours} uur geleden';
    return '${dt.day}-${dt.month}-${dt.year}';
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final PodcastStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, textColor) = switch (status) {
      PodcastStatus.done => (Colors.green[100]!, Colors.green[800]!),
      PodcastStatus.failed => (Colors.red[100]!, Colors.red[800]!),
      _ => (Colors.orange[100]!, Colors.orange[800]!),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio player widget
// ─────────────────────────────────────────────────────────────────────────────

class _AudioPlayerWidget extends ConsumerStatefulWidget {
  final String podcastId;
  const _AudioPlayerWidget({required this.podcastId});

  @override
  ConsumerState<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends ConsumerState<_AudioPlayerWidget> {
  late final AudioPlayer _player;
  bool _initialized = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    setState(() => _loading = true);
    try {
      final token = ApiService.currentToken;
      final url = ApiService.podcastAudioUrl(widget.podcastId);

      // Download audio bytes via http (ondersteunt auth headers op alle platforms,
      // inclusief web waar AudioSource.uri geen custom headers kan meesturen).
      final response = await http.get(
        Uri.parse(url),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      await _player.setAudioSource(_BytesAudioSource(response.bodyBytes));
      setState(() => _initialized = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio laden mislukt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isPlaying = state?.playing ?? false;
        final processing = state?.processingState;
        final isBuffering = _loading ||
            processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;

        return Column(
          children: [
            // Seekbar
            StreamBuilder<Duration?>(
              stream: _player.durationStream,
              builder: (_, durSnap) {
                final total = durSnap.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (_, posSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    final maxVal =
                        total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;
                    final curVal = pos.inMilliseconds
                        .toDouble()
                        .clamp(0.0, maxVal);
                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                          ),
                          child: Slider(
                            value: curVal,
                            max: maxVal,
                            onChanged: _initialized
                                ? (v) => _player.seek(
                                    Duration(milliseconds: v.toInt()))
                                : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fmt(pos),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey[500])),
                              Text(_fmt(total),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey[500])),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            // Play / Pause knop
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Terug 15 sec
                IconButton(
                  icon: const Icon(Icons.replay_10),
                  onPressed: _initialized
                      ? () async {
                          final pos = _player.position;
                          await _player.seek(
                              pos - const Duration(seconds: 10));
                        }
                      : null,
                ),
                isBuffering
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        iconSize: 48,
                        icon: Icon(
                          isPlaying ? Icons.pause_circle : Icons.play_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () async {
                          await _ensureInitialized();
                          if (!mounted) return;
                          if (processing == ProcessingState.completed) {
                            await _player.seek(Duration.zero);
                            await _player.play();
                          } else if (isPlaying) {
                            await _player.pause();
                          } else {
                            await _player.play();
                          }
                        },
                      ),
                // Vooruit 30 sec
                IconButton(
                  icon: const Icon(Icons.forward_30),
                  onPressed: _initialized
                      ? () async {
                          final pos = _player.position;
                          final dur = _player.duration ?? Duration.zero;
                          final next = pos + const Duration(seconds: 30);
                          await _player
                              .seek(next > dur ? dur : next);
                        }
                      : null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog: nieuwe podcast aanmaken
// ─────────────────────────────────────────────────────────────────────────────

class _CreatePodcastDialog extends StatefulWidget {
  final Future<void> Function(int periodDays, int durationMinutes) onConfirm;
  const _CreatePodcastDialog({required this.onConfirm});

  @override
  State<_CreatePodcastDialog> createState() => _CreatePodcastDialogState();
}

class _CreatePodcastDialogState extends State<_CreatePodcastDialog> {
  int _periodDays = 7;
  int _durationMinutes = 10;
  bool _loading = false;

  static const _periods = [
    (label: 'Vandaag', days: 1),
    (label: 'Afgelopen week', days: 7),
    (label: 'Afgelopen 2 weken', days: 14),
  ];

  static const _durations = [5, 10, 15, 20];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nieuwe podcast'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Periode',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _periods
                .map((p) => ChoiceChip(
                      label: Text(p.label),
                      selected: _periodDays == p.days,
                      onSelected: (_) => setState(() => _periodDays = p.days),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          Text('Duur: $_durationMinutes minuten',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _durations
                .map((d) => ChoiceChip(
                      label: Text('$d min'),
                      selected: _durationMinutes == d,
                      onSelected: (_) => setState(() => _durationMinutes = d),
                    ))
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
        FilledButton.icon(
          onPressed: _loading
              ? null
              : () async {
                  setState(() => _loading = true);
                  try {
                    await widget.onConfirm(_periodDays, _durationMinutes);
                    if (context.mounted) Navigator.of(context).pop();
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.mic, size: 18),
          label: const Text('Genereren'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lege staat
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.podcasts, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Nog geen podcasts',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tik op "+ Nieuwe podcast" om te beginnen',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StreamAudioSource op basis van bytes — werkt op alle platforms incl. web
// ─────────────────────────────────────────────────────────────────────────────

class _BytesAudioSource extends StreamAudioSource {
  final Uint8List bytes;
  _BytesAudioSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
