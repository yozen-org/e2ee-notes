import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_keys/hardware_keys.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reports hardware-key capabilities', (tester) async {
    final capabilities = await HardwareKeys().capabilities();
    expect(capabilities.provider, isNotEmpty);
  });
}
