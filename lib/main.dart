import 'package:flutter/material.dart';

import 'ui/arbiter_screen.dart';

/*
 * Entry point only. The integration is under lib/cloudx/ and the screen under
 * lib/ui/; nothing in this file touches an SDK.
 */
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArbiterDemoApp());
}

class ArbiterDemoApp extends StatelessWidget {
  const ArbiterDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloudX Trusted Arbiter',
      theme: ThemeData(useMaterial3: true),
      home: const ArbiterScreen(),
    );
  }
}
