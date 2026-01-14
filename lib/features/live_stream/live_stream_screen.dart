import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/themes/textstyles.dart';
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
                  buildImageButton(
                    'assets/images/streak_icon.png',
                    width: 72.w,
                    height: 36.w,
                  ),

                  // Right Buttons
                  Row(
                    children: [
                      SizedBox(width: 6.w),
                      buildImageButton(
                        'assets/images/gift.png',
                        width: 36.w,
                        height: 36.w,
                      ),
                      SizedBox(width: 6.w),
                      buildImageButton(
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

                                    activityRow(
                                      'assets/images/kick.png',
                                      'New Follower',
                                      '19:41',
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
                                    counterPill(
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
                                    counterPill(
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
                                    counterPill(
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
                                        panelRow('Title Example'),
                                        SizedBox(height: 12.h),
                                        panelRow(
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
                                        counterPill(
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
                                        counterPill(
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
                                        counterPill(
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
                                          serviceRow(
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
                                          serviceRow(
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
                                          serviceRow(
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
                                      counterPill(
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
                                      counterPill(
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
                                      counterPill(
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
                                counterPill(
                                  asset: 'assets/images/twitch.png',
                                  count: '11202',
                                  color: Color.fromRGBO(185, 80, 239, 1),
                                  bgColor: Color.fromRGBO(185, 80, 239, 0.25),
                                ),
                                SizedBox(width: 13.2.w),
                                counterPill(
                                  asset: 'assets/images/kick.png',
                                  count: '1256',
                                  color: Color.fromRGBO(83, 252, 24, 1),
                                  bgColor: Color.fromRGBO(83, 252, 24, 0.25),
                                ),
                                SizedBox(width: 13.2.w),
                                counterPill(
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
                    child: ChatBottomSection(
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
}
