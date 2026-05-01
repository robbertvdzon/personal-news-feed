import 'package:flutter/material.dart';

const _categoryColors = {
  'ai': Color(0xFF6C63FF),
  'crypto': Color(0xFFF7931A),
  'podcasts': Color(0xFF1DB954),
  'software': Color(0xFF0078D7),
};

class CategoryBadge extends StatelessWidget {
  final String categoryId;
  final String categoryName;

  const CategoryBadge({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColors[categoryId] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        categoryName,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
