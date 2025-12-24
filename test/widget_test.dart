import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PersonalAssistantApp());
    expect(find.text('المساعد الشخصي'), findsOneWidget);
  });
}
