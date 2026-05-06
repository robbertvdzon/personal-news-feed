import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../models/news_request.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';
import 'news_provider.dart';

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
      if (index == -1) {
        // ID niet gevonden - mogelijk race condition met temp-ID: refresh hele lijst
        _refreshSilent();
        return;
      }
      final newList = [...current];
      newList[index] = updated;
      state = AsyncData(newList);
      if (updated.status == RequestStatus.done ||
          updated.status == RequestStatus.cancelled) {
        ref.read(newsProvider.notifier).refresh();
      }
    } catch (_) {}
  }

  Future<void> _refreshSilent() async {
    try {
      final requests = await ApiService.fetchRequests();
      state = AsyncData(requests);
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
    String extraInstructions = '',
    int maxAgeDays = 3,
  }) async {
    // Optimistisch toevoegen zodat het meteen zichtbaar is
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final tempRequest = NewsRequest(
      id: tempId,
      subject: subject,
      sourceItemId: sourceItemId,
      sourceItemTitle: sourceItemTitle,
      preferredCount: preferredCount,
      maxCount: maxCount,
      extraInstructions: extraInstructions,
      maxAgeDays: maxAgeDays,
      status: RequestStatus.pending,
      createdAt: DateTime.now(),
    );
    final current = state.valueOrNull ?? [];
    state = AsyncData([tempRequest, ...current]);

    try {
      final newRequest = await ApiService.createRequest(
        subject: subject,
        sourceItemId: sourceItemId,
        sourceItemTitle: sourceItemTitle,
        preferredCount: preferredCount,
        maxCount: maxCount,
        extraInstructions: extraInstructions,
        maxAgeDays: maxAgeDays,
      );
      final updated = state.valueOrNull ?? [];
      state = AsyncData(updated.map((r) => r.id == tempId ? newRequest : r).toList());
    } catch (e) {
      final updated = state.valueOrNull ?? [];
      state = AsyncData(updated.where((r) => r.id != tempId).toList());
    }
  }

  Future<void> deleteRequest(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((r) => r.id != id).toList());
    await ApiService.deleteRequest(id);
  }

  Future<void> cancelRequest(String id) async {
    // Optimistisch status zetten
    final current = state.valueOrNull ?? [];
    final index = current.indexWhere((r) => r.id == id);
    if (index != -1) {
      final newList = [...current];
      newList[index] = newList[index].copyWith(status: RequestStatus.cancelled);
      state = AsyncData(newList);
    }
    await ApiService.cancelRequest(id);
  }

  Future<void> rerunRequest(NewsRequest request) async {
    // Optimistisch status resetten
    final current = state.valueOrNull ?? [];
    final index = current.indexWhere((r) => r.id == request.id);
    if (index != -1) {
      final newList = [...current];
      newList[index] = request.copyWith(status: RequestStatus.pending);
      state = AsyncData(newList);
    }
    await ApiService.rerunRequest(request.id);
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
