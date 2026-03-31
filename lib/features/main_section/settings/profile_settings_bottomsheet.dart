import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/settings_controller.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/streak_controller.dart';
import 'package:second_chat/controllers/auth_controller.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/constants/app_images/app_images.dart';
import 'package:second_chat/core/localization/l10n.dart';
import 'package:second_chat/core/themes/textstyles.dart';

String? _pickString(Map<String, dynamic>? map, List<String> keys) {
  if (map == null) return null;
  for (final k in keys) {
    final v = map[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

bool _pickBool(Map<String, dynamic>? map, List<String> keys) {
  if (map == null) return false;
  for (final k in keys) {
    final v = map[k];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.toLowerCase().trim();
      if (t == 'true' || t == '1') return true;
    }
  }
  return false;
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

/// Read-only profile summary using existing [AuthController.me], settings payload
/// (account + connected platforms), and [StreamStreaksController] streak overview.
class ProfileSettingsBottomSheet extends StatefulWidget {
  const ProfileSettingsBottomSheet({super.key});

  @override
  State<ProfileSettingsBottomSheet> createState() =>
      _ProfileSettingsBottomSheetState();
}

class _ProfileSettingsBottomSheetState extends State<ProfileSettingsBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        Get.find<StreamStreaksController>().fetchCurrentStreak(silent: true),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final settings = Get.find<SettingsController>();
    final streakCtrl = Get.find<StreamStreaksController>();

    return Obx(() {
      streakCtrl.isLoading.value;
      streakCtrl.current.value;
      final me = auth.me.value;
      final username = _pickString(me, const ['username', 'userName']);
      final email = _pickString(me, const ['email']);
      final role = _pickString(me, const ['role']);
      final created = _parseDate(
        me?['created_at'] ?? me?['createdAt'],
      );
      final mePremium = _pickBool(me, const ['is_premium', 'isPremium']);

      final account =
          settings.settingsPayload.value?['account'] as Map<String, dynamic>?;
      final planFromSettings = (account?['yourPlan'] ?? '').toString().trim();
      final isPremiumAccount = account?['isPremium'] == true;
      final premiumLabel = isPremiumAccount || mePremium
          ? context.l10n.premium
          : (planFromSettings.isEmpty ? context.l10n.free : planFromSettings);

      final platformsRaw = settings.settingsPayload.value?['connectPlatforms'];
      final List<Map<String, dynamic>> platformRows = [];
      if (platformsRaw is List) {
        for (final e in platformsRaw) {
          if (e is Map) {
            platformRows.add(Map<String, dynamic>.from(e));
          }
        }
      }

      final displayName =
          (username != null && username.isNotEmpty) ? username : '—';
      final initial = displayName.isNotEmpty && displayName != '—'
          ? displayName[0].toUpperCase()
          : '?';

      final maxBody = MediaQuery.sizeOf(context).height * 0.62;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8.w, 10.h, 8.w, 6.h),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Get.back(),
                  child: Padding(
                    padding: EdgeInsets.all(8.w),
                    child: Image.asset(x_icon, height: 28.h),
                  ),
                ),
                Expanded(
                  child: Text(
                    context.l10n.settingsTitleProfile,
                    textAlign: TextAlign.center,
                    style: sfProText600(17.sp, Colors.white),
                  ),
                ),
                SizedBox(width: 44.w),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxBody),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 36.r,
                        backgroundColor: beige.withValues(alpha: 0.35),
                        child: Text(
                          initial,
                          style: sfProDisplay600(28.sp, Colors.white),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: sfProDisplay600(20.sp, Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (email != null && email.isNotEmpty) ...[
                              SizedBox(height: 4.h),
                              Text(
                                email,
                                style: sfProText400(
                                  14.sp,
                                  const Color.fromRGBO(235, 235, 245, 0.65),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  _SectionCard(
                    title: context.l10n.profileAccount,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kvRow(
                          context.l10n.yourPlan,
                          premiumLabel,
                        ),
                        if (role != null && role.isNotEmpty) ...[
                          SizedBox(height: 10.h),
                          _kvRow(context.l10n.profileRole, role),
                        ],
                        if (created != null) ...[
                          SizedBox(height: 10.h),
                          _kvRow(
                            context.l10n.profileMemberSince,
                            DateFormat.yMMMd().format(created.toLocal()),
                          ),
                        ],
                        if (username != null && username.isNotEmpty) ...[
                          SizedBox(height: 10.h),
                          _kvRow(context.l10n.profileUsername, username),
                        ],
                        if (email != null && email.isNotEmpty) ...[
                          SizedBox(height: 10.h),
                          _kvRow(context.l10n.profileEmail, email),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildStreakSection(
                    context,
                    streakCtrl.isLoading.value,
                    streakCtrl.current.value,
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: context.l10n.profilePlatforms,
                    child:
                        platformRows.isEmpty
                            ? Text(
                              context.l10n.profileNotConnected,
                              style: sfProText400(
                                14.sp,
                                const Color.fromRGBO(235, 235, 245, 0.6),
                              ),
                            )
                            : Column(
                              children: [
                                for (var i = 0; i < platformRows.length; i++) ...[
                                  if (i > 0) SizedBox(height: 10.h),
                                  _platformRow(context, platformRows[i]),
                                ],
                              ],
                            ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildStreakSection(
    BuildContext context,
    bool loading,
    StreakData? data,
  ) {
    return _SectionCard(
      title: context.l10n.profileStreamStreaks,
      child:
          loading && data == null
              ? Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Center(
                  child: SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: beige,
                    ),
                  ),
                ),
              )
              : data == null
              ? Text(
                context.l10n.profileStreakPlaceholder,
                style: sfProText400(
                  14.sp,
                  const Color.fromRGBO(235, 235, 245, 0.6),
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _statPill(
                          context.l10n.profileCurrentStreak,
                          '${data.currentStreak}',
                          context.l10n.dayStreak,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _statPill(
                          context.l10n.profileLongestStreak,
                          '${data.longestStreak}',
                          context.l10n.dayStreak,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _kvRow(
                    context.l10n.profileThisWeek,
                    context.l10n.profileWeekProgress(
                      data.completedThisWeek,
                      data.targetDaysPerWeek > 0
                          ? data.targetDaysPerWeek
                          : data.completedThisWeek,
                    ),
                  ),
                  if (data.freezeAllowancePerMonth > 0) ...[
                    SizedBox(height: 8.h),
                    _kvRow(
                      context.l10n.profileFreezeTokens,
                      '${data.freezeTokens}',
                    ),
                  ],
                  if (data.isInDanger) ...[
                    SizedBox(height: 10.h),
                    Text(
                      context.l10n.streakInDangerHitFreezeButton,
                      style: sfProText500(
                        13.sp,
                        const Color(0xFFFFB4A2),
                      ),
                    ),
                  ],
                ],
              ),
    );
  }

  Widget _kvRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: sfProText400(
              13.sp,
              const Color.fromRGBO(235, 235, 245, 0.55),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: sfProText500(14.sp, Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _statPill(String label, String value, String unit) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: onBottomSheetGrey,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color.fromRGBO(120, 120, 128, 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: sfProText400(
              12.sp,
              const Color.fromRGBO(235, 235, 245, 0.55),
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: sfProDisplay600(22.sp, Colors.white)),
              SizedBox(width: 4.w),
              Text(
                unit,
                style: sfProText400(
                  12.sp,
                  const Color.fromRGBO(235, 235, 245, 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _platformRow(BuildContext context, Map<String, dynamic> row) {
    final name = (row['platform'] ?? row['platformName'] ?? '')
        .toString()
        .trim();
    final display = name.isEmpty ? '—' : _titleCase(name);
    final connected = row['connected'] == true || row['is_active'] == true;
    final handle = _pickString(row, const ['username', 'platform_username']);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(display, style: sfProText500(15.sp, Colors.white)),
              if (handle != null && handle.isNotEmpty)
                Text(
                  '@$handle',
                  style: sfProText400(
                    12.sp,
                    const Color.fromRGBO(235, 235, 245, 0.5),
                  ),
                ),
            ],
          ),
        ),
        Text(
          connected ? context.l10n.connected : context.l10n.disconnected,
          style: sfProText500(
            13.sp,
            connected ? const Color(0xFF8ED99B) : const Color(0xFFB0B0B5),
          ),
        ),
      ],
    );
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: onBottomSheetGrey,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: sfProDisplay400(
              12.sp,
              const Color.fromRGBO(235, 235, 245, 0.55),
            ),
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}
