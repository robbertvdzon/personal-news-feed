class Category {
  final String id;
  final String name;
  bool enabled;
  String extraInstructions;

  Category({
    required this.id,
    required this.name,
    this.enabled = true,
    this.extraInstructions = '',
  });

  Category copyWith({
    bool? enabled,
    String? extraInstructions,
  }) {
    return Category(
      id: id,
      name: name,
      enabled: enabled ?? this.enabled,
      extraInstructions: extraInstructions ?? this.extraInstructions,
    );
  }
}
