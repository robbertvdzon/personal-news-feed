class NewsItem {
  final String id;
  final String title;
  final String summary;
  final String url;
  final String category;
  final DateTime timestamp;
  final String source;

  const NewsItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.url,
    required this.category,
    required this.timestamp,
    required this.source,
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
    );
  }
}
