import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import '../../../core/constants/app_images/app_images.dart';
import '../../../controllers/Main Section Controllers/settings_controller.dart';

class StreamScreen extends StatelessWidget {
  const StreamScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Image
          // Background Image
          Positioned.fill(
            child: Image.asset(
              background_image,
              fit: BoxFit.cover,
            ),
          ),

          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2C2C1E), Color(0xFF000000)],
                ),
              ),
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 10.h),

                // A. Top Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: const _TopHeader(),
                ),

                SizedBox(height: 20.h),

                // B. Stream Grid (4 items: Active, Empty, Empty, Active)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: SizedBox(
                    height: 250.h,
                    child: const _StreamGridDisplay(),
                  ),
                ),

                SizedBox(height: 20.h),

                // C. Stats Row (Twitch, Kick, Youtube pills)
                const _StatsRow(),

                SizedBox(height: 20.h),

                // D. Bottom Chat/Activity Section
                const Expanded(child: _ChatBottomSection()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WIDGETS COMPONENTS
// ---------------------------------------------------------------------------

class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Profile/Logo Pill
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            children: [
              Image.asset(gradient_fire_icon, height: 20.w,),
              SizedBox(width: 5.w),
              Text("-", style: TextStyle(color: Colors.white, fontSize: 14.sp)),
            ],
          ),
        ),

        // Action Buttons
        Row(
          children: [
            _circleButton(gift_icon),
            SizedBox(width: 10.w),
            _circleButton(setting_icon),
          ],
        )
      ],
    );
  }

  Widget _circleButton(String icon) {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: Image.asset(icon, height: 20.w,),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.find<SettingsController>();
    return Obx(() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _statPill(controller.getPlatformColor('twitch'), twitch_icon, "11202", true), // Twitch style
          SizedBox(width: 12.w),
          _statPill(controller.getPlatformColor('kick'), kick_icon, "1256", true), // Kick style
          SizedBox(width: 12.w),
          _statPill(controller.getPlatformColor('youtube'), youtube_icon, "256", true), // Youtube style
        ],
      );
    });
  }

  Widget _statPill(Color color, String icon, String count, bool coloredBack) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: coloredBack ? color.withOpacity(.2) : Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Image.asset(icon, height: 10.h, color: color,),
          SizedBox(width: 8.w),
          Text(
            count,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

class _StreamGridDisplay extends StatelessWidget {
  const _StreamGridDisplay();

  @override
  Widget build(BuildContext context) {
    // Hardcoded 4 streams to match the 2x2 layout in the screenshot
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.4, // Aspect ratio to match the rectangular shape
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        // Pattern: Active, Empty, Empty, Active
        bool isActive = index == 0 || index == 3;

        if (!isActive) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: CustomPaint(painter: _CheckerboardPainter()),
          );
        }

        return _ActiveStreamCell(index: index);
      },
    );
  }
}

class _ActiveStreamCell extends StatelessWidget {
  final int index;
  const _ActiveStreamCell({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade800),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background (Simulated Game Feed)
          Container(color: const Color(0xFF1a1a1a)),
          Center(child: Icon(Icons.map, color: Colors.brown.shade800, size: 40.sp)),

          // Left Sidebar Overlay
          Positioned(
            left: 0, top: 0, bottom: 0,
            width: 30.w,
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),

          // Right Buttons Overlay
          Positioned(
            right: 4.w, top: 20.h,
            child: Column(
              children: List.generate(4, (i) => Container(
                margin: EdgeInsets.only(bottom: 4.h),
                width: 12.w, height: 6.h,
                color: Colors.blueGrey,
              )),
            ),
          ),

          // Webcam (Bottom Left)
          Positioned(
            bottom: 4.h,
            left: 4.w,
            child: Container(
              width: 40.w,
              height: 30.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.person, color: Colors.white54, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBottomSection extends StatelessWidget {
  const _ChatBottomSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: onBottomSheetGrey,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: Column(
        children: [
          SizedBox(height: 10.h),
          // Handle Bar
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 16.h),

          // Tabs (Activity / Title)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              children: [
                pillButton("Activity", isActive: false),
                const Spacer(),
                pillButton("Title", isActive: false),
                SizedBox(width: 12.w),
                Icon(Icons.open_in_full, color: Colors.grey.shade600, size: 18.sp),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Chat List
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              children: [
                _chatItem(Colors.green, "SuperFan", "Great Stream!"),
                _chatItem(Colors.green, "SuperGirl", "Great Stream!"),
                _chatItem(Colors.red, "Alberes", "What you just saw was the vertical sapzer hupwithout the inverse stream rhurst"),
                _chatItem(Colors.deepPurple, "GigaChad", "Back ldffsagg ydgou my girld"),
                _chatItem(Colors.red, "Nutty", "How many could i tech a few triks lalalal amazing stream lest"),
                _chatItem(Colors.deepPurple, "ChatStreamer", "I love you my boy"),
                _chatItem(Colors.green, "SuperGirl", "Great Stream!"),
              ],
            ),
          ),

          // Input Field
          Container(
            padding: EdgeInsets.all(16.w),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              height: 50.h,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(25.r),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Text("Text", style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp)),
                  const Spacer(),
                  Icon(Icons.emoji_emotions_outlined, color: Colors.white, size: 20.sp),
                  SizedBox(width: 10.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(12.r)
                    ),
                    child: Row(
                      children: [
                        Text("All", style: TextStyle(color: Colors.white, fontSize: 12.sp)),
                        Icon(Icons.unfold_more, color: Colors.grey, size: 14.sp)
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget pillButton(String text, {required bool isActive, String? assetPath}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1E1E1E) : Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isActive ? const Color(0XFFFFE6A7) : Colors.grey.shade800,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (assetPath != null) ...[
            Image.asset(
              assetPath,
              width: 16.w,
              height: 16.h,
              color: isActive ? const Color(0XFFFFE6A7) : Colors.grey.shade600,
            ),
            SizedBox(width: 6.w),
          ],
          Text(
            text,
            style: TextStyle(
              color: isActive ? const Color(0XFFFFE6A7) : Colors.grey.shade600,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatItem(Color iconColor, String name, String message) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: RichText(
        text: TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(right: 6.w),
                child: Icon(Icons.close, color: iconColor, size: 14.sp), // Using 'close' or 'x' icon as placeholder for platform logo
              ),
            ),
            TextSpan(
              text: "$name: ",
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
              ),
            ),
            TextSpan(
              text: message,
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PAINTERS
// ---------------------------------------------------------------------------

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paintGrey = Paint()..color = const Color(0xFFEEEEEE);
    final Paint paintWhite = Paint()..color = const Color(0xFFFFFFFF);

    // Scale square size based on container width
    final double squareSize = size.width / 10;

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        bool isGrey = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isGrey ? paintGrey : paintWhite,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}