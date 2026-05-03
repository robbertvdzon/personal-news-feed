class Category {
  final String id;
  String name;
  bool enabled;
  String extraInstructions;
  final bool isSystem;
  int preferredCount;
  int maxCount;
  List<String> websites;

  Category({
    required this.id,
    required this.name,
    this.enabled = true,
    this.extraInstructions = '',
    this.isSystem = false,
    this.preferredCount = 3,
    this.maxCount = 5,
    List<String>? websites,
  }) : websites = websites ?? [];

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        enabled: json['enabled'] as bool? ?? true,
        extraInstructions: json['extraInstructions'] as String? ?? '',
        isSystem: json['isSystem'] as bool? ?? false,
        preferredCount: json['preferredCount'] as int? ?? 3,
        maxCount: json['maxCount'] as int? ?? 5,
        websites: (json['websites'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'extraInstructions': extraInstructions,
        'isSystem': isSystem,
        'preferredCount': preferredCount,
        'maxCount': maxCount,
        'websites': websites,
      };

  Category copyWith({
    String? name,
    bool? enabled,
    String? extraInstructions,
    int? preferredCount,
    int? maxCount,
    List<String>? websites,
  }) =>
      Category(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        extraInstructions: extraInstructions ?? this.extraInstructions,
        isSystem: isSystem,
        preferredCount: preferredCount ?? this.preferredCount,
        maxCount: maxCount ?? this.maxCount,
        websites: websites ?? List.from(this.websites),
      );
}
