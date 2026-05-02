class CategoryResult {
  final String categoryId;
  final String categoryName;
  final int articleCount;
  final double costUsd;

  const CategoryResult({
    required this.categoryId,
    required this.categoryName,
    required this.articleCount,
    required this.costUsd,
  });

  factory CategoryResult.fromJson(Map<String, dynamic> json) => CategoryResult(
        categoryId: json['categoryId'] as String,
        categoryName: json['categoryName'] as String,
        articleCount: json['articleCount'] as int? ?? 0,
        costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0.0,
      );
}
