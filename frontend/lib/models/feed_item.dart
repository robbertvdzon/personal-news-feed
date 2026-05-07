class FeedItem {
  final String id;
  final String title;
  final String summary;
  final String url;
  final String category;
  final String source;
  final List<String> sourceRssIds;
  final List<String> sourceUrls;
  final List<String> topics;
  final String feedReason;
  final bool isRead;
  final bool starred;
  final bool? liked;
  final DateTime createdAt;
  final DateTime? publishedDate;
  final bool isSummary;

  const FeedItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.url,
    required this.category,
    required this.source,
    this.sourceRssIds = const [],
    this.sourceUrls = const [],
    this.topics = const [],
    this.feedReason = '',
    this.isRead = false,
    this.starred = false,
    this.liked,
    required this.createdAt,
    this.publishedDate,
    this.isSummary = false,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      url: json['url'] as String? ?? '',
      category: json['category'] as String? ?? '',
      source: json['source'] as String? ?? '',
      sourceRssIds: (json['sourceRssIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      sourceUrls: (json['sourceUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      topics: (json['topics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      feedReason: json['feedReason'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      starred: json['starred'] as bool? ?? false,
      liked: json['liked'] as bool?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      publishedDate: json['publishedDate'] != null
          ? DateTime.tryParse(json['publishedDate'] as String)
          : null,
      isSummary: json['isSummary'] as bool? ?? false,
    );
  }

  FeedItem copyWith({
    bool? isRead,
    bool? starred,
    Object? liked = _sentinel,
    bool clearLiked = false,
  }) =>
      FeedItem(
        id: id,
        title: title,
        summary: summary,
        url: url,
        category: category,
        source: source,
        sourceRssIds: sourceRssIds,
        sourceUrls: sourceUrls,
        topics: topics,
        feedReason: feedReason,
        isRead: isRead ?? this.isRead,
        starred: starred ?? this.starred,
        liked: clearLiked
            ? null
            : (liked == _sentinel ? this.liked : liked as bool?),
        createdAt: createdAt,
        publishedDate: publishedDate,
        isSummary: isSummary,
      );
}

const _sentinel = Object();
