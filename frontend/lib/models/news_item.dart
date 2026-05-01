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
}
