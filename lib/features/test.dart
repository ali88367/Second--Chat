import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';

class Test extends StatelessWidget {
  const Test({super.key});

  @override
  Widget build(BuildContext context) {
    const int selectedItem = 3;

    final List<int> allItems = List.generate(7, (index) => index + 1);
    final List<int> listItems =
    allItems.where((i) => i != selectedItem).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: GlassmorphicContainer(
          width: 100,
          height: 420,
          borderRadius: 50,
          blur: 20,
          alignment: Alignment.center,
          // Increased border width slightly so the "Low" sides are actually visible
          border: 2,

          linearGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF000000).withOpacity(0.8),
              const Color(0xFF1a1a1a).withOpacity(0.6),
            ],
            stops: const [0.1, 1],
          ),

          // --- FIXED BORDER GRADIENT ---
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              // 1. Top-Left Corner: VERY Bright (1.0)
              Colors.white.withOpacity(1),

              // 2. The Middle (Sides + TR + BL): Visible but Low (0.3)
              // We raised this from 0.05 to 0.3 so the sides don't disappear.
              Colors.white.withOpacity(0.3),
              Colors.white.withOpacity(0.3),

              // 3. Bottom-Right Corner: VERY Bright (1.0)
              Colors.white.withOpacity(1.0),
            ],

            // --- FIXED STOPS ---
            // 0.0 - 0.15: Bright Corner (Tight to the corner)
            // 0.15 - 0.85: Long section of Low Opacity (Covers the sides)
            // 0.85 - 1.0: Bright Corner (Tight to the corner)
            stops: const [0.0, 0.070, 0.90, 3.0],
          ),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

            ],
          ),
        ),
      ),
    );
  }
}