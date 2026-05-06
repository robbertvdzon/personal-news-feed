enum PodcastStatus {
  pending,
  determiningTopics,
  generatingScript,
  generatingAudio,
  done,
  failed;

  static PodcastStatus fromString(String value) {
    switch (value) {
      case 'PENDING':
        return PodcastStatus.pending;
      case 'DETERMINING_TOPICS':
        return PodcastStatus.determiningTopics;
      case 'GENERATING_SCRIPT':
        return PodcastStatus.generatingScript;
      case 'GENERATING_AUDIO':
        return PodcastStatus.generatingAudio;
      case 'DONE':
        return PodcastStatus.done;
      case 'FAILED':
        return PodcastStatus.failed;
      default:
        return PodcastStatus.pending;
    }
  }

  bool get isGenerating =>
      this == PodcastStatus.pending ||
      this == PodcastStatus.determiningTopics ||
      this == PodcastStatus.generatingScript ||
      this == PodcastStatus.generatingAudio;

  String get label {
    switch (this) {
      case PodcastStatus.pending:
        return 'In wachtrij';
      case PodcastStatus.determiningTopics:
        return 'Onderwerpen bepalen…';
      case PodcastStatus.generatingScript:
        return 'Script schrijven…';
      case PodcastStatus.generatingAudio:
        return 'Audio genereren…';
      case PodcastStatus.done:
        return 'Klaar';
      case PodcastStatus.failed:
        return 'Mislukt';
    }
  }
}

enum TtsProvider { openai, elevenlabs }

class Podcast {
  final String id;
  final String title;
  final String periodDescription;
  final int periodDays;
  final int durationMinutes;
  final PodcastStatus status;
  final DateTime createdAt;
  final int? durationSeconds;
  final double costUsd;
  final List<String> topics;
  final String? scriptText;
  final List<String> customTopics;
  final TtsProvider ttsProvider;
  final int podcastNumber;
  final int? generationSeconds;

  const Podcast({
    required this.id,
    required this.title,
    required this.periodDescription,
    required this.periodDays,
    required this.durationMinutes,
    required this.status,
    required this.createdAt,
    this.durationSeconds,
    this.costUsd = 0.0,
    this.topics = const [],
    this.scriptText,
    this.customTopics = const [],
    this.ttsProvider = TtsProvider.openai,
    this.podcastNumber = 0,
    this.generationSeconds,
  });

  factory Podcast.fromJson(Map<String, dynamic> json) => Podcast(
        id: json['id'] as String,
        title: json['title'] as String,
        periodDescription: json['periodDescription'] as String,
        periodDays: json['periodDays'] as int,
        durationMinutes: json['durationMinutes'] as int,
        status: PodcastStatus.fromString(json['status'] as String? ?? 'PENDING'),
        createdAt: DateTime.parse(json['createdAt'] as String),
        durationSeconds: json['durationSeconds'] as int?,
        costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0.0,
        topics: (json['topics'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        scriptText: json['scriptText'] as String?,
        customTopics: (json['customTopics'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        ttsProvider: (json['ttsProvider'] as String?) == 'ELEVENLABS'
            ? TtsProvider.elevenlabs
            : TtsProvider.openai,
        podcastNumber: json['podcastNumber'] as int? ?? 0,
        generationSeconds: json['generationSeconds'] as int?,
      );
}
