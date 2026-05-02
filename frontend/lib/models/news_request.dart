enum RequestStatus { pending, processing, done, failed }

class NewsRequest {
  final String id;
  final String subject;
  final String? sourceItemId;
  final String? sourceItemTitle;
  final int preferredCount;
  final int maxCount;
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
    this.status = RequestStatus.pending,
    required this.createdAt,
    this.completedAt,
    this.newItemCount = 0,
  });

  NewsRequest copyWith({
    RequestStatus? status,
    DateTime? completedAt,
    int? newItemCount,
  }) {
    return NewsRequest(
      id: id,
      subject: subject,
      sourceItemId: sourceItemId,
      sourceItemTitle: sourceItemTitle,
      preferredCount: preferredCount,
      maxCount: maxCount,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      newItemCount: newItemCount ?? this.newItemCount,
    );
  }
}
