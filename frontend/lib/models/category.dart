class Category {
  final String id;
  final String name;
  bool enabled;
  String extraInstructions;
  final bool isSystem;

  Category({
    required this.id,
    required this.name,
    this.enabled = true,
    this.extraInstructions = '',
    this.isSystem = false,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        enabled: json['enabled'] as bool? ?? true,
        extraInstructions: json['extraInstructions'] as String? ?? '',
        isSystem: json['isSystem'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'extraInstructions': extraInstructions,
        'isSystem': isSystem,
      };

  Category copyWith({bool? enabled, String? extraInstructions}) => Category(
        id: id,
        name: name,
        enabled: enabled ?? this.enabled,
        extraInstructions: extraInstructions ?? this.extraInstructions,
        isSystem: isSystem,
      );
}
