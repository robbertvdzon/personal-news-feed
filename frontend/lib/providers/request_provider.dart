import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/news_request.dart';

class RequestNotifier extends Notifier<List<NewsRequest>> {
  @override
  List<NewsRequest> build() => [
        NewsRequest(
          id: 'r1',
          subject: 'Rust async runtime vergelijking',
          preferredCount: 2,
          maxCount: 5,
          status: RequestStatus.done,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          completedAt: DateTime.now().subtract(const Duration(hours: 2)),
          newItemCount: 2,
        ),
        NewsRequest(
          id: 'r2',
          subject: 'Ethereum Layer 2 oplossingen',
          sourceItemTitle: 'Ethereum voltooit Pectra-upgrade',
          preferredCount: 3,
          maxCount: 5,
          status: RequestStatus.processing,
          createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        ),
        NewsRequest(
          id: 'r3',
          subject: 'Spring AI praktijkvoorbeelden',
          preferredCount: 2,
          maxCount: 4,
          status: RequestStatus.pending,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

  void addRequest({
    required String subject,
    String? sourceItemId,
    String? sourceItemTitle,
    int preferredCount = 2,
    int maxCount = 5,
  }) {
    final request = NewsRequest(
      id: 'r${DateTime.now().millisecondsSinceEpoch}',
      subject: subject,
      sourceItemId: sourceItemId,
      sourceItemTitle: sourceItemTitle,
      preferredCount: preferredCount,
      maxCount: maxCount,
      status: RequestStatus.pending,
      createdAt: DateTime.now(),
    );
    state = [request, ...state];
  }
}

final requestProvider =
    NotifierProvider<RequestNotifier, List<NewsRequest>>(RequestNotifier.new);

final activeRequestCountProvider = Provider<int>((ref) {
  return ref
      .watch(requestProvider)
      .where((r) =>
          r.status == RequestStatus.pending ||
          r.status == RequestStatus.processing)
      .length;
});
