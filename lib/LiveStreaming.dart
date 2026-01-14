import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'core/themes/textstyles.dart';

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

  @override
  void dispose() {
    _showServiceCard.dispose();
    _selectedPlatform.dispose();
    _showActivity.dispose();
    _titleSelected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // 🔹 Top Background Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300.h,
            child: Image.asset(
              'assets/images/topbarshade.png',
              fit: BoxFit.cover,
            ),
          ),

          // 🔹 Gradient Overlay
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

          // 🔹 Header (Image Buttons)
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 28.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Offline Button
                  _buildImageButton(
                    'assets/images/streak_icon.png',
                    width: 72.w,
                    height: 36.w,
                  ),

                  // Right Buttons
                  Row(
                    children: [
                      SizedBox(width: 6.w),
                      _buildImageButton(
                        'assets/images/gift.png',
                        width: 36.w,
                        height: 36.w,
                      ),
                      SizedBox(width: 6.w),
                      _buildImageButton(
                        'assets/images/settings.png',
                        width: 36.w,
                        height: 36.w,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 🔹 Center Content
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 122.h),

                  ValueListenableBuilder<bool>(
                    valueListenable: _showServiceCard,
                    builder: (context, showCard, child) {
                      if (showCard) {
                        if (_showActivity.value) {
                          return Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 12.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(22, 21, 24, 1),
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Column(
                                  children: [
                                    SizedBox(height: 12.h),

                                    _activityRow(
                                      'assets/images/kick.png',
                                      'New Follower',
                                      '19:41',
                                      '',
                                    ),
                                    SizedBox(height: 12.h),
                                    _activityRow(
                                      'assets/images/kick.png',
                                      'Mega Supporter',
                                      '19:49',
                                      '\$50',
                                    ),
                                    SizedBox(height: 12.h),
                                    _activityRow(
                                      'assets/images/youtube1.png',
                                      'Fun',
                                      '19:49',
                                      'Subscribed',
                                    ),
                                    SizedBox(height: 12.h),
                                    _activityRow(
                                      'assets/images/twitch1.png',
                                      'Ranen',
                                      '19:49',
                                      'Subscribed',
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16.h),

                              Container(
                                width: 297.w,
                                height: 59.4.h,
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(30, 29, 32, 1),
                                  borderRadius: BorderRadius.circular(33.r),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _counterPill(
                                      asset: 'assets/images/twitch.png',
                                      count: '11202',
                                      color: Color.fromRGBO(185, 80, 239, 1),
                                      bgColor: Color.fromRGBO(
                                        185,
                                        80,
                                        239,
                                        0.25,
                                      ),
                                    ),
                                    SizedBox(width: 13.2.w),
                                    _counterPill(
                                      asset: 'assets/images/kick.png',
                                      count: '1256',
                                      color: Color.fromRGBO(83, 252, 24, 1),
                                      bgColor: Color.fromRGBO(
                                        83,
                                        252,
                                        24,
                                        0.25,
                                      ),
                                    ),
                                    SizedBox(width: 13.2.w),
                                    _counterPill(
                                      asset: 'assets/images/youtube.png',
                                      count: '256',
                                      color: Color.fromRGBO(221, 44, 40, 1),
                                      bgColor: Color.fromRGBO(
                                        221,
                                        44,
                                        40,
                                        0.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        return ValueListenableBuilder<String?>(
                          valueListenable: _selectedPlatform,
                          builder: (context, platform, _) {
                            if (platform != null) {
                              final asset = platform == 'twitch'
                                  ? 'assets/images/twitch1.png'
                                  : platform == 'kick'
                                  ? 'assets/images/kick.png'
                                  : 'assets/images/youtube1.png';

                              // Platform panel (matches attached design)
                              return Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 12.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color.fromRGBO(22, 21, 24, 1),
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Column(
                                      children: [
                                        // top bar with back and centered logo
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.w,
                                          ),
                                          child: Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  _selectedPlatform.value =
                                                      null;
                                                  _showServiceCard.value =
                                                      false;
                                                  _titleSelected.value = false;
                                                  _showActivity.value = false;
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.all(8.w),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade900,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Transform.translate(
                                                    offset: const Offset(
                                                      2,
                                                      0,
                                                    ), // fine-tune if needed
                                                    child: Icon(
                                                      Icons.arrow_back_ios,
                                                      color: Colors.white,
                                                      size: 16.sp,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Center(
                                                child: Image.asset(
                                                  asset,
                                                  width: 22.w,
                                                  height: 22.h,
                                                ),
                                              ),

                                              const Spacer(),
                                              SizedBox(width: 40.w),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 16.h),

                                        // Two large rows: Title Example & Name Category
                                        _panelRow('Title Example'),
                                        SizedBox(height: 12.h),
                                        _panelRow(
                                          'Name Category',
                                          showChevron: true,
                                          onTap: () {
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (ctx) {
                                                return Padding(
                                                  padding: EdgeInsets.only(
                                                    bottom: MediaQuery.of(
                                                      ctx,
                                                    ).viewInsets.bottom,
                                                  ),
                                                  child: FractionallySizedBox(
                                                    heightFactor: 0.8,
                                                    child: AnimatedPadding(
                                                      padding: EdgeInsets.only(
                                                        bottom: MediaQuery.of(
                                                          ctx,
                                                        ).viewInsets.bottom,
                                                      ),
                                                      duration: Duration(
                                                        milliseconds: 250,
                                                      ),
                                                      curve: Curves.easeOut,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: Color.fromRGBO(
                                                            20,
                                                            18,
                                                            18,
                                                            1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.vertical(
                                                                top:
                                                                    Radius.circular(
                                                                      38.r,
                                                                    ),
                                                              ),
                                                        ),
                                                        child: Stack(
                                                          children: [
                                                            Column(
                                                              children: [
                                                                SizedBox(
                                                                  height: 10.h,
                                                                ),
                                                                // Top handle + header
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
                                                                        onTap: () => Navigator.of(
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
                                                                            ), // background
                                                                            shape:
                                                                                BoxShape.circle,
                                                                          ),
                                                                          child: Center(
                                                                            child: Transform.translate(
                                                                              offset: const Offset(
                                                                                2.5,
                                                                                0,
                                                                              ), // required for arrow_back_ios
                                                                              child: Icon(
                                                                                Icons.arrow_back_ios,
                                                                                color: Colors.white, // icon color
                                                                                size: 18,
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
                                                                          Colors
                                                                              .white,
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
                                                                  height: 12.h,
                                                                ),
                                                                Expanded(
                                                                  child: ListView.separated(
                                                                    padding: EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          16.w,
                                                                      vertical:
                                                                          8.h,
                                                                    ),
                                                                    itemCount:
                                                                        14,
                                                                    separatorBuilder:
                                                                        (
                                                                          _,
                                                                          __,
                                                                        ) => SizedBox(
                                                                          height:
                                                                              12.h,
                                                                        ),
                                                                    itemBuilder: (c, i) {
                                                                      return InkWell(
                                                                        onTap:
                                                                            () {},
                                                                        borderRadius:
                                                                            BorderRadius.circular(
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
                                                                            color: Color.fromRGBO(
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
                                                                                width: 25.w,
                                                                                height: 25.w,
                                                                                decoration: BoxDecoration(
                                                                                  color: Colors.grey.shade900,
                                                                                  borderRadius: BorderRadius.circular(
                                                                                    18.r,
                                                                                  ),
                                                                                ),
                                                                                child: Icon(
                                                                                  Icons.arrow_forward_ios,
                                                                                  color: Colors.grey.shade500,
                                                                                  size: 10.sp,
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
                                                              bottom: 18.h,
                                                              left: 74.w,
                                                              right: 74.w,
                                                              child: Container(
                                                                height: 56.h,
                                                                padding:
                                                                    EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          16.w,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .black,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        28.r,
                                                                      ),
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .search,
                                                                      color: Colors
                                                                          .white,
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
                                                                      color: Colors
                                                                          .white,
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
                                  SizedBox(height: 16.h),
                                  // counters
                                  Container(
                                    width: 297.w,
                                    height: 59.4.h,
                                    decoration: BoxDecoration(
                                      color: Color.fromRGBO(30, 29, 32, 1),
                                      borderRadius: BorderRadius.circular(33.r),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _counterPill(
                                          asset: 'assets/images/twitch.png',
                                          count: '11202',
                                          color: Color.fromRGBO(
                                            185,
                                            80,
                                            239,
                                            1,
                                          ),
                                          bgColor: Color.fromRGBO(
                                            185,
                                            80,
                                            239,
                                            0.25,
                                          ),
                                        ),
                                        SizedBox(width: 13.2.w),
                                        _counterPill(
                                          asset: 'assets/images/kick.png',
                                          count: '1256',
                                          color: Color.fromRGBO(83, 252, 24, 1),
                                          bgColor: Color.fromRGBO(
                                            83,
                                            252,
                                            24,
                                            0.25,
                                          ),
                                        ),
                                        SizedBox(width: 13.2.w),
                                        _counterPill(
                                          asset: 'assets/images/youtube.png',
                                          count: '256',
                                          color: Color.fromRGBO(221, 44, 40, 1),
                                          bgColor: Color.fromRGBO(
                                            221,
                                            44,
                                            40,
                                            0.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            // no platform selected: show service list
                            return Column(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: 14.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Color.fromRGBO(22, 21, 24, 1),
                                        borderRadius: BorderRadius.circular(
                                          20.r,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _serviceRow(
                                            asset: 'assets/images/twitch1.png',
                                            title: 'Title',
                                            subtitle: 'Category',
                                            onTap: () {
                                              _selectedPlatform.value =
                                                  'twitch';
                                              _titleSelected.value = true;
                                              _showServiceCard.value = true;
                                            },
                                          ),
                                          SizedBox(height: 10.h),
                                          _serviceRow(
                                            asset: 'assets/images/kick.png',
                                            title: 'Title',
                                            subtitle: 'Category',
                                            onTap: () {
                                              _selectedPlatform.value = 'kick';
                                              _titleSelected.value = true;
                                              _showServiceCard.value = true;
                                            },
                                          ),
                                          SizedBox(height: 10.h),
                                          _serviceRow(
                                            asset: 'assets/images/youtube1.png',
                                            title: 'Title',
                                            subtitle: 'Category',
                                            onTap: () {
                                              _selectedPlatform.value =
                                                  'youtube';
                                              _titleSelected.value = true;
                                              _showServiceCard.value = true;
                                            },
                                          ),
                                          SizedBox(height: 36.h),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 6.h,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20.w,
                                          vertical: 8.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color.fromRGBO(20, 18, 20, 1),
                                          borderRadius: BorderRadius.circular(
                                            20.r,
                                          ),
                                          border: Border.all(
                                            color: Colors.white10,
                                            width: 1.w,
                                          ),
                                        ),
                                        child: Text(
                                          'Update All',
                                          style: sfProText400(
                                            14.sp,
                                            Color.fromRGBO(238, 218, 172, 1),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                Container(
                                  width: 297.w,
                                  height: 59.4.h,
                                  decoration: BoxDecoration(
                                    color: Color.fromRGBO(30, 29, 32, 1),
                                    borderRadius: BorderRadius.circular(33.r),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _counterPill(
                                        asset: 'assets/images/twitch.png',
                                        count: '11202',
                                        color: Color.fromRGBO(185, 80, 239, 1),
                                        bgColor: Color.fromRGBO(
                                          185,
                                          80,
                                          239,
                                          0.25,
                                        ),
                                      ),
                                      SizedBox(width: 13.2.w),
                                      _counterPill(
                                        asset: 'assets/images/kick.png',
                                        count: '1256',
                                        color: Color.fromRGBO(83, 252, 24, 1),
                                        bgColor: Color.fromRGBO(
                                          83,
                                          252,
                                          24,
                                          0.25,
                                        ),
                                      ),
                                      SizedBox(width: 13.2.w),
                                      _counterPill(
                                        asset: 'assets/images/youtube.png',
                                        count: '256',
                                        color: Color.fromRGBO(221, 44, 40, 1),
                                        bgColor: Color.fromRGBO(
                                          221,
                                          44,
                                          40,
                                          0.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      }

                      // default: image placeholder
                      return Column(
                        children: [
                          Container(
                            height: 236.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24.r),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24.r),
                              child: Opacity(
                                opacity: 1,
                                child: Image.asset(
                                  'assets/images/streaming.png', // replace with your placeholder image path
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12.h),

                          // counters under the display image (restored)
                          Container(
                            width: 297.w,
                            height: 59.4.h,
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(30, 29, 32, 1),
                              borderRadius: BorderRadius.circular(33.r),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _counterPill(
                                  asset: 'assets/images/twitch.png',
                                  count: '11202',
                                  color: Color.fromRGBO(185, 80, 239, 1),
                                  bgColor: Color.fromRGBO(185, 80, 239, 0.25),
                                ),
                                SizedBox(width: 13.2.w),
                                _counterPill(
                                  asset: 'assets/images/kick.png',
                                  count: '1256',
                                  color: Color.fromRGBO(83, 252, 24, 1),
                                  bgColor: Color.fromRGBO(83, 252, 24, 0.25),
                                ),
                                SizedBox(width: 13.2.w),
                                _counterPill(
                                  asset: 'assets/images/youtube.png',
                                  count: '256',
                                  color: Color.fromRGBO(221, 44, 40, 1),
                                  bgColor: Color.fromRGBO(221, 44, 40, 0.25),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  SizedBox(height: 12.h),
                  Expanded(
                    child: _ChatBottomSection(
                      showServiceCard: _showServiceCard,
                      showActivity: _showActivity,
                      selectedPlatform: _selectedPlatform,
                      titleSelected: _titleSelected,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Reusable Image Button
  static Widget _buildImageButton(
    String assetPath, {
    required double width,
    required double height,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }
}

class _ChatBottomSection extends StatefulWidget {
  final ValueNotifier<bool> showServiceCard;
  final ValueNotifier<bool> showActivity;
  final ValueNotifier<String?> selectedPlatform;
  final ValueNotifier<bool> titleSelected;

  const _ChatBottomSection({
    required this.showServiceCard,
    required this.showActivity,
    required this.selectedPlatform,
    required this.titleSelected,
  });

  @override
  State<_ChatBottomSection> createState() => _ChatBottomSectionState();
}

class _ChatBottomSectionState extends State<_ChatBottomSection> {
  static const List<String> platforms = [
    'assets/images/twitch1.png',
    'assets/images/kick.png',
    'assets/images/youtube1.png',
  ];

  // Name colors to randomize
  static const List<Color> nameColors = [
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.orange,
    Colors.red,
    Colors.teal,
    Colors.yellow,
    Colors.pink,
  ];

  // Chat state
  late List<Map<String, dynamic>> _comments;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _expandedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _comments = [
      // Twitch comments
      {
        'platform': 'assets/images/twitch1.png',
        'name': 'TwitchFan1',
        'message': 'Amazing play!',
      },
      {
        'platform': 'assets/images/twitch1.png',
        'name': 'TwitchFan2',
        'message': 'Wow, insane!',
      },
      {
        'platform': 'assets/images/twitch1.png',
        'name': 'TwitchFan3',
        'message': 'Cant believe this!',
      },
      {
        'platform': 'assets/images/twitch1.png',
        'name': 'TwitchFan4',
        'message': 'Go go go!',
      },
      {
        'platform': 'assets/images/twitch1.png',
        'name': 'TwitchFan5',
        'message': 'Lol that was funny!',
      },
      {
        'platform': 'assets/images/twitch1.png',
        'name': 'TwitchFan6',
        'message': 'Best stream ever!',
      },

      // Kick comments
      {
        'platform': 'assets/images/kick.png',
        'name': 'KickFan1',
        'message': 'Lets goooo!',
      },
      {
        'platform': 'assets/images/kick.png',
        'name': 'KickFan2',
        'message': 'Hyped for this!',
      },
      {
        'platform': 'assets/images/kick.png',
        'name': 'KickFan3',
        'message': 'No way!',
      },
      {
        'platform': 'assets/images/kick.png',
        'name': 'KickFan4',
        'message': 'This is epic!',
      },
      {
        'platform': 'assets/images/kick.png',
        'name': 'KickFan5',
        'message': 'Lol amazing!',
      },
      {
        'platform': 'assets/images/kick.png',
        'name': 'KickFan6',
        'message': 'Cant stop watching!',
      },

      // YouTube comments
      {
        'platform': 'assets/images/youtube1.png',
        'name': 'YTViewer1',
        'message': 'Nice content!',
      },
      {
        'platform': 'assets/images/youtube1.png',
        'name': 'YTViewer2',
        'message': 'Love this!',
      },
      {
        'platform': 'assets/images/youtube1.png',
        'name': 'YTViewer3',
        'message': 'Subscribed!',
      },
      {
        'platform': 'assets/images/youtube1.png',
        'name': 'YTViewer4',
        'message': 'This is lit!',
      },
      {
        'platform': 'assets/images/youtube1.png',
        'name': 'YTViewer5',
        'message': 'Great job!',
      },
      {
        'platform': 'assets/images/youtube1.png',
        'name': 'YTViewer6',
        'message': 'Keep it up!',
      },
    ];

    _comments.shuffle();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _mainScrollController.dispose();
    _expandedScrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final item = {
      'platform': widget.selectedPlatform.value ?? platforms[0],
      'name': 'You',
      'message': text,
    };

    setState(() {
      _comments.add(item);
    });

    _messageController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mainScrollController.hasClients) {
        _mainScrollController.animateTo(
          _mainScrollController.position.maxScrollExtent + 100,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      if (_expandedScrollController.hasClients) {
        _expandedScrollController.animateTo(
          _expandedScrollController.position.maxScrollExtent + 100,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openExpandedChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.94,
          child: AnimatedPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            duration: Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    SizedBox(height: 10.h),
                    // Handle
                    Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Top Tabs
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Row(
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: widget.showActivity,
                            builder: (context, active, _) {
                              return GestureDetector(
                                onTap: () {
                                  final newVal = !active;
                                  widget.showActivity.value = newVal;
                                  if (newVal) {
                                    widget.selectedPlatform.value = null;
                                    widget.showServiceCard.value = true;
                                  } else {
                                    widget.showServiceCard.value =
                                        widget.titleSelected.value;
                                  }
                                  setState(() {});
                                },
                                child: _pillButton(
                                  "Activity",
                                  isActive: active,
                                  assetPath: 'assets/images/line.png',
                                ),
                              );
                            },
                          ),
                          SizedBox(width: 12.w),
                          ValueListenableBuilder<bool>(
                            valueListenable: widget.titleSelected,
                            builder: (context, val, _) {
                              return GestureDetector(
                                onTap: () {
                                  final newVal = !val;
                                  widget.titleSelected.value = newVal;
                                  widget.showServiceCard.value =
                                      newVal || widget.showActivity.value;
                                  setState(() {});
                                },
                                child: _pillButton(
                                  "Title",
                                  isActive: val,
                                  assetPath: 'assets/images/magic.png',
                                ),
                              );
                            },
                          ),
                          const Spacer(),
                          SizedBox(width: 12.w),
                          SizedBox(
                            height: 36.h,
                            width: 36.w,
                            child: Image.asset(
                              'assets/images/expand.png',
                              color: Colors.yellow,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Expanded Chat List
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: ListView.builder(
                          controller: _expandedScrollController,
                          padding: EdgeInsets.only(bottom: 16.h),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final item = _comments[index];
                            final nameColor =
                                nameColors[Random().nextInt(nameColors.length)];
                            return _chatItem(
                              item['platform'],
                              item['name'],
                              item['message'],
                              nameColor,
                            );
                          },
                        ),
                      ),
                    ),

                    // Input area (expanded chat)
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        height: 55.h,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(25.r),
                          border: Border.all(color: Colors.white10, width: 1.w),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.emoji_emotions_outlined,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                style: sfProText400(17.sp, Colors.white),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Write a message...',
                                  hintStyle: TextStyle(
                                    color: Color.fromRGBO(235, 235, 245, 0.3),
                                    fontSize: 17.sp,
                                  ),
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    "All",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                  Icon(
                                    Icons.unfold_more,
                                    color: Colors.grey,
                                    size: 14.sp,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            IconButton(
                              onPressed: _sendMessage,
                              icon: Icon(Icons.send, color: Colors.white),
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
  }

  @override
  Widget build(BuildContext context) {
    final random = Random();

    // using _comments state (initialized in initState)

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900, // onBottomSheetGrey
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
          // Tabs
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: widget.showActivity,
                  builder: (context, active, _) {
                    return GestureDetector(
                      onTap: () {
                        final newVal = !active;
                        widget.showActivity.value = newVal;
                        if (newVal) {
                          widget.selectedPlatform.value = null;
                          widget.showServiceCard.value = true;
                        } else {
                          widget.showServiceCard.value =
                              widget.titleSelected.value;
                        }
                      },
                      child: _pillButton(
                        "Activity",
                        isActive: active,
                        assetPath: 'assets/images/line.png',
                      ),
                    );
                  },
                ),
                SizedBox(width: 12.w),
                ValueListenableBuilder<bool>(
                  valueListenable: widget.titleSelected,
                  builder: (context, val, _) {
                    return GestureDetector(
                      onTap: () {
                        final newVal = !val;
                        widget.titleSelected.value = newVal;
                        widget.showServiceCard.value =
                            newVal || widget.showActivity.value;
                      },
                      child: _pillButton(
                        "Title",
                        isActive: val,
                        assetPath: 'assets/images/magic.png',
                      ),
                    );
                  },
                ),
                const Spacer(),
                SizedBox(width: 12.w),
                GestureDetector(
                  onTap: () => _openExpandedChat(context),
                  child: SizedBox(
                    height: 36.h,
                    width: 36.w,
                    child: Image.asset('assets/images/expand.png'),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Chat List with Floating Button
          Expanded(
            child: Stack(
              children: [
                // Chat List
                ListView.builder(
                  controller: _mainScrollController,
                  padding: EdgeInsets.only(
                    left: 16.w,
                    right: 16.w,
                    bottom:
                        80.h +
                        MediaQuery.of(context)
                            .viewInsets
                            .bottom, // Add padding to prevent content hiding behind button
                  ),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final item = _comments[index];
                    // Pick a random color for the name
                    final nameColor =
                        nameColors[random.nextInt(nameColors.length)];
                    return _chatItem(
                      item['platform'],
                      item['name'],
                      item['message'],
                      nameColor,
                    );
                  },
                ),
                // Floating Input Button
                Positioned(
                  bottom: 16.h + MediaQuery.of(context).viewInsets.bottom,
                  left: 10.w,
                  right: 10.w,
                  child: GestureDetector(
                    onTap: () => _openExpandedChat(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      height: 55.h,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(25.r),
                        border: Border.all(color: Colors.white10, width: 1.w),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.emoji_emotions_outlined,
                            color: Colors.white,
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Write a message...',
                              style: TextStyle(
                                color: Color.fromRGBO(235, 235, 245, 0.3),
                                fontSize: 17.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  "All",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                  ),
                                ),
                                Icon(
                                  Icons.unfold_more,
                                  color: Colors.grey,
                                  size: 14.sp,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          IconButton(
                            onPressed: _sendMessage,
                            icon: Icon(Icons.send, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatItem(
    String platform,
    String name,
    String message,
    Color nameColor,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: RichText(
        text: TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(right: 6.w),
                child: Image.asset(
                  platform,
                  width: 14.sp,
                  height: 14.sp,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            TextSpan(text: "$name: ", style: sfProText500(12.sp, nameColor)),
            TextSpan(text: message, style: sfProText400(12.sp, Colors.white)),
          ],
        ),
      ),
    );
  }
}

// Top-level helpers so both widgets can reuse them
Widget _serviceRow({
  required String asset,
  required String title,
  required String subtitle,
  VoidCallback? onTap,
}) {
  final row = Container(
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
    decoration: BoxDecoration(
      color: Color.fromRGBO(30, 29, 32, 1),
      borderRadius: BorderRadius.circular(32.r),
    ),
    child: Row(
      children: [
        Center(
          child: Image.asset(asset, width: 23.w, height: 23.h),
        ),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: sfProText600(12.sp, Colors.white)),
            Text(subtitle, style: sfProText400(10.sp, Colors.grey.shade500)),
          ],
        ),
        const Spacer(),
        Container(
          width: 30.w,
          height: 30.w,
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Icon(
            Icons.arrow_forward_ios,
            color: Colors.white,
            size: 16.sp,
          ),
        ),
      ],
    ),
  );

  if (onTap != null) {
    return GestureDetector(onTap: onTap, child: row);
  }

  return row;
}

Widget _counterPill({
  required String asset,
  required String count,
  required Color color,
  required Color bgColor,
}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 15.w),
    height: 38.5.h,
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(70.4.r),
    ),
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(asset, color: color, width: 12.1.w, height: 12.1.h),
          SizedBox(width: 4.4.w),
          Text(count, style: sfProText400(14.3.sp, color)),
        ],
      ),
    ),
  );
}

Widget _panelRow(String text, {bool showChevron = false, VoidCallback? onTap}) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
    decoration: BoxDecoration(
      color: Color.fromRGBO(30, 29, 32, 1),
      borderRadius: BorderRadius.circular(28.r),
    ),
    child: Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                Text(text, style: sfProText600(13.sp, Colors.white)),
                const Spacer(),
                if (showChevron)
                  Container(
                    height: 20,
                    width: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(1.2, 0), // shift left
                        child: Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 13.sp,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _activityRow(String asset, String name, String time, String message) {
  final Color nameColor = asset.contains('kick')
      ? Color.fromRGBO(83, 252, 24, 1)
      : asset.contains('twitch')
      ? Color.fromRGBO(185, 80, 239, 1)
      : asset.contains('youtube')
      ? Color.fromRGBO(221, 44, 40, 1)
      : Colors.white;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Image.asset(asset, width: 16.w, height: 16.h),
          SizedBox(width: 8.w),
          Text(name, style: sfProText600(14.sp, nameColor)),
          Spacer(),
          Text(time, style: sfProText400(12.sp, Colors.grey.shade400)),
        ],
      ),
      if (message.isNotEmpty) ...[
        SizedBox(height: 6.h),
        Text(message, style: sfProText600(15.sp, Colors.white)),
      ],
    ],
  );
}

Widget _pillButton(String text, {required bool isActive, String? assetPath}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
    decoration: BoxDecoration(
      color: isActive ? const Color(0xFF1E1E1E) : Colors.transparent,
      borderRadius: BorderRadius.circular(20.r),
      border: Border.all(
        color: isActive ? Colors.yellow : Colors.grey.shade800,
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
            color: isActive ? Colors.yellow : Colors.grey.shade600,
          ),
          SizedBox(width: 6.w),
        ],
        Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.yellow : Colors.grey.shade600,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
