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
  final bool isSummary;

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
    this.isSummary = false,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      url: json['url'] as String,
      category: json['category'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      source: json['source'] as String,
      isRead: json['isRead'] as bool? ?? false,
      starred: json['starred'] as bool? ?? false,
      liked: json['liked'] as bool?,
      isSummary: json['isSummary'] as bool? ?? false,
    );
  }

  NewsItem copyWith({bool? isRead, bool? starred, bool? isSummary, Object? liked = _sentinel}) => NewsItem(
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
        isSummary: isSummary ?? this.isSummary,
      );
}

const _sentinel = Object();
