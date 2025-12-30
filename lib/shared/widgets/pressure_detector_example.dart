// import 'package:flutter/material.dart';
// import 'package:clientapp/shared/widgets/pressure_detector.dart';

// /// Example usage of PressureDetector widget
// /// 
// /// This file demonstrates how to integrate pressure detection
// /// into any widget in your app.

// class PressureDetectorExample extends StatefulWidget {
//   const PressureDetectorExample({super.key});

//   @override
//   State<PressureDetectorExample> createState() => _PressureDetectorExampleState();
// }

// class _PressureDetectorExampleState extends State<PressureDetectorExample> {
//   String _message = 'Press the button';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(_message, style: const TextStyle(fontSize: 24)),
//             const SizedBox(height: 32),
            
//             // Example 1: Basic usage with pressure change callback
//             PressureDetector(
//               onPressureChanged: (level) {
//                 setState(() {
//                   _message = 'Pressure: ${level.name}';
//                 });
//               },
//               child: Container(
//                 width: 200,
//                 height: 200,
//                 decoration: BoxDecoration(
//                   color: Colors.blue,
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: const Center(
//                   child: Text(
//                     'Press Me',
//                     style: TextStyle(color: Colors.white, fontSize: 20),
//                   ),
//                 ),
//               ),
//             ),
            
//             const SizedBox(height: 32),
            
//             // Example 2: Custom thresholds and continuous updates
//             PressureDetector(
//               mediumThreshold: 8.0,  // Lower threshold for medium
//               heavyThreshold: 15.0,   // Lower threshold for heavy
//               onPressureUpdate: (pressure) {
//                 // Get continuous pressure values
//                 debugPrint('Current pressure: $pressure');
//               },
//               onPressureChanged: (level) {
//                 // React to level changes
//                 if (level == PressureLevel.heavy) {
//                   // Do something special on heavy press
//                   debugPrint('Heavy press detected!');
//                 }
//               },
//               child: ElevatedButton(
//                 onPressed: () {},
//                 child: const Text('Custom Thresholds'),
//               ),
//             ),
            
//             const SizedBox(height: 32),
            
//             // Example 3: Disable haptics
//             PressureDetector(
//               enableHaptics: false,
//               onPressureChanged: (level) {
//                 setState(() {
//                   _message = 'Silent press: ${level.name}';
//                 });
//               },
//               child: Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.green,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Text(
//                   'No Haptics',
//                   style: TextStyle(color: Colors.white),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
