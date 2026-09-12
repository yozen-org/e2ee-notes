import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_enclave.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reports hardware-key capabilities', (tester) async {
    final capabilities = await SecureEnclaveKeys().capabilities();
    expect(capabilities.provider, isNotEmpty);
  });
}
