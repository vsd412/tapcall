import 'package:flutter_test/flutter_test.dart';
import 'package:tapcall/main.dart';

void main() {
  testWidgets('App renders home page title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    
    // Check for the app title
    expect(find.text('TapCall'), findsOneWidget);
  });
}