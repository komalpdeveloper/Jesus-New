import 'package:flutter/material.dart';
import 'presentation/inventory_screen.dart';

/// Demo file to test the Inventory Screen
/// 
/// To use this screen in your app, add it to your routes:
/// 
/// ```dart
/// MaterialApp(
///   routes: {
///     '/inventory': (context) => const InventoryScreen(),
///   },
/// )
/// ```
/// 
/// Or navigate directly:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (context) => const InventoryScreen()),
/// );
/// ```

void main() {
  runApp(const InventoryDemo());
}

class InventoryDemo extends StatelessWidget {
  const InventoryDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WORDMART Inventory',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1410),
      ),
      home: const InventoryScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
