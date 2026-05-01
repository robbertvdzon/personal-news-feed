import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_news_feed/main.dart';

void main() {
  testWidgets('News feed smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PersonalNewsFeedApp()),
    );
    expect(find.text('Nieuws'), findsOneWidget);
  });
}
