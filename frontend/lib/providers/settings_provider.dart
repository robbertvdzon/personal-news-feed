import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../data/mock_data.dart';

class SettingsNotifier extends Notifier<List<Category>> {
  @override
  List<Category> build() {
    return mockCategories
        .map((c) => Category(
              id: c.id,
              name: c.name,
              enabled: c.enabled,
              extraInstructions: c.extraInstructions,
              isSystem: c.isSystem,
            ))
        .toList();
  }

  void toggleCategory(String categoryId) {
    state = [
      for (final cat in state)
        if (cat.id == categoryId)
          cat.copyWith(enabled: !cat.enabled)
        else
          cat,
    ];
  }

  void updateExtraInstructions(String categoryId, String instructions) {
    state = [
      for (final cat in state)
        if (cat.id == categoryId)
          cat.copyWith(extraInstructions: instructions)
        else
          cat,
    ];
  }

  void addCategory(String name) {
    final id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    if (state.any((c) => c.id == id)) return;
    state = [
      ...state,
      Category(id: id, name: name, enabled: true),
    ];
  }

  void removeCategory(String categoryId) {
    state = state.where((c) => c.id != categoryId).toList();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, List<Category>>(
  SettingsNotifier.new,
);

final enabledCategoryIdsProvider = Provider<Set<String>>((ref) {
  return ref
      .watch(settingsProvider)
      .where((c) => c.enabled)
      .map((c) => c.id)
      .toSet();
});
