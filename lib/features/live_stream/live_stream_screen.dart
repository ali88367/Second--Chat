import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/themes/textstyles.dart';
import '../../../controllers/Main Section Controllers/settings_controller.dart';
import '../../core/constants/app_colors/app_colors.dart';
import '../Invite/Invite_screen.dart';
import '../main_section/settings/settings_bottomsheet_column.dart';
import 'widgets/chat_bottom_section.dart';
import 'widgets/live_stream_helper_widgets.dart';

class Livestreaming extends StatefulWidget {
  const Livestreaming({super.key});

  @override
  State<Livestreaming> createState() => _LivestreamingState();
}

class _LivestreamingState extends State<Livestreaming> {
  final ValueNotifier<bool> _showServiceCard = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _selectedPlatform = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _showActivity = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _titleSelected = ValueNotifier<bool>(false);

  final ValueNotifier<String> _topBarImage = ValueNotifier<String>(
    'assets/images/topbarshade.png',
  );

  final ValueNotifier<String?> _chatFilter = ValueNotifier<String?>(null);

  final ValueNotifier<int> _currentStreamingIndex = ValueNotifier<int>(0);

  // Resizable bottom section state
  double _bottomSectionHeight = 0;
  double _initialHeight = 0;
  bool _isInitialHeightSet = false;
  static const double _dragSensitivity = 1.8;

  // ── Activity section state ──────────────────────────────────────────
  double _activityHeight = 0;
  bool _isDraggingActivity = false;
  static const double _activityMinHeight = 0.3;
  static const double _activityMaxHeight = 0.65;
  final ScrollController _activityScrollController = ScrollController();

  final List<String> _streamingImages = [
    'assets/images/streaming.png',
    'assets/images/streaming2.png',
    'assets/images/streaming3.png',
    'assets/images/streaming4.png',
  ];

  late final SettingsController _settingsCtrl;

  @override
  void initState() {
    super.initState();
    _settingsCtrl = Get.find<SettingsController>();
    _chatFilter.addListener(_updateImageBasedOnFilter);
  }

  void _updateImageBasedOnFilter() {
    switch (_chatFilter.value) {
      case 'twitch':
        _topBarImage.value = 'assets/images/twitchshade.png';
        break;
      case 'kick':
        _topBarImage.value = 'assets/images/youtubeshade.png';
        break;
      case 'youtube':
        _topBarImage.value = 'assets/images/kickshade.png';
        break;
      default:
        _topBarImage.value = 'assets/images/topbarshade.png';
        break;
    }
  }

  @override
  void dispose() {
    _chatFilter.removeListener(_updateImageBasedOnFilter);
    _showServiceCard.dispose();
    _selectedPlatform.dispose();
    _showActivity.dispose();
    _titleSelected.dispose();
    _topBarImage.dispose();
    _chatFilter.dispose();
    _currentStreamingIndex.dispose();
    _activityScrollController.dispose();
    super.dispose();
  }

  void _handleFilterTap(String platformKey) {
    if (_chatFilter.value == platformKey) {
      _chatFilter.value = null;
    } else {
      _chatFilter.value = platformKey;
    }
  }

  void _handlePlatformSwipe(bool swipeRight) {
    const platforms = [null, 'twitch', 'kick', 'youtube'];
    final currentIndex = platforms.indexOf(_chatFilter.value);

    if (swipeRight) {
      final nextIndex = (currentIndex + 1) % platforms.length;
      _chatFilter.value = platforms[nextIndex];
    } else {
      final prevIndex =
          (currentIndex - 1 + platforms.length) % platforms.length;
      _chatFilter.value = platforms[prevIndex];
    }
  }

  Widget _buildInteractiveCounterRow() {
    return Obx(() {
      if (!_settingsCtrl.viewerCount.value) {
        return const SizedBox.shrink();
      }

      return Container(
        width: 297.w,
        height: 59.4.h,
        decoration: BoxDecoration(
          color: black,
          borderRadius: BorderRadius.circular(33.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _handleFilterTap('twitch'),
              child: Obx(() {
                final color = _settingsCtrl.getPlatformColor('twitch');
                return counterPill(
                  asset: 'assets/images/twitch.png',
                  count: '11202',
                  color: color,
                  bgColor: color.withOpacity(0.25),
                );
              }),
            ),
            SizedBox(width: 13.2.w),
            GestureDetector(
              onTap: () => _handleFilterTap('kick'),
              child: Obx(() {
                final color = _settingsCtrl.getPlatformColor('kick');
                return counterPill(
                  asset: 'assets/images/kick.png',
                  count: '1256',
                  color: color,
                  bgColor: color.withOpacity(0.25),
                );
              }),
            ),
            SizedBox(width: 13.2.w),
            GestureDetector(
              onTap: () => _handleFilterTap('youtube'),
              child: Obx(() {
                final color = _settingsCtrl.getPlatformColor('youtube');
                return counterPill(
                  asset: 'assets/images/youtube.png',
                  count: '256',
                  color: color,
                  bgColor: color.withOpacity(0.25),
                );
              }),
            ),
          ],
        ),
      );
    });
  }

  // ── Resizable activity container ────────────────────────────────────
  static const double _activityDragSensitivity = 1.5;

  Widget _buildResizableActivityContainer(BuildContext context) {
    final double screenHeight = Get.height;
    final double originalHeight = screenHeight * _activityMinHeight;
    final double maxHeight = screenHeight * _activityMaxHeight;

    if (_activityHeight == 0) {
      _activityHeight = originalHeight;
    }

    final double clampedHeight = _activityHeight.clamp(
      originalHeight,
      maxHeight,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveMax =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight.clamp(originalHeight, maxHeight)
                : maxHeight;
        final height = clampedHeight.clamp(originalHeight, effectiveMax);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (_) {
            setState(() {
              _isDraggingActivity = true;
            });
          },
          onVerticalDragUpdate: (details) {
            final delta = details.delta.dy * _activityDragSensitivity;
            if (delta < 0 && _activityHeight <= originalHeight) {
              return;
            }
            setState(() {
              _activityHeight = (_activityHeight + delta).clamp(
                originalHeight,
                effectiveMax,
              );
            });
          },
          onVerticalDragEnd: (_) {
            setState(() {
              _isDraggingActivity = false;
            });
          },
          onVerticalDragCancel: () {
            setState(() {
              _isDraggingActivity = false;
            });
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: _isDraggingActivity ? 0 : 250),
            curve: Curves.easeOut,
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(22, 21, 24, 1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Stack(
              children: [
                // ─── Scrollable activity rows ───────────────────────
                Positioned.fill(
                  bottom: 12.h,
                  child: ScrollbarTheme(
                    data: ScrollbarThemeData(
                      thumbColor: MaterialStateProperty.all(
                        Colors.grey.shade500,
                      ),
                    ),
                    child: Scrollbar(
                      controller: _activityScrollController,
                      thumbVisibility: true,
                      thickness: 3.w,
                      radius: Radius.circular(8.r),
                      scrollbarOrientation: ScrollbarOrientation.right,
                      child: SingleChildScrollView(
                        controller: _activityScrollController,
                        padding: EdgeInsets.only(
                          left: 12.w,
                          right: 12.w,
                          top: 12.h,
                        ),
                        physics:
                            _isDraggingActivity
                                ? const NeverScrollableScrollPhysics()
                                : const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            activityRow(
                              'assets/images/kick.png',
                              'New Follower',
                              '19:41',
                              '',
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/kick.png',
                              'New Follower',
                              '22:41',
                              '',
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/kick.png',
                              'Mega Supporter',
                              '19:49',
                              '\$50',
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/youtube1.png',
                              'Fun',
                              '19:49',
                              'Subscribed',
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/youtube1.png',
                              'Fun',
                              '19:49',
                              'Subscribed',
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/twitch1.png',
                              'Ranen',
                              '19:49',
                              'Subscribed',
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/kick.png',
                              'New Follower',
                              '20:15',
                              '',
                            ),
                            SizedBox(height: 12.h),
                            activityRow(
                              'assets/images/twitch1.png',
                              'SuperFan',
                              '20:30',
                              '\$100',
                            ),
                            SizedBox(height: 12.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Stack(
            children: [
              // ── Top bar shade image ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 230.h,
                child: ClipRect(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _topBarImage,
                    builder: (context, imagePath, child) {
                      return ValueListenableBuilder<String?>(
                        valueListenable: _chatFilter,
                        builder: (context, filter, _) {
                          if (filter == null) {
                            return Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              key: ValueKey(imagePath),
                            );
                          }

                          return Obx(() {
                            Color filterColor;
                            if (filter == 'twitch') {
                              filterColor =
                                  _settingsCtrl.twitchColor.value ??
                                  twitchPurple;
                            } else if (filter == 'kick') {
                              filterColor =
                                  _settingsCtrl.kickColor.value ?? kickGreen;
                            } else if (filter == 'youtube') {
                              filterColor =
                                  _settingsCtrl.youtubeColor.value ??
                                  youtubeRed;
                            } else {
                              filterColor = Colors.transparent;
                            }

                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  imagePath,
                                  fit: BoxFit.cover,
                                  key: ValueKey(imagePath),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        filterColor.withOpacity(0.8),
                                        filterColor.withOpacity(0.0),
                                      ],
                                      stops: const [0.0, 1.0],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          });
                        },
                      );
                    },
                  ),
                ),
              ),

              // ── Full-screen gradient overlay ──
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x661A1A1A), Color(0xFF0A0A0A)],
                    ),
                  ),
                ),
              ),

              // ── Top bar buttons ──
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 28.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      buildImageButton(
                        'assets/images/streak_icon.png',
                        width: 72.w,
                        height: 36.w,
                      ),
                      Row(
                        children: [
                          SizedBox(width: 6.w),
                          GestureDetector(
                            onTap: () {
                              Get.bottomSheet(
                                Container(
                                  height: Get.height * .9,
                                  decoration: BoxDecoration(
                                    color: bottomSheetGrey,
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(18.r),
                                      topLeft: Radius.circular(18.r),
                                    ),
                                  ),
                                  child: InviteBottomSheet(),
                                ),
                                isDismissible: true,
                                isScrollControlled: true,
                                enableDrag: true,
                                enterBottomSheetDuration: const Duration(
                                  milliseconds: 300,
                                ),
                                exitBottomSheetDuration: const Duration(
                                  milliseconds: 250,
                                ),
                              );
                            },
                            child: buildImageButton(
                              'assets/images/gift.png',
                              width: 36.w,
                              height: 36.w,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          GestureDetector(
                            onTap: () {
                              Get.bottomSheet(
                                Container(
                                  height: Get.height * .9,
                                  decoration: BoxDecoration(
                                    color: bottomSheetGrey,
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(18.r),
                                      topLeft: Radius.circular(18.r),
                                    ),
                                  ),
                                  child: SettingsBottomsheetColumn(),
                                ),
                                isDismissible: true,
                                isScrollControlled: true,
                                enableDrag: true,
                                enterBottomSheetDuration: const Duration(
                                  milliseconds: 300,
                                ),
                                exitBottomSheetDuration: const Duration(
                                  milliseconds: 250,
                                ),
                              );
                            },
                            child: buildImageButton(
                              'assets/images/settings.png',
                              width: 36.w,
                              height: 36.w,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Main content area ──
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (!_isInitialHeightSet) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            final screenHeight = Get.height;
                            final topPadding = 122.h;
                            final spacing = 12.h;
                            final bottomPadding =
                                16.h +
                                MediaQuery.of(context).viewPadding.bottom;
                            final upperSectionHeight = 236.h + spacing;
                            final counterRowHeight = 59.4.h + 24.h;
                            final availableHeight =
                                screenHeight - topPadding - bottomPadding;
                            final calculatedHeight =
                                availableHeight -
                                upperSectionHeight -
                                spacing -
                                counterRowHeight;
                            final initialBottomHeight = calculatedHeight * 1.4;
                            setState(() {
                              _initialHeight =
                                  initialBottomHeight > 200.h
                                      ? initialBottomHeight
                                      : 200.h;
                              _bottomSectionHeight = _initialHeight;
                              _isInitialHeightSet = true;
                            });
                          }
                        });
                      }

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 117.h),

                          // ── Upper section ──
                          Flexible(
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _showActivity,
                              builder: (context, showActivity, _) {
                                if (showActivity) {
                                  return _buildResizableActivityContainer(
                                    context,
                                  );
                                }
                                return SingleChildScrollView(
                                  physics:
                                      _isDraggingActivity
                                          ? const NeverScrollableScrollPhysics()
                                          : const ClampingScrollPhysics(),
                                  padding: EdgeInsets.only(
                                    bottom:
                                        MediaQuery.of(
                                          context,
                                        ).viewPadding.bottom,
                                  ),
                                  child: ValueListenableBuilder<bool>(
                                    valueListenable: _showServiceCard,
                                    builder: (context, showCard, child) {
                                      if (!showCard) {
                                        return Column(
                                          children: [
                                            ValueListenableBuilder<int>(
                                              valueListenable:
                                                  _currentStreamingIndex,
                                              builder: (
                                                context,
                                                currentIndex,
                                                _,
                                              ) {
                                                return GestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onVerticalDragStart: (_) {},
                                                  onVerticalDragUpdate: (_) {},
                                                  onVerticalDragEnd: (_) {},
                                                  child: Stack(
                                                    children: [
                                                      CarouselSlider(
                                                        options: CarouselOptions(
                                                          height: 226.h,
                                                          viewportFraction: 1.0,
                                                          enableInfiniteScroll:
                                                              false,
                                                          enlargeCenterPage:
                                                              false,
                                                          onPageChanged: (
                                                            index,
                                                            reason,
                                                          ) {
                                                            _currentStreamingIndex
                                                                .value = index;
                                                          },
                                                        ),
                                                        items:
                                                            _streamingImages.map((
                                                              imagePath,
                                                            ) {
                                                              return Builder(
                                                                builder: (
                                                                  BuildContext
                                                                  context,
                                                                ) {
                                                                  return Container(
                                                                    width:
                                                                        MediaQuery.of(
                                                                          context,
                                                                        ).size.width,
                                                                    margin: EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          5.w,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            24.r,
                                                                          ),
                                                                    ),
                                                                    child: ClipRRect(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            24.r,
                                                                          ),
                                                                      child: Image.asset(
                                                                        imagePath,
                                                                        fit:
                                                                            BoxFit.cover,
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                              );
                                                            }).toList(),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        );
                                      }

                                      return ValueListenableBuilder<bool>(
                                        valueListenable: _titleSelected,
                                        builder: (context, titleSelected, _) {
                                          if (titleSelected) {
                                            return ValueListenableBuilder<
                                              String?
                                            >(
                                              valueListenable:
                                                  _selectedPlatform,
                                              builder: (context, platform, _) {
                                                if (platform != null) {
                                                  final asset =
                                                      platform == 'twitch'
                                                          ? 'assets/images/twitch1.png'
                                                          : platform == 'kick'
                                                          ? 'assets/images/kick.png'
                                                          : 'assets/images/youtube1.png';

                                                  return Column(
                                                    children: [
                                                      Container(
                                                        width: double.infinity,
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 12.w,
                                                              vertical: 12.h,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: black,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20.r,
                                                              ),
                                                        ),
                                                        child: Column(
                                                          children: [
                                                            Padding(
                                                              padding:
                                                                  EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        8.w,
                                                                  ),
                                                              child: Row(
                                                                children: [
                                                                  GestureDetector(
                                                                    onTap: () {
                                                                      _selectedPlatform
                                                                              .value =
                                                                          null;
                                                                      _showServiceCard
                                                                              .value =
                                                                          false;
                                                                      _titleSelected
                                                                              .value =
                                                                          false;
                                                                      _showActivity
                                                                              .value =
                                                                          false;
                                                                      _activityHeight =
                                                                          0;
                                                                      _isDraggingActivity =
                                                                          false;
                                                                    },
                                                                    child: Container(
                                                                      padding:
                                                                          EdgeInsets.all(
                                                                            8.w,
                                                                          ),
                                                                      decoration: BoxDecoration(
                                                                        color:
                                                                            Colors.grey.shade900,
                                                                        shape:
                                                                            BoxShape.circle,
                                                                      ),
                                                                      child: Transform.translate(
                                                                        offset:
                                                                            const Offset(
                                                                              2,
                                                                              0,
                                                                            ),
                                                                        child: Icon(
                                                                          Icons
                                                                              .arrow_back_ios,
                                                                          color:
                                                                              Colors.white,
                                                                          size:
                                                                              16.sp,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const Spacer(),
                                                                  Center(
                                                                    child: Image.asset(
                                                                      asset,
                                                                      width:
                                                                          22.w,
                                                                      height:
                                                                          22.h,
                                                                    ),
                                                                  ),
                                                                  const Spacer(),
                                                                  SizedBox(
                                                                    width: 40.w,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              height: 16.h,
                                                            ),
                                                            panelRow(
                                                              'Title Example',
                                                            ),
                                                            SizedBox(
                                                              height: 12.h,
                                                            ),
                                                            panelRow(
                                                              'Name Category',
                                                              showChevron: true,
                                                              onTap: () {
                                                                showModalBottomSheet(
                                                                  context:
                                                                      context,
                                                                  isScrollControlled:
                                                                      true,
                                                                  backgroundColor:
                                                                      Colors
                                                                          .transparent,
                                                                  builder: (
                                                                    ctx,
                                                                  ) {
                                                                    return Padding(
                                                                      padding: EdgeInsets.only(
                                                                        bottom:
                                                                            MediaQuery.of(
                                                                              ctx,
                                                                            ).viewInsets.bottom,
                                                                      ),
                                                                      child: FractionallySizedBox(
                                                                        heightFactor:
                                                                            0.8,
                                                                        child: AnimatedPadding(
                                                                          padding: EdgeInsets.only(
                                                                            bottom:
                                                                                MediaQuery.of(
                                                                                  ctx,
                                                                                ).viewInsets.bottom,
                                                                          ),
                                                                          duration: const Duration(
                                                                            milliseconds:
                                                                                250,
                                                                          ),
                                                                          curve:
                                                                              Curves.easeOut,
                                                                          child: Container(
                                                                            decoration: BoxDecoration(
                                                                              color: const Color.fromRGBO(
                                                                                20,
                                                                                18,
                                                                                18,
                                                                                1,
                                                                              ),
                                                                              borderRadius: const BorderRadius.vertical(
                                                                                top: Radius.circular(
                                                                                  38,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            child: Stack(
                                                                              children: [
                                                                                Column(
                                                                                  children: [
                                                                                    SizedBox(
                                                                                      height:
                                                                                          10.h,
                                                                                    ),
                                                                                    Padding(
                                                                                      padding: EdgeInsets.symmetric(
                                                                                        horizontal:
                                                                                            18.w,
                                                                                        vertical:
                                                                                            10,
                                                                                      ),
                                                                                      child: Row(
                                                                                        children: [
                                                                                          GestureDetector(
                                                                                            onTap:
                                                                                                () =>
                                                                                                    Navigator.of(
                                                                                                      ctx,
                                                                                                    ).pop(),
                                                                                            child: Container(
                                                                                              padding: EdgeInsets.all(
                                                                                                8.w,
                                                                                              ),
                                                                                              decoration: const BoxDecoration(
                                                                                                color: Color.fromRGBO(
                                                                                                  120,
                                                                                                  120,
                                                                                                  128,
                                                                                                  0.16,
                                                                                                ),
                                                                                                shape:
                                                                                                    BoxShape.circle,
                                                                                              ),
                                                                                              child: Center(
                                                                                                child: Transform.translate(
                                                                                                  offset: const Offset(
                                                                                                    2.5,
                                                                                                    0,
                                                                                                  ),
                                                                                                  child: Icon(
                                                                                                    Icons.arrow_back_ios,
                                                                                                    color:
                                                                                                        Colors.white,
                                                                                                    size:
                                                                                                        18,
                                                                                                  ),
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                          const Spacer(),
                                                                                          Text(
                                                                                            'Category',
                                                                                            style: sfProText600(
                                                                                              18.sp,
                                                                                              Colors.white,
                                                                                            ),
                                                                                          ),
                                                                                          const Spacer(),
                                                                                          SizedBox(
                                                                                            width:
                                                                                                40.w,
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                    ),
                                                                                    SizedBox(
                                                                                      height:
                                                                                          12.h,
                                                                                    ),
                                                                                    Expanded(
                                                                                      child: ListView.separated(
                                                                                        padding: EdgeInsets.only(
                                                                                          left:
                                                                                              16.w,
                                                                                          right:
                                                                                              16.w,
                                                                                          top:
                                                                                              8.h,
                                                                                          bottom:
                                                                                              100.h,
                                                                                        ),
                                                                                        itemCount:
                                                                                            3,
                                                                                        separatorBuilder:
                                                                                            (
                                                                                              _,
                                                                                              __,
                                                                                            ) => SizedBox(
                                                                                              height:
                                                                                                  12.h,
                                                                                            ),
                                                                                        itemBuilder: (
                                                                                          c,
                                                                                          i,
                                                                                        ) {
                                                                                          return InkWell(
                                                                                            onTap:
                                                                                                () {},
                                                                                            borderRadius: BorderRadius.circular(
                                                                                              32.r,
                                                                                            ),
                                                                                            child: Container(
                                                                                              padding: EdgeInsets.symmetric(
                                                                                                horizontal:
                                                                                                    20.w,
                                                                                                vertical:
                                                                                                    13.h,
                                                                                              ),
                                                                                              decoration: BoxDecoration(
                                                                                                color: const Color.fromRGBO(
                                                                                                  37,
                                                                                                  37,
                                                                                                  37,
                                                                                                  1,
                                                                                                ),
                                                                                                borderRadius: BorderRadius.circular(
                                                                                                  28.r,
                                                                                                ),
                                                                                              ),
                                                                                              child: Row(
                                                                                                children: [
                                                                                                  Text(
                                                                                                    'Name Category',
                                                                                                    style: sfProText400(
                                                                                                      13.sp,
                                                                                                      Colors.white,
                                                                                                    ),
                                                                                                  ),
                                                                                                  const Spacer(),
                                                                                                  Container(
                                                                                                    width:
                                                                                                        25.w,
                                                                                                    height:
                                                                                                        25.w,
                                                                                                    decoration: BoxDecoration(
                                                                                                      color:
                                                                                                          Colors.grey.shade900,
                                                                                                      borderRadius: BorderRadius.circular(
                                                                                                        18.r,
                                                                                                      ),
                                                                                                    ),
                                                                                                    child: Icon(
                                                                                                      Icons.arrow_forward_ios,
                                                                                                      color:
                                                                                                          Colors.grey.shade500,
                                                                                                      size:
                                                                                                          10.sp,
                                                                                                    ),
                                                                                                  ),
                                                                                                ],
                                                                                              ),
                                                                                            ),
                                                                                          );
                                                                                        },
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                                Positioned(
                                                                                  bottom:
                                                                                      18.h,
                                                                                  left:
                                                                                      74.w,
                                                                                  right:
                                                                                      74.w,
                                                                                  child: Container(
                                                                                    height:
                                                                                        56.h,
                                                                                    padding: EdgeInsets.symmetric(
                                                                                      horizontal:
                                                                                          16.w,
                                                                                    ),
                                                                                    decoration: BoxDecoration(
                                                                                      color:
                                                                                          Colors.black,
                                                                                      borderRadius: BorderRadius.circular(
                                                                                        28.r,
                                                                                      ),
                                                                                    ),
                                                                                    child: Row(
                                                                                      children: [
                                                                                        Icon(
                                                                                          Icons.search,
                                                                                          color:
                                                                                              Colors.white,
                                                                                          size:
                                                                                              22.sp,
                                                                                        ),
                                                                                        SizedBox(
                                                                                          width:
                                                                                              12.w,
                                                                                        ),
                                                                                        Expanded(
                                                                                          child: Text(
                                                                                            'Search',
                                                                                            style: sfProText400(
                                                                                              18.sp,
                                                                                              Colors.white.withOpacity(
                                                                                                0.6,
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                        ),
                                                                                        SizedBox(
                                                                                          width:
                                                                                              8.w,
                                                                                        ),
                                                                                        Icon(
                                                                                          Icons.mic,
                                                                                          color:
                                                                                              Colors.white,
                                                                                          size:
                                                                                              22.sp,
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                );
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }

                                                return Column(
                                                  children: [
                                                    Stack(
                                                      alignment:
                                                          Alignment.center,
                                                      children: [
                                                        Container(
                                                          width:
                                                              double.infinity,
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal:
                                                                    14.w,
                                                                vertical: 14.h,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: black,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  20.r,
                                                                ),
                                                          ),
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              serviceRow(
                                                                asset:
                                                                    'assets/images/youtube1.png',
                                                                title: 'Title',
                                                                subtitle:
                                                                    'Category',
                                                                onTap: () {
                                                                  _selectedPlatform
                                                                          .value =
                                                                      'youtube';
                                                                  _titleSelected
                                                                          .value =
                                                                      true;
                                                                  _showServiceCard
                                                                          .value =
                                                                      true;
                                                                },
                                                              ),
                                                              SizedBox(
                                                                height: 36.h,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Positioned(
                                                          bottom: 6.h,
                                                          child: Container(
                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      20.w,
                                                                  vertical: 8.h,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  const Color.fromRGBO(
                                                                    20,
                                                                    18,
                                                                    20,
                                                                    1,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    20.r,
                                                                  ),
                                                              border: Border.all(
                                                                color:
                                                                    Colors
                                                                        .white10,
                                                                width: 1.w,
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'Update All',
                                                              style: sfProText400(
                                                                14.sp,
                                                                const Color.fromRGBO(
                                                                  238,
                                                                  218,
                                                                  172,
                                                                  1,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          }

                                          return const SizedBox.shrink();
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 12.h),
                          _buildResizableBottomSection(context, constraints),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResizableBottomSection(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    if (!_isInitialHeightSet) {
      return SizedBox(
        height: 200.h,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 2.h, bottom: 12.h),
              child: _buildInteractiveCounterRow(),
            ),
            Expanded(
              child: ChatBottomSection(
                showServiceCard: _showServiceCard,
                showActivity: _showActivity,
                selectedPlatform: _selectedPlatform,
                titleSelected: _titleSelected,
                chatFilter: _chatFilter,
                onPlatformSwipe: _handlePlatformSwipe,
              ),
            ),
          ],
        ),
      );
    }

    final screenHeight = Get.height;
    const double bottomGap = 16;
    final minHeight = _isInitialHeightSet ? _initialHeight : 180.h;
    final maxHeight = screenHeight - 122.h - bottomGap.h - 12.h - bottomInset;

    final currentHeight = _bottomSectionHeight.clamp(minHeight, maxHeight);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        height: currentHeight,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 12.h, bottom: 12.h),
              child: _buildInteractiveCounterRow(),
            ),
            Expanded(
              child: ChatBottomSection(
                showServiceCard: _showServiceCard,
                showActivity: _showActivity,
                selectedPlatform: _selectedPlatform,
                titleSelected: _titleSelected,
                chatFilter: _chatFilter,
                onResize: (delta) {
                  final adjustedDelta = delta * _dragSensitivity;
                  setState(() {
                    _bottomSectionHeight = (_bottomSectionHeight - adjustedDelta)
                        .clamp(minHeight, maxHeight);
                  });
                },
                onResizeEnd: () {
                  final midHeight = (minHeight + maxHeight) / 2;

                  double targetHeight;
                  final distToMin = (_bottomSectionHeight - minHeight).abs();
                  final distToMid = (_bottomSectionHeight - midHeight).abs();
                  final distToMax = (_bottomSectionHeight - maxHeight).abs();

                  if (distToMin <= distToMid && distToMin <= distToMax) {
                    targetHeight = minHeight;
                  } else if (distToMid <= distToMax) {
                    targetHeight = midHeight;
                  } else {
                    targetHeight = maxHeight;
                  }

                  setState(() {
                    _bottomSectionHeight = targetHeight;
                  });
                },
                onPlatformSwipe: _handlePlatformSwipe,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Eager gesture recognizer ──────────────────────────────────────────
class _EagerVerticalDragGestureRecognizer
    extends VerticalDragGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
