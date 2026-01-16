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
  final ValueNotifier<String?> chatFilter;

  const ChatBottomSection({
    super.key,
    required this.showServiceCard,
    required this.showActivity,
    required this.selectedPlatform,
    required this.titleSelected,
    required this.chatFilter,
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

  static const Color twitchColor = Color.fromRGBO(185, 80, 239, 1);
  static const Color kickColor = Color.fromRGBO(83, 252, 24, 1);
  static const Color youtubeColor = Color.fromRGBO(221, 44, 40, 1);

  late List<Map<String, dynamic>> _comments;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _expandedScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _comments = [
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
        'platform': 'assets/images/youtube1.png',
        'name': 'YTViewer1',
        'message': 'Nice content!',
      },
      {
        'platform': 'assets/images/youtube1.png',
        'name': 'YTViewer2',
        'message': 'Love this!',
      },
    ];
    for (int i = 0; i < 10; i++) {
      _comments.add({
        'platform': 'assets/images/twitch1.png',
        'name': 'User$i',
        'message': 'Hello $i',
      });
    }
    _comments.shuffle();

    // Auto-scroll to bottom on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(_mainScrollController, animate: false);
      _scrollToBottom(_expandedScrollController, animate: false);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _mainScrollController.dispose();
    _expandedScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom(ScrollController controller, {bool animate = true}) {
    if (!controller.hasClients) {
      // If not ready, schedule for next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(controller, animate: animate);
      });
      return;
    }

    if (animate) {
      // Use a shorter duration for instant feel
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    } else {
      controller.jumpTo(controller.position.maxScrollExtent);
    }
  }

  String _getPlatformAsset(String? platformName) {
    if (platformName == null) return platforms[0];
    switch (platformName.toLowerCase()) {
      case 'twitch':
        return 'assets/images/twitch1.png';
      case 'kick':
        return 'assets/images/kick.png';
      case 'youtube':
        return 'assets/images/youtube1.png';
      default:
        return 'assets/images/twitch1.png';
    }
  }

  List<Map<String, dynamic>> _getFilteredComments(String? filter) {
    if (filter == null) return _comments;
    return _comments.where((item) {
      final platformPath = item['platform'].toString().toLowerCase();
      final filterKey = filter.toLowerCase();
      return platformPath.contains(filterKey);
    }).toList();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    String currentPlatform = widget.chatFilter.value ?? 'twitch';
    if (widget.chatFilter.value == null &&
        widget.selectedPlatform.value != null) {
      currentPlatform = widget.selectedPlatform.value!;
    }

    final platformAsset = _getPlatformAsset(currentPlatform);
    final item = {'platform': platformAsset, 'name': 'You', 'message': text};

    // Add comment and trigger rebuild immediately
    setState(() {
      _comments.add(item);
    });

    // Clear text field but keep keyboard open
    _messageController.clear();

    // Keep focus on text field (keyboard stays open)
    _focusNode.requestFocus();

    // Scroll to bottom immediately after frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(_mainScrollController, animate: true);
      _scrollToBottom(_expandedScrollController, animate: true);
    });
  }

  Widget _buildPlatformSelector(StateSetter? setSheetState) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.chatFilter,
      builder: (context, filter, _) {
        String label = "All";
        Color labelColor = Colors.white; // Default color for "All"

        if (filter != null) {
          label = "${filter[0].toUpperCase()}${filter.substring(1)}";
          // Change color based on selection
          switch (filter) {
            case 'twitch':
              labelColor = twitchColor;
              break;
            case 'kick':
              labelColor = kickColor;
              break;
            case 'youtube':
              labelColor = youtubeColor;
              break;
          }
        }

        return Theme(
          data: Theme.of(context).copyWith(
            popupMenuTheme: PopupMenuThemeData(
              color: const Color(0xFF141414),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
              ),
            ),
          ),
          child: PopupMenuButton<String>(
            offset: Offset(0, -220.h),
            constraints: BoxConstraints(minWidth: 140.w, maxWidth: 140.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.r),
            ),
            color: const Color(0xFF141414),
            elevation: 8,
            onSelected: (String value) {
              if (value == 'all') {
                widget.chatFilter.value = null;
              } else {
                widget.chatFilter.value = value;
              }
              setState(() {});
              if (setSheetState != null) setSheetState(() {});
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'all',
                height: 48.h,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (filter == null) ...[
                        Icon(Icons.check, color: Colors.white, size: 18.sp),
                        SizedBox(width: 8.w),
                      ],
                      Text('All', style: sfProText500(18.sp, Colors.white)),
                    ],
                  ),
                ),
              ),
              PopupMenuDivider(height: 1.h),
              PopupMenuItem<String>(
                value: 'twitch',
                height: 48.h,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (filter == 'twitch') ...[
                        Icon(Icons.check, color: twitchColor, size: 18.sp),
                        SizedBox(width: 6.w),
                      ],
                      Text('Twitch', style: sfProText500(18.sp, twitchColor)),
                    ],
                  ),
                ),
              ),
              PopupMenuItem<String>(
                value: 'kick',
                height: 48.h,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (filter == 'kick') ...[
                        Icon(Icons.check, color: kickColor, size: 18.sp),
                        SizedBox(width: 6.w),
                      ],
                      Text('Kick', style: sfProText500(18.sp, kickColor)),
                    ],
                  ),
                ),
              ),
              PopupMenuItem<String>(
                value: 'youtube',
                height: 48.h,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (filter == 'youtube') ...[
                        Icon(Icons.check, color: youtubeColor, size: 18.sp),
                        SizedBox(width: 6.w),
                      ],
                      Text('YouTube', style: sfProText500(18.sp, youtubeColor)),
                    ],
                  ),
                ),
              ),
            ],
            // Updated Child with Dynamic Color
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: labelColor, fontSize: 16.sp),
                  ),
                  Icon(
                    Icons.unfold_more,
                    color: Colors.white.withOpacity(0.6),
                    size: 16.sp,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openExpandedChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.94,
              child: AnimatedPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30.r),
                    ),
                  ),
                  child: SafeArea(
                    child: GestureDetector(
                      onTap: () {
                        // Dismiss keyboard when tapping outside in expanded view
                        _focusNode.unfocus();
                      },
                      behavior: HitTestBehavior.opaque,
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
                                          widget.showServiceCard.value =
                                              widget.titleSelected.value;
                                        }
                                        setState(() {});
                                        setSheetState(() {});
                                      },
                                      child: pillButton(
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
                                        setSheetState(() {});
                                      },
                                      child: pillButton(
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
                                  onTap: () => Navigator.pop(context),
                                  child: SizedBox(
                                    height: 36.h,
                                    width: 36.w,
                                    child: Image.asset(
                                      'assets/images/expand.png',
                                      color: Colors.yellow,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: ValueListenableBuilder<String?>(
                                valueListenable: widget.chatFilter,
                                builder: (context, filter, child) {
                                  final filteredList = _getFilteredComments(
                                    filter,
                                  );
                                  return ListView.builder(
                                    key: ValueKey(
                                      'expanded_chat_${_comments.length}_${filter ?? 'all'}',
                                    ),
                                    controller: _expandedScrollController,
                                    padding: EdgeInsets.only(bottom: 16.h),
                                    itemCount: filteredList.length,
                                    itemBuilder: (context, index) {
                                      final item = filteredList[index];
                                      // Use consistent color based on name hash for stability
                                      final nameHash = item['name'].hashCode;
                                      final nameColor =
                                          nameColors[nameHash.abs() %
                                              nameColors.length];
                                      return _chatItem(
                                        item['platform'],
                                        item['name'],
                                        item['message'],
                                        nameColor,
                                        key: ValueKey(
                                          'expanded_${item['name']}_$index',
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(25.r),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                  ),
                                  height: 55.h,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(25.r),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 0.5.w,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _messageController,
                                          focusNode: _focusNode,
                                          style: sfProText400(
                                            17.sp,
                                            Colors.white,
                                          ),
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            hintText: 'Text',
                                            hintStyle: TextStyle(
                                              color: const Color.fromRGBO(
                                                235,
                                                235,
                                                245,
                                                0.3,
                                              ),
                                              fontSize: 17.sp,
                                            ),
                                          ),
                                          textInputAction: TextInputAction.send,
                                          onSubmitted: (_) {
                                            _sendMessage();
                                            // Don't rebuild sheet, just update comments
                                          },
                                        ),
                                      ),
                                      Icon(
                                        Icons.sentiment_satisfied_sharp,
                                        color: Colors.white,
                                        size: 24.sp,
                                      ),
                                      SizedBox(width: 12.w),

                                      _buildPlatformSelector(setSheetState),

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
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        _focusNode.unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
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
                            widget.showServiceCard.value =
                                widget.titleSelected.value;
                          }
                        },
                        child: pillButton(
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
                        child: pillButton(
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
            Expanded(
              child: Stack(
                children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: widget.chatFilter,
                    builder: (context, filter, child) {
                      final filteredList = _getFilteredComments(filter);
                      return ListView.builder(
                        key: ValueKey(
                          'main_chat_${_comments.length}_${filter ?? 'all'}',
                        ),
                        controller: _mainScrollController,
                        padding: EdgeInsets.only(
                          left: 16.w,
                          right: 16.w,
                          bottom:
                              80.h + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          // Use consistent color based on name hash for stability
                          final nameHash = item['name'].hashCode;
                          final nameColor =
                              nameColors[nameHash.abs() % nameColors.length];
                          return _chatItem(
                            item['platform'],
                            item['name'],
                            item['message'],
                            nameColor,
                            key: ValueKey('main_${item['name']}_$index'),
                          );
                        },
                      );
                    },
                  ),
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
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 0.5.w,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Text',
                                    style: TextStyle(
                                      color: const Color.fromRGBO(
                                        235,
                                        235,
                                        245,
                                        0.3,
                                      ),
                                      fontSize: 17.sp,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.sentiment_satisfied_alt_outlined,
                                  color: Colors.white,
                                  size: 24.sp,
                                ),
                                SizedBox(width: 12.w),

                                _buildPlatformSelector(null),
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
      ),
    );
  }

  // Included _chatItem method
  Widget _chatItem(
    String platform,
    String name,
    String message,
    Color nameColor, {
    Key? key,
  }) {
    return Padding(
      key: key,
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
