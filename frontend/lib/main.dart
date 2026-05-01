import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/news_feed_screen.dart';

void main() {
  runApp(const ProviderScope(child: PersonalNewsFeedApp()));
}

class PersonalNewsFeedApp extends StatelessWidget {
  const PersonalNewsFeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Persoonlijk Nieuwsoverzicht',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
      ),
      home: const NewsFeedScreen(),
    );
  }
}
