import 'package:flutter/material.dart';
import 'package:secure_keys/secure_enclave.dart';

void main() => runApp(const SecureKeysExample());

class SecureKeysExample extends StatelessWidget {
  const SecureKeysExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Hardware Keys')),
        body: FutureBuilder<HardwareKeyCapabilities>(
          future: SecureEnclaveKeys().capabilities(),
          builder: (context, snapshot) => Center(
            child: Text(
              snapshot.hasData
                  ? '${snapshot.data!.provider}: ${snapshot.data!.available}'
                  : 'Checking hardware key support…',
            ),
          ),
        ),
      ),
    );
  }
}
