class RssFeedsSettings {
  final List<String> feeds;

  const RssFeedsSettings({this.feeds = const []});

  factory RssFeedsSettings.fromJson(Map<String, dynamic> json) =>
      RssFeedsSettings(
        feeds: (json['feeds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {'feeds': feeds};

  RssFeedsSettings copyWith({List<String>? feeds}) =>
      RssFeedsSettings(feeds: feeds ?? List.from(this.feeds));
}
