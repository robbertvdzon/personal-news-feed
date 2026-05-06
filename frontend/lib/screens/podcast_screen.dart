import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/podcast.dart' show Podcast, PodcastStatus, TtsProvider;
import '../providers/audio_player_provider.dart';
import '../providers/podcast_provider.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Hoofd-scherm: lijst + mini-player onderin
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
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nieuwe podcast',
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: podcastsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fout: $e')),
              data: (podcasts) => podcasts.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        top: 4,
                        bottom: audioState.podcastId != null ? 4 : 80,
                      ),
                      itemCount: podcasts.length,
                      itemBuilder: (context, index) =>
                          _PodcastListItem(podcast: podcasts[index]),
                    ),
            ),
          ),
          if (audioState.podcastId != null) const _MiniPlayer(),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _CreatePodcastDialog(
        onConfirm: (periodDays, durationMinutes, customTopics, ttsProvider) async {
          await ref.read(podcastProvider.notifier).create(
                periodDays: periodDays,
                durationMinutes: durationMinutes,
                customTopics: customTopics,
                ttsProvider: ttsProvider,
              );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact lijstitem — tik om detail te openen
// ─────────────────────────────────────────────────────────────────────────────

class _PodcastListItem extends ConsumerWidget {
  final Podcast podcast;
  const _PodcastListItem({required this.podcast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = podcast.status == PodcastStatus.done;
    final isFailed = podcast.status == PodcastStatus.failed;
    final audioState = ref.watch(audioPlayerProvider);
    final isCurrent = audioState.podcastId == podcast.id;
    final isPlaying = isCurrent &&
        ref.watch(audioPlayerProvider.notifier).player.playing;
    final isLoading = isCurrent && audioState.isLoading;

    // Korte beschrijving: de eerste 2 topics of customTopics
    final description = _shortDescription();

    return Dismissible(
      key: ValueKey(podcast.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) =>
          ref.read(podcastProvider.notifier).delete(podcast.id),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: isCurrent ? 2 : (isDone ? 1 : 0),
        color: isFailed
            ? Colors.red[50]
            : isCurrent
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.25)
                : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openDetail(context),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Play-knop of status-icoon
                _leadingIcon(context, ref, isDone, isFailed, isCurrent,
                    isPlaying, isLoading),
                const SizedBox(width: 12),
                // Titel + beschrijving
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        podcast.title,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (podcast.status.isGenerating) ...[
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                            borderRadius: BorderRadius.circular(4)),
                        const SizedBox(height: 2),
                        Text(podcast.status.label,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Colors.orange[700],
                                    fontSize: 11)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Duur rechts
                if (isDone)
                  Text(
                    _durationLabel(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[500]),
                  )
                else if (!podcast.status.isGenerating)
                  _StatusChip(status: podcast.status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leadingIcon(
    BuildContext context,
    WidgetRef ref,
    bool isDone,
    bool isFailed,
    bool isCurrent,
    bool isPlaying,
    bool isLoading,
  ) {
    if (!isDone) {
      return Icon(
        isFailed ? Icons.error_outline : Icons.mic_none,
        color: isFailed ? Colors.red[400] : Colors.grey[400],
        size: 28,
      );
    }
    if (isLoading) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return GestureDetector(
      onTap: () => ref.read(audioPlayerProvider.notifier).loadAndPlay(
            podcast.id,
            podcast.title,
            durationSeconds: podcast.durationSeconds,
          ),
      child: Icon(
        isCurrent && isPlaying
            ? Icons.pause_circle_filled
            : Icons.play_circle_filled,
        color: Theme.of(context).colorScheme.primary,
        size: 32,
      ),
    );
  }

  String _shortDescription() {
    if (podcast.topics.isNotEmpty) {
      return podcast.topics.take(3).join(' · ');
    }
    if (podcast.customTopics.isNotEmpty) {
      return podcast.customTopics.join(' · ');
    }
    return podcast.periodDescription;
  }

  String _durationLabel() {
    if (podcast.durationSeconds != null) {
      return _fmtDur(Duration(seconds: podcast.durationSeconds!));
    }
    return '${podcast.durationMinutes} min';
  }

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PodcastDetailScreen(podcast: podcast),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detailscherm
// ─────────────────────────────────────────────────────────────────────────────

class PodcastDetailScreen extends ConsumerWidget {
  final Podcast podcast;
  const PodcastDetailScreen({super.key, required this.podcast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = podcast.status == PodcastStatus.done;
    final audioState = ref.watch(audioPlayerProvider);
    final isCurrent = audioState.podcastId == podcast.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          podcast.podcastNumber > 0
              ? 'DevTalk ${podcast.podcastNumber}'
              : 'Podcast',
        ),
        actions: [
          if (isDone)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Download MP3',
              onPressed: () => _downloadAudio(podcast.id),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: isCurrent ? 8 : 32,
              ),
              children: [
                // ── Titel ──────────────────────────────────────────────────
                Text(
                  podcast.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),

                // ── Meta-rij ───────────────────────────────────────────────
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _MetaItem(
                        Icons.calendar_today_outlined,
                        _formatDate(podcast.createdAt)),
                    if (podcast.durationSeconds != null)
                      _MetaItem(Icons.headphones_outlined,
                          _fmtDur(Duration(seconds: podcast.durationSeconds!))),
                    if (podcast.generationSeconds != null)
                      _MetaItem(Icons.timer_outlined,
                          'Aangemaakt in ${_fmtDur(Duration(seconds: podcast.generationSeconds!))}'),
                    if (podcast.costUsd > 0)
                      _MetaItem(Icons.attach_money,
                          '\$${podcast.costUsd.toStringAsFixed(3)}'),
                    if (podcast.ttsProvider == TtsProvider.elevenlabs)
                      _MetaItem(Icons.record_voice_over_outlined, 'ElevenLabs'),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Eigen onderwerpen ──────────────────────────────────────
                if (podcast.customTopics.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: podcast.customTopics
                        .map((t) => _TopicChip(t,
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Status / voortgang ─────────────────────────────────────
                if (podcast.status.isGenerating) ...[
                  Row(children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text(podcast.status.label,
                        style: TextStyle(color: Colors.orange[700])),
                  ]),
                  const SizedBox(height: 12),
                ] else if (!isDone)
                  _StatusChip(status: podcast.status),

                // ── Audio player ───────────────────────────────────────────
                if (isDone) ...[
                  const Divider(),
                  _FullPlayer(podcast: podcast),
                  const Divider(),
                  const SizedBox(height: 8),
                ],

                // ── Topics ─────────────────────────────────────────────────
                if (podcast.topics.isNotEmpty) ...[
                  Text('Besproken onderwerpen',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: podcast.topics
                        .map((t) => _TopicChip(t,
                            color: Colors.grey[200]!))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Draaiboek ──────────────────────────────────────────────
                if (isDone)
                  OutlinedButton.icon(
                    onPressed: () => _showScript(context, podcast.id),
                    icon: const Icon(Icons.article_outlined, size: 18),
                    label: const Text('Bekijk draaiboek'),
                  ),
              ],
            ),
          ),
          // Mini-player als er een andere podcast speelt
          if (audioState.podcastId != null &&
              audioState.podcastId != podcast.id)
            const _MiniPlayer(),
        ],
      ),
    );
  }

  Future<void> _downloadAudio(String podcastId) async {
    final url = ApiService.podcastAudioUrl(podcastId,
        version: podcast.durationSeconds);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _showScript(BuildContext context, String podcastId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Volledige audio-player (in het detailscherm)
// ─────────────────────────────────────────────────────────────────────────────

class _FullPlayer extends ConsumerWidget {
  final Podcast podcast;
  const _FullPlayer({required this.podcast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final player = notifier.player;
    final isCurrent = audioState.podcastId == podcast.id;

    return Column(
      children: [
        const SizedBox(height: 8),
        // Seek-balk
        _SeekBar(
          player: player,
          isCurrent: isCurrent,
          knownDuration: audioState.knownDuration,
          notifier: notifier,
        ),
        // Knoppen
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (_, snap) {
            final ps = snap.data;
            final isPlaying = ps?.playing ?? false;
            final processing = ps?.processingState;
            final isBuffering = (isCurrent && audioState.isLoading) ||
                (isCurrent &&
                    (processing == ProcessingState.loading ||
                        processing == ProcessingState.buffering));
            final enabled = isCurrent && audioState.hasContent;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SkipButton(seconds: -60, enabled: enabled,
                    onTap: () => _skip(notifier, player, -60)),
                _SkipButton(seconds: -30, enabled: enabled,
                    onTap: () => _skip(notifier, player, -30)),
                _SkipButton(seconds: -15, enabled: enabled,
                    onTap: () => _skip(notifier, player, -15)),
                if (isBuffering)
                  const SizedBox(
                      width: 52, height: 52,
                      child: Padding(padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2)))
                else
                  IconButton(
                    iconSize: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    icon: Icon(
                      isCurrent && isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () async {
                      if (!isCurrent) {
                        await notifier.loadAndPlay(podcast.id, podcast.title,
                            durationSeconds: podcast.durationSeconds);
                      } else if (processing == ProcessingState.completed) {
                        await notifier.seek(Duration.zero);
                        await player.play();
                      } else {
                        await notifier.togglePlayPause();
                      }
                    },
                  ),
                _SkipButton(seconds: 15, enabled: enabled,
                    onTap: () => _skip(notifier, player, 15)),
                _SkipButton(seconds: 30, enabled: enabled,
                    onTap: () => _skip(notifier, player, 30)),
                _SkipButton(seconds: 60, enabled: enabled,
                    onTap: () => _skip(notifier, player, 60)),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  void _skip(AudioPlayerNotifier notifier, AudioPlayer player, int secs) {
    final dur = player.duration ?? notifier.knownDuration ?? Duration.zero;
    final next = player.position + Duration(seconds: secs);
    notifier.seek(next.isNegative ? Duration.zero : (next > dur ? dur : next));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seek-balk (gedeeld door full player en mini player)
// ─────────────────────────────────────────────────────────────────────────────

class _SeekBar extends StatelessWidget {
  final AudioPlayer player;
  final bool isCurrent;
  final Duration? knownDuration;
  final AudioPlayerNotifier notifier;

  const _SeekBar({
    required this.player,
    required this.isCurrent,
    required this.knownDuration,
    required this.notifier,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (_, durSnap) {
        // Gebruik de gedetecteerde duur, of fall back op de bekende duur
        final detected = durSnap.data;
        final total = (detected != null && detected.inSeconds > 30)
            ? detected
            : (knownDuration ?? detected ?? Duration.zero);

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
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: curVal,
                    max: maxVal,
                    onChanged: isCurrent
                        ? (v) => notifier
                            .seek(Duration(milliseconds: v.toInt()))
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini-player (onderin het lijstscherm, of als andere podcast speelt)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniPlayer extends ConsumerWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final player = notifier.player;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titel
          Row(children: [
            Icon(Icons.podcasts,
                size: 15, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                audioState.isLoading
                    ? 'Audio laden…'
                    : audioState.podcastTitle ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 2),
          // Seek-balk
          _SeekBar(
            player: player,
            isCurrent: audioState.hasContent,
            knownDuration: audioState.knownDuration,
            notifier: notifier,
          ),
          // Knoppen
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (_, snap) {
              final ps = snap.data;
              final isPlaying = ps?.playing ?? false;
              final processing = ps?.processingState;
              final isBuffering = audioState.isLoading ||
                  processing == ProcessingState.loading ||
                  processing == ProcessingState.buffering;
              final enabled = audioState.hasContent;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SkipButton(seconds: -60, enabled: enabled,
                      onTap: () => _skip(notifier, player, -60)),
                  _SkipButton(seconds: -30, enabled: enabled,
                      onTap: () => _skip(notifier, player, -30)),
                  _SkipButton(seconds: -15, enabled: enabled,
                      onTap: () => _skip(notifier, player, -15)),
                  if (isBuffering)
                    const SizedBox(
                        width: 44, height: 44,
                        child: Padding(padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2)))
                  else
                    IconButton(
                      iconSize: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: enabled
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
                  _SkipButton(seconds: 15, enabled: enabled,
                      onTap: () => _skip(notifier, player, 15)),
                  _SkipButton(seconds: 30, enabled: enabled,
                      onTap: () => _skip(notifier, player, 30)),
                  _SkipButton(seconds: 60, enabled: enabled,
                      onTap: () => _skip(notifier, player, 60)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _skip(AudioPlayerNotifier notifier, AudioPlayer player, int secs) {
    final dur = player.duration ?? notifier.knownDuration ?? Duration.zero;
    final next = player.position + Duration(seconds: secs);
    notifier.seek(next.isNegative ? Duration.zero : (next > dur ? dur : next));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skip-knop
// ─────────────────────────────────────────────────────────────────────────────

class _SkipButton extends StatelessWidget {
  final int seconds;
  final bool enabled;
  final VoidCallback onTap;
  const _SkipButton(
      {required this.seconds, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBack = seconds < 0;
    final color = enabled ? Colors.grey[700]! : Colors.grey[400]!;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isBack ? Icons.replay : Icons.forward, size: 18, color: color),
            Text('${seconds.abs()}s',
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hulpwidgets
// ─────────────────────────────────────────────────────────────────────────────

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaItem(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[500]),
          const SizedBox(width: 3),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600])),
        ],
      );
}

class _TopicChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TopicChip(this.label, {required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[800])),
      );
}

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
          color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.podcasts, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Nog geen podcasts',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('Tik op + rechtsboven om te beginnen',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[400])),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Draaiboek bottom sheet
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
      setState(() { _detail = detail; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [
              Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Text(_detail?.title ?? 'Draaiboek',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Fout: $_error'))
                    : _ScriptView(
                        script: _detail?.scriptText ?? '',
                        scrollController: scrollController),
          ),
        ],
      ),
    );
  }
}

class _ScriptView extends StatelessWidget {
  final String script;
  final ScrollController scrollController;
  const _ScriptView({required this.script, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    if (script.isEmpty) return const Center(child: Text('Draaiboek niet beschikbaar.'));
    final lines = script.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final line = lines[i];
        final isInterviewer = line.startsWith('INTERVIEWER:');
        final isGuest = line.startsWith('GAST:');
        final speaker = isInterviewer ? 'John' : isGuest ? 'Roland' : null;
        final text = (isInterviewer || isGuest)
            ? line.substring(line.indexOf(':') + 1).trim()
            : line;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (speaker != null)
                Text(speaker,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: isInterviewer
                            ? Theme.of(context).colorScheme.primary
                            : Colors.teal[700],
                        letterSpacing: 0.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isInterviewer
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.4)
                      : isGuest ? Colors.teal[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(text,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.5)),
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
  final Future<void> Function(int, int, List<String>, TtsProvider) onConfirm;
  const _CreatePodcastDialog({required this.onConfirm});

  @override
  State<_CreatePodcastDialog> createState() => _CreatePodcastDialogState();
}

class _CreatePodcastDialogState extends State<_CreatePodcastDialog> {
  bool _loading = false;
  TtsProvider _ttsProvider = TtsProvider.openai;

  final _durationController = TextEditingController(text: '10');
  final _periodController = TextEditingController(text: '7');
  final _topicsController = TextEditingController();

  @override
  void dispose() {
    _durationController.dispose();
    _periodController.dispose();
    _topicsController.dispose();
    super.dispose();
  }

  int get _periodDays => int.tryParse(_periodController.text.trim()) ?? 7;

  List<String> get _customTopics => _topicsController.text
      .split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

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
                hintText: 'Eén onderwerp per regel, bijv.:\nKubernetes 1.33\nAI code assistants',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                suffixIcon: hasTopics
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () { _topicsController.clear(); setState(() {}); })
                    : null,
              ),
            ),
            if (hasTopics)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Claude gebruikt zijn eigen kennis over deze onderwerpen.',
                    style: TextStyle(fontSize: 11, color: Colors.blue[700])),
              ),
            const SizedBox(height: 16),
            _Label('Nieuws-periode${hasTopics ? ' (achtergrond)' : ''}'),
            const SizedBox(height: 6),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _periodController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: 'dagen',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
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
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Label('Stemmen'),
            const SizedBox(height: 6),
            Column(children: [
              _ProviderTile(
                value: TtsProvider.elevenlabs, groupValue: _ttsProvider,
                title: 'ElevenLabs',
                subtitle: 'Nederlandstalige stemmen · eleven_multilingual_v2',
                color: Colors.purple[700]!,
                onChanged: (v) => setState(() => _ttsProvider = v),
              ),
              const SizedBox(height: 6),
              _ProviderTile(
                value: TtsProvider.openai, groupValue: _ttsProvider,
                title: 'OpenAI TTS',
                subtitle: 'Engelse stemmen · tts-1 · snelheid 1.2×',
                color: Colors.teal[700]!,
                onChanged: (v) => setState(() => _ttsProvider = v),
              ),
            ]),
          ],
        ),
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
                  final dur = _durationMinutes;
                  final period = _periodDays;
                  if (dur < 1 || dur > 60) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Duur moet tussen 1 en 60 minuten liggen')));
                    return;
                  }
                  if (period < 1 || period > 90) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Periode moet tussen 1 en 90 dagen liggen')));
                    return;
                  }
                  setState(() => _loading = true);
                  try {
                    await widget.onConfirm(_periodDays, dur, _customTopics, _ttsProvider);
                    if (context.mounted) Navigator.of(context).pop();
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
          icon: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(fontWeight: FontWeight.w600));
}

class _ProviderTile extends StatelessWidget {
  final TtsProvider value, groupValue;
  final String title, subtitle;
  final Color color;
  final void Function(TtsProvider) onChanged;

  const _ProviderTile({
    required this.value, required this.groupValue,
    required this.title, required this.subtitle,
    required this.color, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? color : Colors.grey[300]!, width: selected ? 2 : 1),
          color: selected ? color.withValues(alpha: 0.07) : null,
        ),
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? color : Colors.grey[400], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                      color: selected ? color : null)),
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ]),
          ),
        ]),
      ),
    );
  }
}
