import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:ios_color_picker/show_ios_color_picker.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/constants/app_images/app_images.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/settings_controller.dart';

class PlatformColorSettings extends StatefulWidget {
  const PlatformColorSettings({super.key});

  @override
  State<PlatformColorSettings> createState() => _PlatformColorSettingsState();
}

class _PlatformColorSettingsState extends State<PlatformColorSettings> {
  final SettingsController _controller = Get.find<SettingsController>();

  // Current selected platform and color
  String _selectedPlatform = 'Twitch';
  Color _selectedColor = const Color(0xFF9146FF); // Twitch purple default
  double _opacity = 1.0;

  // Controller for the color picker
  final IOSColorPickerController _colorPickerController =
      IOSColorPickerController();

  // PageController for platform buttons scroll
  final PageController _pageController = PageController(viewportFraction: 0.7);
  int _currentPage = 0;

  // Selected bottom button (0 for wifi, 1 for settings)
  int _selectedBottomButton = 1; // Initially settings is selected

  @override
  void initState() {
    super.initState();
    // Initialize with Twitch color
    _selectedColor = _controller.twitchColor.value ?? twitchPurple;

    // Listen to page changes
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() {
          _currentPage = page;
          // Update selected platform based on page
          switch (page) {
            case 0:
              _selectedPlatform = 'Twitch';
              _selectedColor = _controller.twitchColor.value ?? twitchPurple;
              break;
            case 1:
              _selectedPlatform = 'Kick';
              _selectedColor = _controller.kickColor.value ?? kickGreen;
              break;
            case 2:
              _selectedPlatform = 'YouTube';
              _selectedColor = _controller.youtubeColor.value ?? youtubeRed;
              break;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _colorPickerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Function to open the full iOS color picker
  void _openColorPicker() {
    _colorPickerController.showIOSCustomColorPicker(
      context: context,
      startingColor: _selectedColor.withOpacity(_opacity),
      onColorChanged: (color) {
        setState(() {
          _selectedColor = color.withAlpha(255); // Base color without opacity
          _opacity = color.opacity; // Extract opacity separately
          // Save the color for the selected platform
          _controller.setPlatformColor(_selectedPlatform, _selectedColor);
        });
      },
    );
  }

  void _selectPlatform(String platform) {
    setState(() {
      _selectedPlatform = platform;
      // Update color based on selected platform
      switch (platform.toLowerCase()) {
        case 'twitch':
          _selectedColor = _controller.twitchColor.value ?? twitchPurple;
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          break;
        case 'kick':
          _selectedColor = _controller.kickColor.value ?? kickGreen;
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          break;
        case 'youtube':
          _selectedColor = _controller.youtubeColor.value ?? youtubeRed;
          _pageController.animateToPage(
            2,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color displayColor = _selectedColor.withOpacity(_opacity);

    return Container(
      color: Color.fromRGBO(20, 18, 18, 1),
      child: Column(
        children: [
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Get.back(),
                  child: Image.asset(back_arrow_icon, height: 44.h),
                ),
                Text("Platform Colours", style: sfProDisplay600(17.sp, onDark)),
                SizedBox(width: 44.w),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: Column(
              children: [
                // Horizontal scrollable platform buttons with PageView
                SizedBox(
                  height: 44.h,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.w),
                        child: Obx(() {
                          Color color;
                          String platform;
                          String icon;
                          switch (index) {
                            case 0:
                              platform = 'Twitch';
                              icon = twitch_icon;
                              color =
                                  _controller.twitchColor.value ?? twitchPurple;
                              break;
                            case 1:
                              platform = 'Kick';
                              icon = kick_icon;
                              color = _controller.kickColor.value ?? kickGreen;
                              break;
                            case 2:
                              platform = 'YouTube';
                              icon = youtube_icon;
                              color =
                                  _controller.youtubeColor.value ?? youtubeRed;
                              break;
                            default:
                              platform = 'Twitch';
                              icon = twitch_icon;
                              color = twitchPurple;
                          }
                          return _buildPlatformButton(
                            platform,
                            icon,
                            color,
                            index,
                          );
                        }),
                      );
                    },
                  ),
                ),
                SizedBox(height: 10.h),
                // Page indicator dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildDot(0),
                    SizedBox(width: 6.w),
                    _buildDot(1),
                    SizedBox(width: 6.w),
                    _buildDot(2),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 8.h),

          // Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Colours',
                style: TextStyle(
                  fontFamily: 'SFProDisplay',
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          SizedBox(height: 40.h),

          // Color Preview + Tap to Open Picker
          GestureDetector(
            onTap: _openColorPicker,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 24.w),
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: onBottomSheetGrey,
                borderRadius: BorderRadius.circular(30.r),
              ),
              child: Column(
                children: [
                  // Large color swatch with white ring
                  Container(
                    width: 100.r,
                    height: 100.r,
                    decoration: BoxDecoration(
                      color: displayColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4.w),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Tap to select colours',
                    style: TextStyle(
                      fontFamily: 'SFProText',
                      fontSize: 16.sp,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          Container(
            height: 57.h,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(35),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBottomButton = 0;
                    });
                  },
                  child: Container(
                    width: 61.w,
                    height: 51.h,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _selectedBottomButton == 0
                          ? Color(0xFF2C2C2E)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(33),
                    ),
                    child: Center(
                      child: Image.asset(
                        wifi_icon,
                        height: 26.h,
                        color: _selectedBottomButton == 0
                            ? Color(0xFFFFE6A7) // Gold color when selected
                            : Colors.white, // White when unselected
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBottomButton = 1;
                    });
                  },
                  child: Container(
                    width: 61.w,
                    height: 51.h,
                    margin: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _selectedBottomButton == 1
                          ? Color(0xFF2C2C2E)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(33),
                    ),
                    child: Center(
                      child: Image.asset(
                        setting_icon,
                        height: 26.h,
                        color: _selectedBottomButton == 1
                            ? Color(0xFFFFE6A7) // Gold color when selected
                            : Colors.white, // White when unselected
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 30.h),
        ],
      ),
    );
  }

  Widget _buildPlatformButton(
    String platform,
    String icon,
    Color currentColor,
    int index,
  ) {
    final bool isSelected = _currentPage == index;
    return GestureDetector(
      onTap: () => _selectPlatform(platform),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: isSelected ? currentColor : onBottomSheetGrey,
          borderRadius: BorderRadius.circular(30.r),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(icon, width: 20.w, height: 20.h, fit: BoxFit.contain),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  platform,
                  style: TextStyle(
                    fontFamily: 'SFProDisplay',
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.start,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final bool isSelected = _currentPage == index;
    return CircleAvatar(
      radius: 4.r,
      backgroundColor: isSelected ? Colors.white : Colors.grey,
    );
  }
}

// Checkerboard pattern for transparency preview
class CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final squareSize = size.width / 8;

    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 8; j++) {
        paint.color = (i + j) % 2 == 0 ? Colors.grey[700]! : Colors.grey[600]!;
        canvas.drawRect(
          Rect.fromLTWH(i * squareSize, j * squareSize, squareSize, squareSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
