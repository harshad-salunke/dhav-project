import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DhavStoreApp());
    expect(find.byType(DhavStoreApp), findsOneWidget);
  });
}
