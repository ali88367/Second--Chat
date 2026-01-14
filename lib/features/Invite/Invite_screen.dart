import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/themes/textstyles.dart';

class InviteBottomSheet extends StatelessWidget {
  const InviteBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy data for the codes
    final List<Map<String, dynamic>> inviteCodes = [
      {'code': 'HAKGP2X', 'isClaimed': false},
      {'code': 'JGLP56C', 'isClaimed': false},
      {'code': 'KNBP312', 'isClaimed': true},
      {'code': 'GASG651', 'isClaimed': false},
      {'code': 'KYSLM10', 'isClaimed': false},
    ];

    return Container(
      height: Get.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1C), // Dark background color from your screenshots
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // --- STACKED HEADER AREA ---
          // This Stack layers the background, the ticket, the close button, and the title.
          Stack(
            alignment: Alignment.topCenter,
            children: [
              // 1. Background Image (The "smoke" effect)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.asset(
                  "assets/images/Invite image.png",
                  width: double.infinity,
                  height: 240.h,
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Razor/Ticket Image (Layered on top of background)
              Positioned(
                top: 60.h,
                child: Image.asset(
                  "assets/images/ChatGPT Image 14 дек. 2025 г., 12_53_51 1.png",
                  width: 299.w,
                  fit: BoxFit.contain,
                ),
              ),

              // 3. Top Handlebar (Drag indicator)
              Positioned(
                top: 10.h,
                child: Container(
                  width: 36.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.5.r),
                  ),
                ),
              ),

              // 4. "Invites" Title
              Positioned(
                top: 20.h,
                child: Text(
                  "Invites",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // 5. Close Button (X Icon)
              Positioned(
                top: 15.h,
                left: 15.w,
                child: GestureDetector(
                  onTap: () => Get.back(),
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: const BoxDecoration(
                      color: Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),

          // --- BODY CONTENT ---
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 10.h),
                  Text(
                    "4 invites left",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.w),
                    child: Text(
                      "Share invite codes with your friends and you will receive:",
                      textAlign: TextAlign.center,
                      style: sfProDisplay400(15.sp, const Color(0xFFB0B3B8)),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // --- Premium Badge with Linear Gradient ---
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFE6A7),Color(0xFFF2B269),],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF2B269).withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                          offset: const Offset(0, 0), // Centered glow
                        ),
                      ],
                    ),
                    child: Text(
                      "1 month free premium",
                      style: sfProDisplay400(15.sp, Colors.white)
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // --- Invite Codes List ---
                  // Use ShrinkWrap to work inside SingleChildScrollView
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    itemCount: inviteCodes.length,
                    separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final item = inviteCodes[index];
                      final bool isClaimed = item['isClaimed'];

                      return SizedBox(
                        height: 60.h,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['code'],
                              style: TextStyle(
                                color: isClaimed ? Colors.white24 : Colors.white,
                                fontSize: 17.sp,
                                fontFamily: 'SFProText',
                                fontWeight: FontWeight.w600,
                                decoration:
                                isClaimed ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            isClaimed
                                ? Text(
                              "Claimed",
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 14.sp,
                              ),
                            )
                                : IconButton(
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: item['code']));
                                Get.snackbar(
                                  "Copied",
                                  "Code copied to clipboard",
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: Colors.white10,
                                  colorText: Colors.white,
                                );
                              },
                              icon: Image.asset("assets/images/Group.png")
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}