import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_chat/core/themes/textstyles.dart';

import '../../api/config/api_config.dart';
import '../../core/constants/app_colors/app_colors.dart';
import '../../core/localization/l10n.dart';

class InviteBottomSheet extends StatelessWidget {
  const InviteBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(InviteController());
    ctrl.loadInvitesIfNeeded();

    return Container(
      height: Get.height * 0.85,
      decoration:  BoxDecoration(
        color: bottomSheetGrey,
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
                left: 30.h,
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
                child: Obx(() {
                  final title =
                      ctrl.invitePayload.value?['title']?.toString() ??
                      context.l10n.invites;
                  return Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }),
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
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Column(
                children: [
                  SizedBox(height: 10.h),
                  Obx(() {
                    final data = ctrl.invitePayload.value ?? {};
                    final invitesLeft = data['invitesLeft'] ?? data['invites_left'];
                    final maxInvites = data['maxInvites'] ?? data['max_invites'];
                    final leftText = invitesLeft != null && maxInvites != null
                        ? context.l10n.invitesLeft(invitesLeft)
                        : context.l10n.invites;
                    return Text(
                      leftText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }),
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.w),
                    child: Obx(() {
                      final text = ctrl.invitePayload.value?['rewardTitle']
                              ?.toString() ??
                          context.l10n.shareInviteCodesReward;
                      return Text(
                        text,
                        textAlign: TextAlign.center,
                        style: sfProDisplay400(15.sp, const Color(0xFFB0B3B8)),
                      );
                    }),
                  ),
                  SizedBox(height: 16.h),

                  // --- Premium Badge with Linear Gradient ---
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color.fromRGBO(255, 230, 167, 0.7),
                          Color.fromRGBO(242, 178, 105, 1),                        ],
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
                    child: Obx(() {
                      final reward =
                          ctrl.invitePayload.value?['reward']?.toString() ??
                              context.l10n.oneMonthFreePremium;
                      return Text(
                        reward,
                        style: sfProDisplay400(15.sp, Colors.white),
                      );
                    }),
                  ),
                  SizedBox(height: 20.h),

                  // --- Invite Codes List ---
                  // Use ShrinkWrap to work inside SingleChildScrollView
                  Obx(() {
                    if (ctrl.isLoading.value &&
                        ctrl.invitePayload.value == null) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      );
                    }

                    final data = ctrl.invitePayload.value ?? {};
                    final invites = data['invites'];
                    final inviteList = invites is List
                        ? invites.whereType<Map>().map((e) {
                            final code = e['code']?.toString() ?? '';
                            final claimed = e['claimed'] == true;
                            return {'code': code, 'claimed': claimed};
                          }).toList()
                        : <Map<String, dynamic>>[];

                    if (inviteList.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Text(
                          context.l10n.noInvitesAvailableRightNow,
                          style: sfProDisplay400(14.sp, Colors.white54),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      itemCount: inviteList.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final item = inviteList[index];
                        final bool isClaimed = item['claimed'] == true;

                        return SizedBox(
                          height: 60.h,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item['code'],
                                style: TextStyle(
                                  color:
                                      isClaimed ? Colors.white24 : Colors.white,
                                  fontSize: 17.sp,
                                  fontFamily: 'SFProText',
                                  fontWeight: FontWeight.w600,
                                  decoration: isClaimed
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor:
                                      Colors.white24, // 🔴 underline / line color
                                ),
                              ),

                              isClaimed
                                  ? Text(
                                      context.l10n.claimed,
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
                                          context.l10n.copied,
                                          context.l10n.codeCopiedToClipboard,
                                          snackPosition: SnackPosition.BOTTOM,
                                          backgroundColor: Colors.white10,
                                          colorText: Colors.white,
                                        );
                                      },
                                      icon: Image.asset("assets/images/Group.png"),
                                    ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
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

class InviteController extends GetxController {
  final Rxn<Map<String, dynamic>> invitePayload = Rxn<Map<String, dynamic>>();
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();
  bool _requested = false;

  void loadInvitesIfNeeded() {
    if (_requested) return;
    _requested = true;
    loadInvites();
  }

  Future<void> loadInvites() async {
    try {
      isLoading.value = true;
      error.value = null;
      final token = await _readAccessToken();
      if (token == null) {
        error.value = 'Missing access token';
        print('INVITES ERROR: Missing access token in SharedPreferences');
        return;
      }
      final dio = _buildDio();
      final res = await dio.get<dynamic>(
        '/api/v1/subscriptions/referral/invites',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      final data = res.data;
      print('INVITES RESPONSE RAW: $data');
      if (data is Map && data['data'] is Map) {
        invitePayload.value = Map<String, dynamic>.from(data['data'] as Map);
      } else {
        error.value = 'Unexpected response format';
      }
    } catch (e) {
      error.value = 'Failed to load invites';
      print('INVITES ERROR: $e');
      if (e is DioException) {
        print('INVITES ERROR RESPONSE: ${e.response?.data}');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  Future<String?> _readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('second_chat.access_token')?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }
}
