import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

void main() => runApp(const SecureKeysExample());

class SecureKeysExample extends StatelessWidget {
  const SecureKeysExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Hardware Keys')),
        body: FutureBuilder<KeyCapabilities>(
          future: PlatformSecureKey().capabilities(),
          builder: (context, snapshot) => Center(
            child: Text(
              snapshot.hasData
                  ? 'Hardware backed: ${snapshot.data!.hardwareBacked}'
                  : 'Checking hardware key support…',
            ),
          ),
        ),
      ),
    );
  }
}
