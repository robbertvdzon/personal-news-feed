enum RequestStatus { pending, processing, done, failed }

class NewsRequest {
  final String id;
  final String subject;
  final String? sourceItemId;
  final String? sourceItemTitle;
  final int preferredCount;
  final int maxCount;
  final String extraInstructions;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int newItemCount;

  const NewsRequest({
    required this.id,
    required this.subject,
    this.sourceItemId,
    this.sourceItemTitle,
    this.preferredCount = 2,
    this.maxCount = 5,
    this.extraInstructions = '',
    this.status = RequestStatus.pending,
    required this.createdAt,
    this.completedAt,
    this.newItemCount = 0,
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
      status: RequestStatus.values.byName(
        (json['status'] as String).toLowerCase(),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      newItemCount: json['newItemCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'subject': subject,
        if (sourceItemId != null) 'sourceItemId': sourceItemId,
        if (sourceItemTitle != null) 'sourceItemTitle': sourceItemTitle,
        'preferredCount': preferredCount,
        'maxCount': maxCount,
        if (extraInstructions.isNotEmpty) 'extraInstructions': extraInstructions,
      };

  NewsRequest copyWith({
    RequestStatus? status,
    DateTime? completedAt,
    int? newItemCount,
    bool clearCompletedAt = false,
  }) {
    return NewsRequest(
      id: id,
      subject: subject,
      sourceItemId: sourceItemId,
      sourceItemTitle: sourceItemTitle,
      preferredCount: preferredCount,
      maxCount: maxCount,
      extraInstructions: extraInstructions,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      newItemCount: newItemCount ?? this.newItemCount,
    );
  }
}
