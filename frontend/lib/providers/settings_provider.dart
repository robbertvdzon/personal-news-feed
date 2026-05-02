import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class SettingsNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final auth = ref.watch(authProvider).valueOrNull;
    if (auth?.isLoggedIn != true) return [];
    return ApiService.fetchSettings();
  }

  Future<void> toggleCategory(String categoryId) => _mutate((cats) => [
        for (final cat in cats)
          if (cat.id == categoryId) cat.copyWith(enabled: !cat.enabled) else cat,
      ]);

  Future<void> updateExtraInstructions(String categoryId, String instructions) =>
      _mutate((cats) => [
            for (final cat in cats)
              if (cat.id == categoryId)
                cat.copyWith(extraInstructions: instructions)
              else
                cat,
          ]);

  Future<void> addCategory(String name) {
    final id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final cats = state.valueOrNull ?? [];
    if (cats.any((c) => c.id == id)) return Future.value();
    return _mutate((current) => [
          ...current,
          Category(id: id, name: name, enabled: true),
        ]);
  }

  Future<void> removeCategory(String categoryId) =>
      _mutate((cats) => cats.where((c) => c.id != categoryId).toList());

  Future<void> _mutate(List<Category> Function(List<Category>) updater) async {
    final current = state.valueOrNull ?? [];
    final updated = updater(current);
    state = AsyncData(updated);
    await ApiService.saveSettings(updated);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, List<Category>>(SettingsNotifier.new);

final enabledCategoryIdsProvider = Provider<Set<String>>((ref) {
  final cats = ref.watch(settingsProvider).valueOrNull ?? [];
  return cats.where((c) => c.enabled).map((c) => c.id).toSet();
});
