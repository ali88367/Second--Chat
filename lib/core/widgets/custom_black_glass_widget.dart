import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';

class CustomBlackGlassWidget extends StatelessWidget {
  final List<String> items;

  const CustomBlackGlassWidget({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            // Rounded pill shape
            borderRadius: BorderRadius.circular(35),

            // Gradient border with black on top-right and bottom-left
            border: GradientBoxBorder(
              gradient: SweepGradient(
                center: Alignment.center,
                startAngle: 0,
                endAngle: 6.28,
                colors: [
                  Colors.white.withOpacity(0.12),  // Right side
                  Colors.black,                    // Top-right corner (black)
                  // Top-left
                  Colors.white.withOpacity(0.12),  // Left side
                  Colors.black,                    // Bottom-left corner (black)
                  // Bottom-right
                  Colors.white.withOpacity(0.12),  // Back to right
                ],
                stops: [
                  0.0,    // Right (3 o'clock)
                  0.35,    // Top-right corner (black)
                  0.36,   // Top side
                   // Left (9 o'clock)
                  0.82,    // Bottom-left corner (black)
                  // Bottom-right
                  1.0,    // Back to right
                ],
              ),
              width: 1.2,
            ),

            // THE GRADIENT: Black -> subtle grey band -> black -> very subtle grey at bottom
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [
                0.0,    // Pure black top
                0.33,   // Start of first grey band
                0.43,   // End of first grey band
                0.7,    // Black until here
                1.0     // Very subtle grey at bottom
              ],
              colors: [
                Color(0xFF000000), // Pure black at top
                Color(0xFF171717), // Subtle grey band (less dense)
                Color(0xFF000000), // Back to pure black
                Color(0xFF000000), // Black continues
                Color(0xFF262626), // Very subtle grey at bottom (very less dense)
              ],
            ),

            // Optional: Subtle shadow to lift it off the background
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- 1. The Header (Checkmark + All) ---
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.checkmark,
                    color: Colors.white,
                    size: 20,
                    weight: 800,
                  ),
                  SizedBox(width: 6),
                  Text(
                    "All",
                    style: sfProText600(
                      17,
                      Colors.white,
                    ),
                  ),
                ],
              ),

              // --- 2. The Divider Line ---
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Container(
                  height: 1,
                  width: 50,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),

              // --- 3. Dynamic List Items ---
              ...items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    item,
                    textAlign: TextAlign.center,
                    style: sfProText400(
                      17,
                      _getColorForString(item),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // Logic to assign specific neon colors based on the text
  Color _getColorForString(String text) {
    switch (text.toLowerCase()) {
      case 'twitch':
        return twitchPurple;
      case 'kick':
        return kickGreen;
      case 'youtube':
        return youtubeRed;
      default:
        return Colors.white;
    }
  }
}