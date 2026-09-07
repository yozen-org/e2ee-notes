import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_keys_example/main.dart';

void main() {
  testWidgets('shows the hardware-key example', (tester) async {
    await tester.pumpWidget(const HardwareKeysExample());
    expect(find.text('Hardware Keys'), findsOneWidget);
    expect(find.text('Checking hardware key support…'), findsOneWidget);
  });
}
