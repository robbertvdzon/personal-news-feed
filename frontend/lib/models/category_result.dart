class CategoryResult {
  final String categoryId;
  final String categoryName;
  final int articleCount;
  final double costUsd;
  final int searchResultCount;
  final int filteredCount;

  const CategoryResult({
    required this.categoryId,
    required this.categoryName,
    required this.articleCount,
    required this.costUsd,
    this.searchResultCount = 0,
    this.filteredCount = 0,
  });

  factory CategoryResult.fromJson(Map<String, dynamic> json) => CategoryResult(
        categoryId: json['categoryId'] as String,
        categoryName: json['categoryName'] as String,
        articleCount: json['articleCount'] as int? ?? 0,
        costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0.0,
        searchResultCount: json['searchResultCount'] as int? ?? 0,
        filteredCount: json['filteredCount'] as int? ?? 0,
      );
}
