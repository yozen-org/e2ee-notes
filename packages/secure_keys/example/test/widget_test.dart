import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys_example/main.dart';

void main() {
  testWidgets('shows the hardware-key example', (tester) async {
    await tester.pumpWidget(const SecureKeysExample());
    expect(find.text('Hardware Keys'), findsOneWidget);
    expect(find.text('Checking hardware key support…'), findsOneWidget);
  });
}
