import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../models/news_request.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class RequestNotifier extends AsyncNotifier<List<NewsRequest>> {
  WebSocketChannel? _channel;

  @override
  Future<List<NewsRequest>> build() async {
    final auth = ref.watch(authProvider).valueOrNull;
    if (auth?.isLoggedIn != true) {
      return [];
    }
    final requests = await ApiService.fetchRequests();
    _connectWebSocket();
    ref.onDispose(_disconnect);
    return requests;
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('${AppConfig.wsBaseUrl}/ws/requests'),
      );
      _channel!.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final updated = NewsRequest.fromJson(json);
      final current = state.valueOrNull ?? [];
      final index = current.indexWhere((r) => r.id == updated.id);
      if (index == -1) return;
      final newList = [...current];
      newList[index] = updated;
      state = AsyncData(newList);
    } catch (_) {}
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (state is! AsyncError) _connectWebSocket();
    });
  }

  void _disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> addRequest({
    required String subject,
    String? sourceItemId,
    String? sourceItemTitle,
    int preferredCount = 2,
    int maxCount = 5,
  }) async {
    final newRequest = await ApiService.createRequest(
      subject: subject,
      sourceItemId: sourceItemId,
      sourceItemTitle: sourceItemTitle,
      preferredCount: preferredCount,
      maxCount: maxCount,
    );
    final current = state.valueOrNull ?? [];
    state = AsyncData([newRequest, ...current]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(ApiService.fetchRequests);
    _connectWebSocket();
  }
}

final requestProvider =
    AsyncNotifierProvider<RequestNotifier, List<NewsRequest>>(
        RequestNotifier.new);

final activeRequestCountProvider = Provider<int>((ref) {
  final requests = ref.watch(requestProvider).valueOrNull ?? [];
  return requests
      .where((r) =>
          r.status == RequestStatus.pending ||
          r.status == RequestStatus.processing)
      .length;
});
