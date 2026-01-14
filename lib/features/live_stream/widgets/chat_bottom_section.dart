import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/themes/textstyles.dart';
import 'live_stream_helper_widgets.dart';

class ChatBottomSection extends StatefulWidget {
  final ValueNotifier<bool> showServiceCard;
  final ValueNotifier<bool> showActivity;
  final ValueNotifier<String?> selectedPlatform;
  final ValueNotifier<bool> titleSelected;

  const ChatBottomSection({
    super.key,
    required this.showServiceCard,
    required this.showActivity,
    required this.selectedPlatform,
    required this.titleSelected,
  });

  @override
  State<ChatBottomSection> createState() => _ChatBottomSectionState();
}

class _ChatBottomSectionState extends State<ChatBottomSection> {
  static const List<String> platforms = [
    'assets/images/twitch1.png',
    'assets/images/kick.png',
    'assets/images/youtube1.png',
  ];

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

  late List<Map<String, dynamic>> _comments;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _expandedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _comments = [
      {'platform': 'assets/images/twitch1.png', 'name': 'TwitchFan1', 'message': 'Amazing play!'},
      {'platform': 'assets/images/twitch1.png', 'name': 'TwitchFan2', 'message': 'Wow, insane!'},
      {'platform': 'assets/images/twitch1.png', 'name': 'TwitchFan3', 'message': 'Cant believe this!'},
      {'platform': 'assets/images/twitch1.png', 'name': 'TwitchFan4', 'message': 'Go go go!'},
      {'platform': 'assets/images/twitch1.png', 'name': 'TwitchFan5', 'message': 'Lol that was funny!'},
      {'platform': 'assets/images/twitch1.png', 'name': 'TwitchFan6', 'message': 'Best stream ever!'},
      {'platform': 'assets/images/kick.png', 'name': 'KickFan1', 'message': 'Lets goooo!'},
      {'platform': 'assets/images/kick.png', 'name': 'KickFan2', 'message': 'Hyped for this!'},
      {'platform': 'assets/images/kick.png', 'name': 'KickFan3', 'message': 'No way!'},
      {'platform': 'assets/images/kick.png', 'name': 'KickFan4', 'message': 'This is epic!'},
      {'platform': 'assets/images/kick.png', 'name': 'KickFan5', 'message': 'Lol amazing!'},
      {'platform': 'assets/images/kick.png', 'name': 'KickFan6', 'message': 'Cant stop watching!'},
      {'platform': 'assets/images/youtube1.png', 'name': 'YTViewer1', 'message': 'Nice content!'},
      {'platform': 'assets/images/youtube1.png', 'name': 'YTViewer2', 'message': 'Love this!'},
      {'platform': 'assets/images/youtube1.png', 'name': 'YTViewer3', 'message': 'Subscribed!'},
      {'platform': 'assets/images/youtube1.png', 'name': 'YTViewer4', 'message': 'This is lit!'},
      {'platform': 'assets/images/youtube1.png', 'name': 'YTViewer5', 'message': 'Great job!'},
      {'platform': 'assets/images/youtube1.png', 'name': 'YTViewer6', 'message': 'Keep it up!'},
    ];

    _comments.shuffle();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mainScrollController.hasClients) {
        _mainScrollController.jumpTo(_mainScrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _mainScrollController.dispose();
    _expandedScrollController.dispose();
    super.dispose();
  }

  String _getPlatformAsset(String? platformName) {
    if (platformName == null) return platforms[0];
    switch (platformName.toLowerCase()) {
      case 'twitch': return 'assets/images/twitch1.png';
      case 'kick': return 'assets/images/kick.png';
      case 'youtube': return 'assets/images/youtube1.png';
      default: return 'assets/images/twitch1.png';
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final platformAsset = _getPlatformAsset(widget.selectedPlatform.value);
    final item = {'platform': platformAsset, 'name': 'You', 'message': text};
    setState(() {
      _comments.add(item);
    });
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mainScrollController.hasClients) {
        _mainScrollController.jumpTo(_mainScrollController.position.maxScrollExtent + 100);
      }
      if (_expandedScrollController.hasClients) {
        _expandedScrollController.jumpTo(_expandedScrollController.position.maxScrollExtent + 100);
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
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            duration: const Duration(milliseconds: 250),
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
                    Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(height: 16.h),
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
                                    widget.showServiceCard.value = widget.titleSelected.value;
                                  }
                                  setState(() {});
                                },
                                child: pillButton("Activity", isActive: active, assetPath: 'assets/images/line.png'),
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
                                  widget.showServiceCard.value = newVal || widget.showActivity.value;
                                  setState(() {});
                                },
                                child: pillButton("Title", isActive: val, assetPath: 'assets/images/magic.png'),
                              );
                            },
                          ),
                          const Spacer(),
                          SizedBox(width: 12.w),
                          SizedBox(
                            height: 36.h,
                            width: 36.w,
                            child: Image.asset('assets/images/expand.png', color: Colors.yellow),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: ListView.builder(
                          controller: _expandedScrollController,
                          padding: EdgeInsets.only(bottom: 16.h),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final item = _comments[index];
                            final nameColor = nameColors[Random().nextInt(nameColors.length)];
                            return _chatItem(item['platform'], item['name'], item['message'], nameColor);
                          },
                        ),
                      ),
                    ),

                    // Input area (expanded chat) - RE-ALIGNED AS PER SCREENSHOT
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25.r),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            height: 55.h,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(25.r),
                              border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5.w),
                            ),
                            child: Row(
                              children: [
                                // Left Side: Text Input
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    style: sfProText400(17.sp, Colors.white),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Text', // Matches image_9ae694.png
                                      hintStyle: TextStyle(
                                        color: const Color.fromRGBO(235, 235, 245, 0.3),
                                        fontSize: 17.sp,
                                      ),
                                    ),
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                                // Right Side: Icons Grouped
                                Icon(Icons.sentiment_satisfied_sharp, color: Colors.white, size: 24.sp),
                                SizedBox(width: 12.w),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("All", style: TextStyle(color: Colors.white, fontSize: 16.sp)),
                                    Icon(Icons.unfold_more, color: Colors.white.withOpacity(0.6), size: 16.sp),
                                  ],
                                ),
                                SizedBox(width: 8.w),
                              ],
                            ),
                          ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: Column(
        children: [
          SizedBox(height: 10.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 16.h),
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
                          widget.showServiceCard.value = widget.titleSelected.value;
                        }
                      },
                      child: pillButton("Activity", isActive: active, assetPath: 'assets/images/line.png'),
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
                        widget.showServiceCard.value = newVal || widget.showActivity.value;
                      },
                      child: pillButton("Title", isActive: val, assetPath: 'assets/images/magic.png'),
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
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _mainScrollController,
                  padding: EdgeInsets.only(
                    left: 16.w,
                    right: 16.w,
                    bottom: 80.h + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final item = _comments[index];
                    final nameColor = nameColors[random.nextInt(nameColors.length)];
                    return _chatItem(item['platform'], item['name'], item['message'], nameColor);
                  },
                ),

                // Floating Input Button - RE-ALIGNED AS PER SCREENSHOT
                Positioned(
                  bottom: 16.h + MediaQuery.of(context).viewInsets.bottom,
                  left: 10.w,
                  right: 10.w,
                  child: GestureDetector(
                    onTap: () => _openExpandedChat(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25.r),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          height: 55.h,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(25.r),
                            border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5.w),
                          ),
                          child: Row(
                            children: [
                              // Left: Hint Text
                              Expanded(
                                child: Text(
                                  'Text', // Matches image_9ae694.png
                                  style: TextStyle(
                                    color: const Color.fromRGBO(235, 235, 245, 0.3),
                                    fontSize: 17.sp,
                                  ),
                                ),
                              ),
                              // Right: Icons Grouped
                              Icon(Icons.sentiment_satisfied_alt_outlined, color: Colors.white, size: 24.sp),
                              SizedBox(width: 12.w),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("All", style: TextStyle(color: Colors.white, fontSize: 16.sp)),
                                  Icon(Icons.unfold_more, color: Colors.white.withOpacity(0.6), size: 16.sp),
                                ],
                              ),
                            ],
                          ),
                        ),
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

  Widget _chatItem(String platform, String name, String message, Color nameColor) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: RichText(
        text: TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(right: 6.w),
                child: Image.asset(platform, width: 14.sp, height: 14.sp, fit: BoxFit.contain),
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