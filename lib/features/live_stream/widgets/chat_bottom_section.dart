import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/themes/textstyles.dart';
import '../../../core/widgets/custom_black_glass_widget.dart';
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
  StateSetter? _expandedSheetStateSetter;

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
      Future.delayed(const Duration(milliseconds: 50), () {
        if (controller.hasClients) {
          _scrollToBottom(controller, animate: animate);
        }
      });
      return;
    }

    // Wait for layout to update, then scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;

      final maxScroll = controller.position.maxScrollExtent;
      if (maxScroll > 0) {
        if (animate) {
          // Smooth animation for better feel
          controller.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        } else {
          controller.jumpTo(maxScroll);
        }
      }
    });
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

    // Also trigger rebuild in expanded sheet if it's open
    if (_expandedSheetStateSetter != null) {
      _expandedSheetStateSetter!(() {
        // Rebuild expanded sheet
      });
    }

    // Clear text field but keep keyboard open
    _messageController.clear();

    // Keep focus on text field (keyboard stays open)
    _focusNode.requestFocus();

    // Force scroll after multiple frames to ensure keyboard layout is accounted for
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // First attempt - immediate scroll
      Future.microtask(() {
        _scrollToBottomImmediate(_mainScrollController);
        _scrollToBottomImmediate(_expandedScrollController);
      });

      // Second attempt - after layout phase
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottomImmediate(_mainScrollController);
        _scrollToBottomImmediate(_expandedScrollController);
      });

      // Third attempt - after keyboard insets stabilize
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToBottomImmediate(_mainScrollController);
        _scrollToBottomImmediate(_expandedScrollController);
      });
    });
  }

  void _scrollToBottomImmediate(ScrollController controller) {
    if (!controller.hasClients) return;

    try {
      final maxScroll = controller.position.maxScrollExtent;
      if (maxScroll > 0) {
        // Use jumpTo for immediate scroll, then animate for smoothness
        controller.jumpTo(maxScroll);
        // Smooth scroll after jump
        Future.delayed(const Duration(milliseconds: 50), () {
          if (controller.hasClients &&
              controller.position.maxScrollExtent > 0) {
            controller.animateTo(
              controller.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      // Silent fail if scroll position is invalid
    }
  }

  static const List<String> _emojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '🤣',
    '😂',
    '🙂',
    '🙃',
    '😉',
    '😊',
    '😇',
    '🥰',
    '😍',
    '🤩',
    '😘',
    '😗',
    '😚',
    '😙',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '🤐',
    '🤨',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '🤥',
    '😌',
    '😔',
    '😪',
    '🤤',
    '😴',
    '😷',
    '🤒',
    '🤕',
    '🤢',
    '🤮',
    '👍',
    '👎',
    '👌',
    '✌️',
    '🤞',
    '🤟',
    '🤘',
    '👏',
    '🙌',
    '👐',
    '❤️',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🤎',
    '💔',
    '❣️',
    '💕',
    '💞',
    '💓',
    '💗',
    '💖',
    '💘',
    '💝',
    '💟',
    '☮️',
    '✝️',
  ];

  void _showEmojiPicker(BuildContext context, StateSetter? setSheetState) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenWidth = mediaQuery.size.width * 0.8;
    final double keyboardHeight = mediaQuery.viewInsets.bottom;

    // Position above text input (accounting for keyboard)
    final double emojiPickerHeight = 250.h;

    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboardHeight + 75.h),
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: FadeTransition(
                opacity: animation,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20.r),
                    bottom: Radius.circular(20.r),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      width: screenWidth,
                      constraints: BoxConstraints(maxHeight: emojiPickerHeight),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.black.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20.r),
                          bottom: Radius.circular(20.r),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.18),
                            width: 1.0.w,
                          ),
                          left: BorderSide(
                            color: Colors.white.withOpacity(0.18),
                            width: 1.0.w,
                          ),
                          right: BorderSide(
                            color: Colors.white.withOpacity(0.18),
                            width: 1.0.w,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 16.w,
                          right: 16.w,
                          top: 6.h,
                          bottom: 10.h,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const int cols = 7;
                            final int rows = (_emojis.length / cols).ceil();

                            Widget emojiCell(String emoji) {
                              return GestureDetector(
                                onTap: () {
                                  final currentText = _messageController.text;
                                  final newText = currentText + emoji;
                                  _messageController.value = TextEditingValue(
                                    text: newText,
                                    selection: TextSelection.collapsed(
                                      offset: newText.length,
                                    ),
                                  );
                                  Navigator.of(context).pop();
                                  _focusNode.requestFocus();
                                },
                                child: SizedBox(
                                  height: 38.h,
                                  child: Center(
                                    child: Text(
                                      emoji,
                                      style: TextStyle(
                                        fontSize: 28.sp,
                                        decoration: TextDecoration.none,
                                      ),
                                      textHeightBehavior:
                                          const TextHeightBehavior(
                                            applyHeightToFirstAscent: false,
                                            applyHeightToLastDescent: false,
                                          ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            Widget rowDivider() {
                              // "Glass" divider: thin, subtle, semi-transparent line
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 8.h,
                                ),
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 8,
                                      sigmaY: 8,
                                    ),
                                    child: Container(
                                      height: 1.h,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.12),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: rows,
                              separatorBuilder: (context, index) =>
                                  rowDivider(),
                              itemBuilder: (context, rowIndex) {
                                return Row(
                                  children: List.generate(cols, (colIndex) {
                                    final idx = rowIndex * cols + colIndex;
                                    return Expanded(
                                      child: idx < _emojis.length
                                          ? emojiCell(_emojis[idx])
                                          : const SizedBox.shrink(),
                                    );
                                  }),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGlassmorphicPopupMenu(
    BuildContext context,
    String? currentFilter,
    StateSetter? setSheetState,
  ) {
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final RenderBox? button = context.findRenderObject() as RenderBox?;

    if (button == null || overlay == null) return;

    final Offset buttonPosition = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;

    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: buttonPosition.dy - 136.h - 8.h,
              right: overlay.size.width - buttonPosition.dx - 60.w,
              child: Material(
                color: Colors.transparent,
                child: IntrinsicWidth(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // Minimum width to match button
                      minWidth: buttonSize.width,
                      // Maximum width to prevent going off-screen on the left
                      maxWidth: buttonPosition.dx + buttonSize.width - 20.w,
                    ),
                    child: CustomBlackGlassWidget(
                      items: const ["All", "Twitch", "Kick", "YouTube"],
                      isWeek: false,
                      onItemSelected: (selected) {
                        // Handle selection
                        Navigator.of(context).pop();
                        if (setSheetState != null) {
                          setSheetState(() {
                            currentFilter = selected;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
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

        return GestureDetector(
          onTap: () {
            _showGlassmorphicPopupMenu(context, filter, setSheetState);
          },
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
        );
      },
    );
  }

  void _openExpandedChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: null,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            // Store reference to setSheetState so _sendMessage can trigger rebuild
            _expandedSheetStateSetter = setSheetState;

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
                                        // If Activity is turned on, turn off Title
                                        if (newVal) {
                                          widget.titleSelected.value = false;
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
                                        // If Title is turned on, turn off Activity
                                        if (newVal) {
                                          widget.showActivity.value = false;
                                        }
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
                                    padding: EdgeInsets.only(
                                      bottom: 16.h + 20.h,
                                    ),
                                    itemCount: filteredList.length,
                                    reverse: false,
                                    addAutomaticKeepAlives: false,
                                    addRepaintBoundaries: false,
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
                                          'expanded_${item['name']}_${index}_${item['message']}',
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
                                  sigmaX: 15,
                                  sigmaY: 15,
                                ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                  ),
                                  height: 55.h,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.black.withOpacity(0.4),
                                        Colors.black.withOpacity(0.2),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(25.r),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.18),
                                      width: 1.0.w,
                                    ),
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
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            disabledBorder: InputBorder.none,
                                            filled: true,
                                            fillColor: Colors.transparent,
                                            contentPadding: EdgeInsets.zero,
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
                                      GestureDetector(
                                        onTap: () {
                                          _showEmojiPicker(
                                            context,
                                            setSheetState,
                                          );
                                        },
                                        child: Icon(
                                          Icons.sentiment_satisfied_sharp,
                                          color: Colors.white,
                                          size: 24.sp,
                                        ),
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
    ).whenComplete(() {
      // Clear reference when sheet is dismissed
      _expandedSheetStateSetter = null;
    });
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
                          // If Activity is turned on, turn off Title
                          if (newVal) {
                            widget.titleSelected.value = false;
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
                          // If Title is turned on, turn off Activity
                          if (newVal) {
                            widget.showActivity.value = false;
                          }
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
                      final keyboardHeight = MediaQuery.of(
                        context,
                      ).viewInsets.bottom;
                      return AnimatedPadding(
                        padding: EdgeInsets.only(bottom: keyboardHeight),
                        duration: const Duration(milliseconds: 100),
                        child: ListView.builder(
                          key: ValueKey(
                            'main_chat_${_comments.length}_${filter ?? 'all'}',
                          ),
                          controller: _mainScrollController,
                          padding: EdgeInsets.only(
                            left: 16.w,
                            right: 16.w,
                            bottom: 80.h + 20.h,
                          ),
                          itemCount: filteredList.length,
                          reverse: false,
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: false,
                          shrinkWrap: false,
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
                              key: ValueKey(
                                'main_${item['name']}_${index}_${item['message']}',
                              ),
                            );
                          },
                        ),
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
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            height: 55.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.black.withOpacity(0.4),
                                  Colors.black.withOpacity(0.2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25.r),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                                width: 1.0.w,
                              ),
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
                                GestureDetector(
                                  onTap: () {
                                    _showEmojiPicker(context, null);
                                  },
                                  child: Icon(
                                    Icons.sentiment_satisfied_alt_outlined,
                                    color: Colors.white,
                                    size: 24.sp,
                                  ),
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
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: Padding(
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
                    TextSpan(
                      text: "$name: ",
                      style: sfProText500(12.sp, nameColor),
                    ),
                    TextSpan(
                      text: message,
                      style: sfProText400(12.sp, Colors.white),
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
}
