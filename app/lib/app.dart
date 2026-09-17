import 'package:flutter/material.dart';

class E2eeNotesApp extends StatelessWidget {
  const E2eeNotesApp({required this.home, super.key});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E2EE Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff395b64)),
        useMaterial3: true,
      ),
      home: home,
    );
  }
}
