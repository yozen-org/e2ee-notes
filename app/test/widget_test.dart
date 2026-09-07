import 'package:e2ee_notes/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the encrypted notes foundation screen', (tester) async {
    await tester.pumpWidget(const E2eeNotesApp());
    expect(find.text('E2EE Notes'), findsOneWidget);
    expect(find.text('Your notes, your keys, your storage.'), findsOneWidget);
  });
}
