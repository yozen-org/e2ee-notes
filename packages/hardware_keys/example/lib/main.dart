import 'package:flutter/material.dart';
import 'package:hardware_keys/hardware_keys.dart';

void main() => runApp(const HardwareKeysExample());

class HardwareKeysExample extends StatelessWidget {
  const HardwareKeysExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Hardware Keys')),
        body: FutureBuilder<HardwareKeyCapabilities>(
          future: HardwareKeys().capabilities(),
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
