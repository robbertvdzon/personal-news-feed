import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/podcast.dart';
import '../providers/audio_player_provider.dart';
import '../providers/podcast_provider.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Hoofd-scherm
// ─────────────────────────────────────────────────────────────────────────────

class PodcastScreen extends ConsumerWidget {
  const PodcastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcastsAsync = ref.watch(podcastProvider);
    final audioState = ref.watch(audioPlayerProvider);

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
      body: Column(
        children: [
          // Lijst met afleveringen
          Expanded(
            child: podcastsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fout: $e')),
              data: (podcasts) => podcasts.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        top: 8,
                        bottom: audioState.podcastId != null ? 8 : 80,
                      ),
                      itemCount: podcasts.length,
                      itemBuilder: (context, index) =>
                          _PodcastCard(podcast: podcasts[index]),
                    ),
            ),
          ),
          // Globale mini-player (alleen zichtbaar als er iets geladen is)
          if (audioState.podcastId != null) const _MiniPlayer(),
        ],
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
        onConfirm: (periodDays, durationMinutes, customTopics) async {
          await ref.read(podcastProvider.notifier).create(
                periodDays: periodDays,
                durationMinutes: durationMinutes,
                customTopics: customTopics,
              );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Podcast-kaart (zonder eigen player)
// ─────────────────────────────────────────────────────────────────────────────

class _PodcastCard extends ConsumerWidget {
  final Podcast podcast;
  const _PodcastCard({required this.podcast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = podcast.status == PodcastStatus.done;
    final isFailed = podcast.status == PodcastStatus.failed;
    final audioState = ref.watch(audioPlayerProvider);
    final isCurrent = audioState.podcastId == podcast.id;
    final isPlaying = isCurrent &&
        ref.watch(audioPlayerProvider.notifier).player.playing;
    final isLoading = isCurrent && audioState.isLoading;

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
        elevation: isCurrent ? 2 : (isDone ? 1 : 0),
        color: isFailed
            ? Colors.red[50]
            : isCurrent
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25)
                : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: titel + status + play-knop ──────────────────────
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
                  if (isDone) ...[
                    // Play / pause knop
                    if (isLoading)
                      const SizedBox(
                        width: 36,
                        height: 36,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 36,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () => ref
                            .read(audioPlayerProvider.notifier)
                            .loadAndPlay(podcast.id, podcast.title),
                      ),
                  ] else
                    _StatusChip(status: podcast.status),
                ],
              ),

              // ── Eigen onderwerpen (customTopics) ────────────────────────
              if (podcast.customTopics.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: podcast.customTopics
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],

              // ── Meta: datum + duur + kosten ─────────────────────────────
              const SizedBox(height: 6),
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
                  if (isDone) ...[
                    const Spacer(),
                    _StatusChip(status: podcast.status),
                  ],
                ],
              ),

              // ── Besproken onderwerpen (topics uit script) ───────────────
              if (isDone && podcast.topics.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: podcast.topics
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],

              // ── Foutmelding audio ───────────────────────────────────────
              if (isCurrent && audioState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Fout: ${audioState.errorMessage}',
                    style: TextStyle(fontSize: 12, color: Colors.red[700]),
                  ),
                ),

              // ── Draaiboek + download-knoppen ────────────────────────────
              if (isDone) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _downloadAudio(podcast.id),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Download'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.grey[600],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showScript(context, podcast.id),
                      icon: const Icon(Icons.article_outlined, size: 16),
                      label: const Text('Draaiboek'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],

              // ── Voortgangsbalk tijdens genereren ────────────────────────
              if (podcast.status.isGenerating) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(4)),
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

  Future<void> _downloadAudio(String podcastId) async {
    final url = ApiService.podcastAudioUrl(podcastId);
    final uri = Uri.parse(url);
    if (kIsWeb) {
      // Op web: open de URL in een nieuw tabblad — de browser downloadt automatisch
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri);
    }
  }

  void _showScript(BuildContext context, String podcastId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ScriptSheet(podcastId: podcastId),
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
// Globale mini-player (onderin het scherm)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniPlayer extends ConsumerWidget {
  const _MiniPlayer();

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final player = notifier.player;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titel + laden/fout
          Row(
            children: [
              Icon(Icons.podcasts,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  audioState.isLoading
                      ? 'Audio laden…'
                      : audioState.errorMessage != null
                          ? 'Fout bij laden'
                          : audioState.podcastTitle ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        overflow: TextOverflow.ellipsis,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Seek-balk + tijdslabels
          StreamBuilder<Duration?>(
            stream: player.durationStream,
            builder: (_, durSnap) {
              final total = durSnap.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (_, posSnap) {
                  final pos = posSnap.data ?? Duration.zero;
                  final maxVal = total.inMilliseconds > 0
                      ? total.inMilliseconds.toDouble()
                      : 1.0;
                  final curVal =
                      pos.inMilliseconds.toDouble().clamp(0.0, maxVal);
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 10),
                        ),
                        child: Slider(
                          value: curVal,
                          max: maxVal,
                          onChanged: audioState.hasContent
                              ? (v) => notifier
                                  .seek(Duration(milliseconds: v.toInt()))
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
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

          // Knoppen: terug / play-pause / vooruit
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (_, snap) {
              final ps = snap.data;
              final isPlaying = ps?.playing ?? false;
              final processing = ps?.processingState;
              final isBuffering = audioState.isLoading ||
                  processing == ProcessingState.loading ||
                  processing == ProcessingState.buffering;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    onPressed: audioState.hasContent
                        ? () => notifier
                            .seek(player.position - const Duration(seconds: 10))
                        : null,
                  ),
                  if (isBuffering)
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      iconSize: 44,
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: audioState.hasContent
                          ? () async {
                              if (processing == ProcessingState.completed) {
                                await notifier.seek(Duration.zero);
                                await player.play();
                              } else {
                                await notifier.togglePlayPause();
                              }
                            }
                          : null,
                    ),
                  IconButton(
                    icon: const Icon(Icons.forward_30),
                    onPressed: audioState.hasContent
                        ? () {
                            final next = player.position +
                                const Duration(seconds: 30);
                            final dur = player.duration ?? Duration.zero;
                            notifier.seek(next > dur ? dur : next);
                          }
                        : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
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
            fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
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
// Bottom sheet: draaiboek
// ─────────────────────────────────────────────────────────────────────────────

class _ScriptSheet extends StatefulWidget {
  final String podcastId;
  const _ScriptSheet({required this.podcastId});

  @override
  State<_ScriptSheet> createState() => _ScriptSheetState();
}

class _ScriptSheetState extends State<_ScriptSheet> {
  Podcast? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await ApiService.fetchPodcastDetail(widget.podcastId);
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // Greep + titel
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _detail?.title ?? 'Draaiboek',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Fout: $_error'))
                    : _ScriptView(
                        script: _detail?.scriptText ?? '',
                        scrollController: scrollController,
                      ),
          ),
        ],
      ),
    );
  }
}

class _ScriptView extends StatelessWidget {
  final String script;
  final ScrollController scrollController;
  const _ScriptView(
      {required this.script, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    if (script.isEmpty) {
      return const Center(child: Text('Draaiboek niet beschikbaar.'));
    }
    final lines =
        script.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final line = lines[i];
        final isInterviewer = line.startsWith('INTERVIEWER:');
        final isGuest = line.startsWith('GAST:');
        final speaker = isInterviewer
            ? 'Interviewer'
            : isGuest
                ? 'Gast'
                : null;
        final text = (isInterviewer || isGuest)
            ? line.substring(line.indexOf(':') + 1).trim()
            : line;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (speaker != null)
                Text(
                  speaker,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isInterviewer
                        ? Theme.of(context).colorScheme.primary
                        : Colors.teal[700],
                    letterSpacing: 0.5,
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isInterviewer
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.4)
                      : isGuest
                          ? Colors.teal[50]
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog: nieuwe podcast aanmaken
// ─────────────────────────────────────────────────────────────────────────────

class _CreatePodcastDialog extends StatefulWidget {
  final Future<void> Function(
      int periodDays, int durationMinutes, List<String> customTopics) onConfirm;
  const _CreatePodcastDialog({required this.onConfirm});

  @override
  State<_CreatePodcastDialog> createState() => _CreatePodcastDialogState();
}

class _CreatePodcastDialogState extends State<_CreatePodcastDialog> {
  int _periodDays = 7;
  bool _loading = false;

  final _durationController = TextEditingController(text: '10');
  final _topicsController = TextEditingController();

  static const _periods = [
    (label: 'Vandaag', days: 1),
    (label: '1 week', days: 7),
    (label: '2 weken', days: 14),
  ];

  @override
  void dispose() {
    _durationController.dispose();
    _topicsController.dispose();
    super.dispose();
  }

  List<String> get _customTopics => _topicsController.text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  int get _durationMinutes =>
      int.tryParse(_durationController.text.trim()) ?? 10;

  @override
  Widget build(BuildContext context) {
    final hasTopics = _topicsController.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Nieuwe podcast'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label('Onderwerpen (optioneel)'),
            const SizedBox(height: 6),
            TextField(
              controller: _topicsController,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText:
                    'Eén onderwerp per regel, bijv.:\nKubernetes 1.33\nAI code assistants',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey[400]),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                isDense: true,
                suffixIcon: hasTopics
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _topicsController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
            if (hasTopics)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Claude gebruikt zijn eigen kennis over deze onderwerpen.',
                  style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                ),
              ),
            const SizedBox(height: 16),
            _Label(
                'Nieuws-periode${hasTopics ? ' (achtergrond)' : ''}'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _periods
                  .map((p) => ChoiceChip(
                        label: Text(p.label),
                        selected: _periodDays == p.days,
                        onSelected: (_) =>
                            setState(() => _periodDays = p.days),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _Label('Duur (minuten)'),
            const SizedBox(height: 6),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: 'min',
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
        FilledButton.icon(
          onPressed: _loading
              ? null
              : () async {
                  final dur = _durationMinutes;
                  if (dur < 1 || dur > 60) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Duur moet tussen 1 en 60 minuten liggen')),
                    );
                    return;
                  }
                  setState(() => _loading = true);
                  try {
                    await widget.onConfirm(
                        _periodDays, dur, _customTopics);
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontWeight: FontWeight.w600),
      );
}
