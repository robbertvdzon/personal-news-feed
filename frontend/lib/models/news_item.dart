class NewsItem {
  final String id;
  final String title;
  final String summary;
  final String url;
  final String category;
  final DateTime timestamp;
  final String source;
  final bool isRead;
  final bool starred;
  final bool? liked; // null = geen feedback, true = geliked, false = gedisliked
  final String feedUrl;
  final String snippet;
  final DateTime? publishedDate;
  final DateTime? processedAt;
  final bool inFeed;
  final String feedReason;
  final List<String> topics;

  const NewsItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.url,
    required this.category,
    required this.timestamp,
    required this.source,
    this.isRead = false,
    this.starred = false,
    this.liked,
    this.feedUrl = '',
    this.snippet = '',
    this.publishedDate,
    this.processedAt,
    this.inFeed = false,
    this.feedReason = '',
    this.topics = const [],
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      url: json['url'] as String,
      category: json['category'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      source: json['source'] as String,
      isRead: json['isRead'] as bool? ?? false,
      starred: json['starred'] as bool? ?? false,
      liked: json['liked'] as bool?,
      feedUrl: json['feedUrl'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
      publishedDate: json['publishedDate'] != null
          ? DateTime.tryParse(json['publishedDate'] as String)
          : null,
      processedAt: json['processedAt'] != null
          ? DateTime.tryParse(json['processedAt'] as String)
          : null,
      inFeed: json['inFeed'] as bool? ?? false,
      feedReason: json['feedReason'] as String? ?? '',
      topics: (json['topics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  NewsItem copyWith({
    bool? isRead,
    bool? starred,
    bool? inFeed,
    Object? liked = _sentinel,
  }) =>
      NewsItem(
        id: id,
        title: title,
        summary: summary,
        url: url,
        category: category,
        timestamp: timestamp,
        source: source,
        isRead: isRead ?? this.isRead,
        starred: starred ?? this.starred,
        liked: liked == _sentinel ? this.liked : liked as bool?,
        feedUrl: feedUrl,
        snippet: snippet,
        publishedDate: publishedDate,
        processedAt: processedAt,
        inFeed: inFeed ?? this.inFeed,
        feedReason: feedReason,
        topics: topics,
      );
}

const _sentinel = Object();
