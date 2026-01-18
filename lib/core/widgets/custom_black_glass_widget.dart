import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';

class CustomBlackGlassWidget extends StatefulWidget {
  final List<String> items;
  final bool isWeek;
  final Function(String)? onItemSelected;

  const CustomBlackGlassWidget({
    super.key,
    required this.items,
    required this.isWeek,
    this.onItemSelected,
  });

  @override
  State<CustomBlackGlassWidget> createState() => _CustomBlackGlassWidgetState();
}

class _CustomBlackGlassWidgetState extends State<CustomBlackGlassWidget> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.isWeek ? 30 : 35),
          child: widget.isWeek
              ? BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: _buildContainer(),
          )
              : _buildContainer(),
        ),
      ],
    );
  }

  Widget _buildContainer() {
    return Container(
      width: widget.isWeek ? 90.w : null,
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.isWeek ? 38 : 35),

        // Gradient border with black on top-right and bottom-left
        border: GradientBoxBorder(
          gradient: SweepGradient(
            center: Alignment.center,
            startAngle: 0,
            endAngle: 6.28,
            colors: [
              Colors.white.withOpacity(0.12),  // Right side
              Colors.black,                    // Top-right corner (black)
              Colors.white.withOpacity(0.12),  // Top side
              Colors.white.withOpacity(0.12),  // Left side
              Colors.black,                    // Bottom-left corner (black)
              Colors.white.withOpacity(0.12),  // Back to right
            ],
            stops: widget.isWeek ? [
              0.0,
              0.3,
              0.34,
              0.65,
              0.75,
              1.0,
            ] : [
              0.0,
              0.35,
              0.36,
              0.82,
              0.83,
              1.0,
            ],
          ),
          width: 1.2,
        ),

        // Background color or gradient based on isWeek
        color: widget.isWeek ? Colors.black.withOpacity(.2) : null,
        gradient: widget.isWeek
            ? null
            : LinearGradient(
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

        // Box shadow based on isWeek
        boxShadow: widget.isWeek
            ? [
          BoxShadow(
            color: Color(0xFF000000).withOpacity(0.25),
            blurRadius: 4,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ]
            : [
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
          // --- 1. The Header (Checkmark + Selected Item) ---
          GestureDetector(
            onTap: () {
              setState(() {
                selectedIndex = 0;
              });
              if (widget.onItemSelected != null) {
                widget.onItemSelected!(widget.items[0]);
              }
            },
            child: Row(
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
                  widget.items[selectedIndex],
                  style: sfProText600(
                    17,
                    selectedIndex == 0
                        ? Colors.white
                        : _getColorForString(widget.items[selectedIndex]),
                  ),
                ),
              ],
            ),
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

          // --- 3. Dynamic List Items (excluding selected) ---
          ...List.generate(widget.items.length, (index) {
            if (index == selectedIndex) return SizedBox.shrink();

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedIndex = index;
                });
                if (widget.onItemSelected != null) {
                  widget.onItemSelected!(widget.items[index]);
                }
              },
              child: Padding(
                padding: EdgeInsets.only(top: widget.isWeek ? 24 : 16),
                child: Text(
                  widget.items[index],
                  textAlign: TextAlign.center,
                  style: sfProText400(
                    17,
                    _getColorForString(widget.items[index]),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Logic to assign specific neon colors based on the text
  Color _getColorForString(String text) {
    switch (text.toLowerCase()) {
      case 'all':
        return Colors.white;
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