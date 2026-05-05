import 'category_result.dart';

enum RequestStatus { pending, processing, done, failed }

class NewsRequest {
  final String id;
  final String subject;
  final String? sourceItemId;
  final String? sourceItemTitle;
  final int preferredCount;
  final int maxCount;
  final String extraInstructions;
  final int maxAgeDays;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int newItemCount;
  final double costUsd;
  final bool isDailyUpdate;
  final List<CategoryResult> categoryResults;
  final DateTime? processingStartedAt;
  final int durationSeconds;

  const NewsRequest({
    required this.id,
    required this.subject,
    this.sourceItemId,
    this.sourceItemTitle,
    this.preferredCount = 2,
    this.maxCount = 5,
    this.extraInstructions = '',
    this.maxAgeDays = 3,
    this.status = RequestStatus.pending,
    required this.createdAt,
    this.completedAt,
    this.newItemCount = 0,
    this.costUsd = 0.0,
    this.isDailyUpdate = false,
    this.categoryResults = const [],
    this.processingStartedAt,
    this.durationSeconds = 0,
  });

  factory NewsRequest.fromJson(Map<String, dynamic> json) {
    return NewsRequest(
      id: json['id'] as String,
      subject: json['subject'] as String,
      sourceItemId: json['sourceItemId'] as String?,
      sourceItemTitle: json['sourceItemTitle'] as String?,
      preferredCount: json['preferredCount'] as int? ?? 2,
      maxCount: json['maxCount'] as int? ?? 5,
      extraInstructions: json['extraInstructions'] as String? ?? '',
      maxAgeDays: json['maxAgeDays'] as int? ?? 3,
      status: RequestStatus.values.byName(
        (json['status'] as String).toLowerCase(),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      newItemCount: json['newItemCount'] as int? ?? 0,
      costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0.0,
      isDailyUpdate: json['isDailyUpdate'] as bool? ?? false,
      categoryResults: (json['categoryResults'] as List<dynamic>?)
              ?.map((e) => CategoryResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      processingStartedAt: json['processingStartedAt'] != null
          ? DateTime.parse(json['processingStartedAt'] as String)
          : null,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'subject': subject,
        if (sourceItemId != null) 'sourceItemId': sourceItemId,
        if (sourceItemTitle != null) 'sourceItemTitle': sourceItemTitle,
        'preferredCount': preferredCount,
        'maxCount': maxCount,
        if (extraInstructions.isNotEmpty) 'extraInstructions': extraInstructions,
        'maxAgeDays': maxAgeDays,
      };

  NewsRequest copyWith({
    RequestStatus? status,
    DateTime? completedAt,
    int? newItemCount,
    bool clearCompletedAt = false,
    double? costUsd,
    List<CategoryResult>? categoryResults,
    DateTime? processingStartedAt,
    int? durationSeconds,
  }) {
    return NewsRequest(
      id: id,
      subject: subject,
      sourceItemId: sourceItemId,
      sourceItemTitle: sourceItemTitle,
      preferredCount: preferredCount,
      maxCount: maxCount,
      extraInstructions: extraInstructions,
      maxAgeDays: maxAgeDays,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      newItemCount: newItemCount ?? this.newItemCount,
      costUsd: costUsd ?? this.costUsd,
      isDailyUpdate: isDailyUpdate,
      categoryResults: categoryResults ?? this.categoryResults,
      processingStartedAt: processingStartedAt ?? this.processingStartedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}
