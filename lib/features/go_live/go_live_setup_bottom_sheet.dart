import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../controllers/platform_categories_controller.dart';
import '../../controllers/rtmp_broadcast_controller.dart';
import '../../core/constants/app_colors/app_colors.dart';
import '../../core/constants/app_images/app_images.dart';
import '../../core/themes/textstyles.dart';
import '../../core/widgets/custom_switch.dart';
import '../live_stream/widgets/stream_category_meta_row.dart';

Future<bool?> showGoLiveSetupBottomSheet(
  BuildContext context,
  RtmpBroadcastController broadcast,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GoLiveSetupBottomSheet(broadcast: broadcast),
  );
}

class GoLiveSetupBottomSheet extends StatefulWidget {
  const GoLiveSetupBottomSheet({super.key, required this.broadcast});

  final RtmpBroadcastController broadcast;

  @override
  State<GoLiveSetupBottomSheet> createState() => _GoLiveSetupBottomSheetState();
}

class _GoLiveSetupBottomSheetState extends State<GoLiveSetupBottomSheet> {
  final Map<BroadcastPlatform, bool> _enabled = {
    for (final p in BroadcastPlatform.values) p: false,
  };
  final Map<BroadcastPlatform, TextEditingController> _titleControllers = {};
  final Map<BroadcastPlatform, TextEditingController> _categoryControllers = {};
  final Map<BroadcastPlatform, ValueNotifier<bool>> _categoryMenuOpen = {};
  final Map<BroadcastPlatform, ValueNotifier<String?>> _selectedCategoryIds = {};
  final TextEditingController _kickStreamIdController = TextEditingController();

  bool _isSubmitting = false;
  String? _localError;
  bool _hasStoredKickStreamId = false;

  @override
  void initState() {
    super.initState();
    for (final platform in BroadcastPlatform.values) {
      _titleControllers[platform] = TextEditingController();
      _categoryControllers[platform] = TextEditingController();
      _categoryMenuOpen[platform] = ValueNotifier(false);
      _selectedCategoryIds[platform] = ValueNotifier(null);
    }

    _hasStoredKickStreamId = widget.broadcast.hasStoredKickStreamId;

    // Pre-select Twitch if it was previously selected.
    if (widget.broadcast.isPlatformSelected(BroadcastPlatform.twitch)) {
      _enabled[BroadcastPlatform.twitch] = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.broadcast.refreshKickManualState();
      if (!mounted) return;
      final stored = widget.broadcast.hasStoredKickStreamId;
      setState(() => _hasStoredKickStreamId = stored);
      final categoriesCtrl = Get.find<PlatformCategoriesController>();
      for (final platform in BroadcastPlatform.values) {
        unawaited(categoriesCtrl.ensureCategoriesFor(platform.key));
      }
    });
  }

  @override
  void dispose() {
    for (final c in _titleControllers.values) {
      c.dispose();
    }
    for (final c in _categoryControllers.values) {
      c.dispose();
    }
    for (final n in _categoryMenuOpen.values) {
      n.dispose();
    }
    for (final n in _selectedCategoryIds.values) {
      n.dispose();
    }
    _kickStreamIdController.dispose();
    super.dispose();
  }

  void _togglePlatform(BroadcastPlatform platform, bool value) {
    setState(() {
      _enabled[platform] = value;
      if (!value) {
        _categoryMenuOpen[platform]!.value = false;
      }
      _localError = null;
    });
  }

  void _toggleCategoryMenu(BroadcastPlatform platform) {
    final notifier = _categoryMenuOpen[platform]!;
    notifier.value = !notifier.value;
  }

  void _onCategoryPicked(BroadcastPlatform platform, String name, String id) {
    _categoryControllers[platform]!.text = name;
    _selectedCategoryIds[platform]!.value = id;
    _categoryMenuOpen[platform]!.value = false;
    setState(() => _localError = null);
  }

  Map<BroadcastPlatform, GoLivePlatformSetup> _buildSetup() {
    final setup = <BroadcastPlatform, GoLivePlatformSetup>{};
    for (final platform in BroadcastPlatform.values) {
      if (_enabled[platform] != true) continue;
      setup[platform] = GoLivePlatformSetup(
        title: _titleControllers[platform]!.text.trim(),
        category: _categoryControllers[platform]!.text.trim(),
        categoryId: _selectedCategoryIds[platform]!.value,
        kickStreamId: platform == BroadcastPlatform.kick
            ? _kickStreamIdController.text.trim()
            : null,
      );
    }
    return setup;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _localError = null;
    });

    final setup = _buildSetup();
    final ok = await widget.broadcast.submitGoLiveSetup(setup);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _localError = widget.broadcast.errorMessage.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: onBottomSheetGrey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          border: Border.all(
            color: const Color(0xFF38383A),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Stream setup',
                      style: sfProDisplay600(20.sp, Colors.white),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: Colors.white70, size: 22.sp),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                child: Column(
                  children: [
                    for (final platform in BroadcastPlatform.values)
                      _PlatformSetupTile(
                        platform: platform,
                        enabled: _enabled[platform] ?? false,
                        titleController: _titleControllers[platform]!,
                        categoryController: _categoryControllers[platform]!,
                        categoryMenuOpen: _categoryMenuOpen[platform]!,
                        selectedCategoryId: _selectedCategoryIds[platform]!,
                        showKickStreamIdField: platform == BroadcastPlatform.kick &&
                            !_hasStoredKickStreamId,
                        kickStreamIdController: _kickStreamIdController,
                        onToggle: (v) => _togglePlatform(platform, v),
                        onToggleCategoryMenu: () => _toggleCategoryMenu(platform),
                        onCategoryPicked: (name, id) =>
                            _onCategoryPicked(platform, name, id),
                      ),
                  ],
                ),
              ),
            ),
            if (_localError != null && _localError!.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
                child: Text(
                  _localError!,
                  textAlign: TextAlign.center,
                  style: sfProText400(13.sp, const Color(0xFFFF8A80)),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
              child: GestureDetector(
                onTap: _isSubmitting ? null : _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 52.h,
                  decoration: BoxDecoration(
                    gradient: goldGradient,
                    borderRadius: BorderRadius.circular(28.r),
                    boxShadow: [
                      BoxShadow(
                        color: beige.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _isSubmitting
                      ? SizedBox(
                          width: 22.w,
                          height: 22.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          'Start Stream',
                          style: sfProText700(16.sp, Colors.black),
                        ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }
}

class _PlatformSetupTile extends StatelessWidget {
  const _PlatformSetupTile({
    required this.platform,
    required this.enabled,
    required this.titleController,
    required this.categoryController,
    required this.categoryMenuOpen,
    required this.selectedCategoryId,
    required this.showKickStreamIdField,
    required this.kickStreamIdController,
    required this.onToggle,
    required this.onToggleCategoryMenu,
    required this.onCategoryPicked,
  });

  final BroadcastPlatform platform;
  final bool enabled;
  final TextEditingController titleController;
  final TextEditingController categoryController;
  final ValueNotifier<bool> categoryMenuOpen;
  final ValueNotifier<String?> selectedCategoryId;
  final bool showKickStreamIdField;
  final TextEditingController kickStreamIdController;
  final ValueChanged<bool> onToggle;
  final VoidCallback onToggleCategoryMenu;
  final void Function(String name, String id) onCategoryPicked;

  Color get _accent {
    switch (platform) {
      case BroadcastPlatform.twitch:
        return twitchPurple;
      case BroadcastPlatform.kick:
        return kickGreen;
      case BroadcastPlatform.youtube:
        return youtubeRed;
    }
  }

  String get _iconAsset {
    switch (platform) {
      case BroadcastPlatform.twitch:
        return twitch_icon;
      case BroadcastPlatform.kick:
        return kick;
      case BroadcastPlatform.youtube:
        return 'assets/images/youtube1.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: enabled
              ? _accent.withValues(alpha: 0.1)
              : const Color.fromRGBO(47, 46, 51, 1),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: enabled ? _accent.withValues(alpha: 0.55) : const Color(0xFF38383A),
            width: enabled ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Image.asset(_iconAsset, width: 28.w, height: 28.w),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    platform.label,
                    style: sfProText600(16.sp, Colors.white),
                  ),
                ),
                CustomSwitch(
                  value: enabled,
                  onChanged: onToggle,
                  activeColor: _accent,
                ),
              ],
            ),
            if (enabled) ...[
              SizedBox(height: 14.h),
              _SetupField(
                label: 'Title',
                controller: titleController,
                hint: 'Stream title',
              ),
              SizedBox(height: 10.h),
              StreamCategoryMetaRow(
                isEditing: true,
                displayLabel: 'Category',
                categoryController: categoryController,
                menuOpen: categoryMenuOpen,
                onMenuToggle: onToggleCategoryMenu,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: categoryMenuOpen,
                builder: (context, open, _) {
                  if (!open) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: SizedBox(
                      height: StreamCategoryMetaRow.dropdownMaxHeight.h,
                      child: StreamCategoryDropdownPanel(
                        platformKey: platform.key,
                        selectedCategoryId: selectedCategoryId,
                        onPick: onCategoryPicked,
                      ),
                    ),
                  );
                },
              ),
              if (showKickStreamIdField) ...[
                SizedBox(height: 10.h),
                _SetupField(
                  label: 'Stream ID',
                  controller: kickStreamIdController,
                  hint: 'One-time Kick stream ID',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupField extends StatelessWidget {
  const _SetupField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: sfProText500(12.sp, Colors.white.withValues(alpha: 0.55)),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          style: sfProText400(14.sp, Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: sfProText400(14.sp, Colors.white38),
            filled: true,
            fillColor: greyy,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28.r),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28.r),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
