import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';

import '../../../../core/themes/textstyles.dart';
import '../../../controllers/Main%20Section%20Controllers/settings_controller.dart';
import '../../../core/helper/emote_parser.dart';
import '../../../core/widgets/custom_black_glass_widget.dart';
import '../../../services/emote_service.dart';
import 'live_stream_helper_widgets.dart';

class ChatBottomSection extends StatefulWidget {
  final ValueNotifier<bool> showServiceCard;
  final ValueNotifier<bool> showActivity;
  final ValueNotifier<String?> selectedPlatform;
  final ValueNotifier<bool> titleSelected;
  final ValueNotifier<String?> chatFilter;
  final Function(double delta)? onResize;
  final VoidCallback? onResizeEnd;
  final Function(bool swipeRight)? onPlatformSwipe;

  const ChatBottomSection({
    super.key,
    required this.showServiceCard,
    required this.showActivity,
    required this.selectedPlatform,
    required this.titleSelected,
    required this.chatFilter,
    this.onResize,
    this.onResizeEnd,
    this.onPlatformSwipe,
  });

  @override
  State<ChatBottomSection> createState() => _ChatBottomSectionState();
}

class _ChatBottomSectionState extends State<ChatBottomSection> {
  // Platform assets and colors
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

  // Platform colors - will be accessed dynamically
  late final SettingsController _settingsController;

  // Controllers and state
  late List<Map<String, dynamic>> _comments;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _expandedScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  StateSetter? _expandedSheetStateSetter;
  final filterController = Get.put(FilterController());

  // Emote service - initialized lazily
  late final EmoteService _emoteService;
  EmoteParser? _emoteParser;

  // Flag to prevent emoji picker from showing multiple times
  bool _emojiPickerScheduled = false;

  // Unicode emojis list
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

  @override
  void initState() {
    super.initState();

    // Initialize or get existing EmoteService
    _emoteService = Get.put(EmoteService());

    // Initialize SettingsController
    _settingsController = Get.find<SettingsController>();

    // Initialize sample comments
    _comments = [
      {
        'platform': 'assets/images/twitch1.png',
        'name': 'TwitchFan1',
        'message': 'KEKW Amazing play!',
      },
      {
        'platform': 'assets/images/twitch1.png',
        'name': 'TwitchFan2',
        'message': 'Wow, insane! catJAM',
      },
      {
        'platform': 'assets/images/kick.png',
        'name': 'KickFan1',
        'message': 'Lets goooo! POGGERS',
      },
      {
        'platform': 'assets/images/kick.png',
        'name': 'KickFan2',
        'message': 'Hyped for this! monkaS',
      },
      {
        'platform': 'assets/images/youtube1.png',
        'name': 'YTViewer1',
        'message': 'Nice content! PepeLaugh',
      },
      {
        'platform': 'assets/images/youtube1.png',
        'name': 'YTViewer2',
        'message': 'Love this! Sadge',
      },
    ];

    for (int i = 0; i < 10; i++) {
      _comments.add({
        'platform': 'assets/images/twitch1.png',
        'name': 'User$i',
        'message': 'Hello $i KEKW!',
      });
    }
    _comments.shuffle();

    // Listen for emote changes to update parser
    ever(_emoteService.emoteList, (_) {
      _updateEmoteParser();
    });

    // Initial parser setup
    _updateEmoteParser();

    // Auto-scroll to bottom on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(_mainScrollController, animate: false);
      _scrollToBottom(_expandedScrollController, animate: false);
    });
  }

  /// Update the emote parser when emotes change
  void _updateEmoteParser() {
    _emoteParser = EmoteParser(
      emoteUrlMap: _emoteService.emoteUrlMap,
      textStyle: sfProText400(12.sp, Colors.white),
      emoteSize: 28, // Increased size for better visibility
    );
    // Trigger rebuild to update existing messages
    if (mounted) setState(() {});
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
      Future.delayed(const Duration(milliseconds: 50), () {
        if (controller.hasClients) {
          _scrollToBottom(controller, animate: animate);
        }
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;

      final maxScroll = controller.position.maxScrollExtent;
      if (maxScroll > 0) {
        if (animate) {
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

    setState(() {
      _comments.add(item);
    });

    if (_expandedSheetStateSetter != null) {
      _expandedSheetStateSetter!(() {});
    }

    _messageController.clear();
    _focusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() {
        _scrollToBottomImmediate(_mainScrollController);
        _scrollToBottomImmediate(_expandedScrollController);
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottomImmediate(_mainScrollController);
        _scrollToBottomImmediate(_expandedScrollController);
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToBottomImmediate(_mainScrollController);
        _scrollToBottomImmediate(_expandedScrollController);
      });
    });
  }

  /// Send emote directly to chat (not to text field)
  void _sendEmoteDirectly(String emoteName) {
    String currentPlatform = widget.chatFilter.value ?? 'twitch';
    if (widget.chatFilter.value == null &&
        widget.selectedPlatform.value != null) {
      currentPlatform = widget.selectedPlatform.value!;
    }

    final platformAsset = _getPlatformAsset(currentPlatform);
    final item = {
      'platform': platformAsset,
      'name': 'You',
      'message': emoteName,
    };

    setState(() {
      _comments.add(item);
    });

    if (_expandedSheetStateSetter != null) {
      _expandedSheetStateSetter!(() {});
    }

    // Track recently used
    _emoteService.addToRecentlyUsed(emoteName);

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() {
        _scrollToBottomImmediate(_mainScrollController);
        _scrollToBottomImmediate(_expandedScrollController);
      });

      Future.delayed(const Duration(milliseconds: 100), () {
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
        controller.jumpTo(maxScroll);
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

  /// Show the tabbed emoji/emote picker
  void _showEmojiEmotePicker(BuildContext context, StateSetter? setSheetState) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width * 0.9;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final bottomInset = mediaQuery.viewPadding.bottom;
    final pickerHeight = 320.h;

    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: keyboardHeight + 70.h + bottomInset,
            ),
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: FadeTransition(
                opacity: animation,
                child: _EmojiEmotePickerDialog(
                  width: screenWidth,
                  height: pickerHeight,
                  emojis: _emojis,
                  emoteService: _emoteService,
                  onEmojiSelected: (emoji) {
                    // Emoji still goes to text field
                    final currentText = _messageController.text;
                    _messageController.value = TextEditingValue(
                      text: currentText + emoji,
                      selection: TextSelection.collapsed(
                        offset: currentText.length + emoji.length,
                      ),
                    );
                    Navigator.of(dialogContext).pop();
                    _focusNode.requestFocus();
                  },
                  onEmoteSelected: (emoteName) {
                    // Emote goes directly to chat
                    Navigator.of(dialogContext).pop();
                    _sendEmoteDirectly(emoteName);
                  },
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
              bottom: overlay.size.height - buttonPosition.dy - 25.h,
              right:
                  overlay.size.width -
                  (buttonPosition.dx + buttonSize.width) -
                  28.w,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: buttonSize.width + 40.w,
                    maxWidth: 200.w,
                  ),
                  child: CustomBlackGlassWidget(
                    items: const ["All", "Twitch", "Kick", "YouTube"],
                    isWeek: false,
                    onItemSelected: (selected) {
                      // Convert selection to filter value
                      String? filterValue;

                      if (selected.toLowerCase() == 'all') {
                        filterValue = null; // null means show all
                      } else {
                        filterValue =
                            selected
                                .toLowerCase(); // 'twitch', 'kick', 'youtube'
                      }

                      // Update the ValueNotifier's value
                      widget.chatFilter.value = filterValue;

                      // Update filter controller if needed
                      filterController.setFilter(selected);

                      // Trigger rebuild if sheet is open
                      if (setSheetState != null) {
                        setSheetState(() {});
                      }

                      // Also rebuild main widget
                      if (mounted) {
                        setState(() {});
                      }
                    },
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
    final bool isExpanded = setSheetState != null;

    return ValueListenableBuilder<String?>(
      valueListenable: widget.chatFilter,
      builder: (context, filter, _) {
        // If no filter is selected, show "All" without color
        if (filter == null) {
          return GestureDetector(
            onTap: () {
              if (isExpanded) {
                FocusScope.of(context).unfocus();
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (context.mounted) {
                    _showGlassmorphicPopupMenu(context, filter, setSheetState);
                  }
                });
              } else {
                _showGlassmorphicPopupMenu(context, filter, null);
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "All",
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
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
        }

        // When filter is selected, use Obx to track platform color changes
        return Obx(() {
          String label = "${filter[0].toUpperCase()}${filter.substring(1)}";
          Color labelColor;

          // Directly access observables for GetX to track them
          if (filter == 'twitch') {
            labelColor = _settingsController.twitchColor.value ?? twitchPurple;
          } else if (filter == 'kick') {
            labelColor = _settingsController.kickColor.value ?? kickGreen;
          } else if (filter == 'youtube') {
            labelColor = _settingsController.youtubeColor.value ?? youtubeRed;
          } else {
            labelColor = Colors.white;
          }

          return GestureDetector(
            onTap: () {
              if (isExpanded) {
                FocusScope.of(context).unfocus();
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (context.mounted) {
                    _showGlassmorphicPopupMenu(context, filter, setSheetState);
                  }
                });
              } else {
                _showGlassmorphicPopupMenu(context, filter, null);
              }
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
        });
      },
    );
  }

  /// Build chat message with emote parsing
  Widget _chatItem(
    String platform,
    String name,
    String message,
    Color nameColor, {
    Key? key,
  }) {
    // Parse message for emotes
    final List<InlineSpan> messageSpans =
        _emoteParser?.parse(message) ??
        [TextSpan(text: message, style: sfProText400(12.sp, Colors.white))];

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
                    // Platform icon
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
                    // Username
                    TextSpan(
                      text: "$name: ",
                      style: sfProText500(12.sp, nameColor),
                    ),
                    // Message with emotes
                    ...messageSpans,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Opens expanded chat normally (without emoji picker)
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
            _expandedSheetStateSetter = setSheetState;
            return _buildExpandedChatContent(context, setSheetState);
          },
        );
      },
    ).whenComplete(() {
      _expandedSheetStateSetter = null;
    });
  }

  /// Opens expanded chat and automatically shows emoji picker (only once)
  void _openExpandedChatWithEmoji(BuildContext context) {
    // Reset the flag before opening
    _emojiPickerScheduled = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: null,
      useSafeArea: true,
      builder: (ctx) {
        // Schedule emoji picker ONCE here, outside of StatefulBuilder
        if (!_emojiPickerScheduled) {
          _emojiPickerScheduled = true;
          Future.delayed(const Duration(milliseconds: 400), () {
            if (ctx.mounted && _expandedSheetStateSetter != null) {
              _showEmojiEmotePicker(ctx, _expandedSheetStateSetter);
            }
          });
        }

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            _expandedSheetStateSetter = setSheetState;
            return _buildExpandedChatContent(context, setSheetState);
          },
        );
      },
    ).whenComplete(() {
      _expandedSheetStateSetter = null;
      _emojiPickerScheduled = false;
    });
  }

  /// Builds the expanded chat content (shared between normal and emoji-trigger open)
  Widget _buildExpandedChatContent(
    BuildContext context,
    StateSetter setSheetState,
  ) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return FractionallySizedBox(
      heightFactor: 1.0,
      child: AnimatedPadding(
        padding: EdgeInsets.only(bottom: bottomInset),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            color: black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
          ),
          child: SafeArea(
            bottom: false,
            child: GestureDetector(
              onTap: () {
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
                  // Header buttons
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Row(
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: widget.titleSelected,
                          builder: (context, val, _) {
                            return GestureDetector(
                              onTap: () {
                                final newVal = !val;
                                widget.titleSelected.value = newVal;
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
                        SizedBox(width: 12.w),
                        ValueListenableBuilder<bool>(
                          valueListenable: widget.showActivity,
                          builder: (context, active, _) {
                            return GestureDetector(
                              onTap: () {
                                final newVal = !active;
                                widget.showActivity.value = newVal;
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
                  // Chat list
                  Expanded(
                    child: GestureDetector(
                      onHorizontalDragEnd:
                          widget.onPlatformSwipe != null
                              ? (details) {
                                // Determine swipe direction based on velocity
                                const swipeThreshold =
                                    100.0; // Minimum velocity to trigger swipe
                                if (details.primaryVelocity != null) {
                                  if (details.primaryVelocity! >
                                      swipeThreshold) {
                                    // Swipe right
                                    widget.onPlatformSwipe!(true);
                                  } else if (details.primaryVelocity! <
                                      -swipeThreshold) {
                                    // Swipe left
                                    widget.onPlatformSwipe!(false);
                                  }
                                }
                              }
                              : null,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: ValueListenableBuilder<String?>(
                          valueListenable: widget.chatFilter,
                          builder: (context, filter, child) {
                            final filteredList = _getFilteredComments(filter);
                            return ListView.builder(
                              key: ValueKey(
                                'expanded_chat_${_comments.length}_${filter ?? 'all'}',
                              ),
                              controller: _expandedScrollController,
                              padding: EdgeInsets.only(
                                bottom:
                                    16.h +
                                    20.h +
                                    bottomInset,
                              ),
                              itemCount: filteredList.length,
                              reverse: false,
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: false,
                              itemBuilder: (context, index) {
                                final item = filteredList[index];
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
                  ),
                  // Input field
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.fromLTRB(
                      16.w,
                      8.h,
                      16.w,
                      16.h,
                    ),
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
                                child: TextField(
                                  controller: _messageController,
                                  focusNode: _focusNode,
                                  style: sfProText400(17.sp, Colors.white),
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
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              // Emoji icon - shows emoji picker when tapped
                              GestureDetector(
                                onTap: () {
                                  _showEmojiEmotePicker(context, setSheetState);
                                },
                                child: SizedBox(
                                  height: 20.h,
                                  width: 20.w,
                                  child: Image.asset('assets/images/smile.png'),
                                ),
                              ),
                              SizedBox(width: 9.w),
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
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
      },
      // Allow swiping anywhere on the sheet to resize
      onVerticalDragUpdate:
          widget.onResize != null
              ? (details) {
                widget.onResize!(details.delta.dy);
              }
              : null,
      onVerticalDragEnd:
          widget.onResizeEnd != null
              ? (_) {
                widget.onResizeEnd!();
              }
              : null,
      onVerticalDragStart: (_) {
        // Optional: Add haptic feedback or visual feedback on drag start
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        ),
        child: Column(
          children: [
            SizedBox(height: 10.h),
            // Visual drag handle bar (no longer requires exact tap on bar)
            Container(
              padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 20.w),
              child: Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Row(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.titleSelected,
                    builder: (context, val, _) {
                      return GestureDetector(
                        onTap: () {
                          final newVal = !val;
                          widget.titleSelected.value = newVal;
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
                  SizedBox(width: 12.w),
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.showActivity,
                    builder: (context, active, _) {
                      return GestureDetector(
                        onTap: () {
                          final newVal = !active;
                          widget.showActivity.value = newVal;
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
              child: GestureDetector(
                onHorizontalDragEnd:
                    widget.onPlatformSwipe != null
                        ? (details) {
                          // Determine swipe direction based on velocity
                          const swipeThreshold =
                              100.0; // Minimum velocity to trigger swipe
                          if (details.primaryVelocity != null) {
                            if (details.primaryVelocity! > swipeThreshold) {
                              // Swipe right
                              widget.onPlatformSwipe!(true);
                            } else if (details.primaryVelocity! <
                                -swipeThreshold) {
                              // Swipe left
                              widget.onPlatformSwipe!(false);
                            }
                          }
                        }
                        : null,
                child: Stack(
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: widget.chatFilter,
                      builder: (context, filter, child) {
                        final filteredList = _getFilteredComments(filter);
                        final keyboardHeight =
                            MediaQuery.of(context).viewInsets.bottom;
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
                                  'main_${item['name']}_${index}_${item['message']}',
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    // Main view input bar (16.h above bottom; parent reserves nav bar space)
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
                                  // Emoji icon - opens expanded chat WITH emoji picker
                                  GestureDetector(
                                    onTap: () {
                                      _openExpandedChatWithEmoji(context);
                                    },
                                    child: SizedBox(
                                      height: 20.h,
                                      width: 20.w,
                                      child: Image.asset(
                                        'assets/images/smile.png',
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 9.w),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Tabbed Emoji/Emote Picker Dialog
class _EmojiEmotePickerDialog extends StatefulWidget {
  final double width;
  final double height;
  final List<String> emojis;
  final EmoteService emoteService;
  final Function(String) onEmojiSelected;
  final Function(String) onEmoteSelected;

  const _EmojiEmotePickerDialog({
    required this.width,
    required this.height,
    required this.emojis,
    required this.emoteService,
    required this.onEmojiSelected,
    required this.onEmoteSelected,
  });

  @override
  State<_EmojiEmotePickerDialog> createState() =>
      _EmojiEmotePickerDialogState();
}

class _EmojiEmotePickerDialogState extends State<_EmojiEmotePickerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: widget.width,
            constraints: BoxConstraints(maxHeight: widget.height),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(20.r),
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
            child: Column(
              children: [
                // Search bar (only show when on emotes tab)
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, child) {
                    final showSearch = _tabController.index >= 2;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: showSearch ? 50.h : 0,
                      child:
                          showSearch
                              ? Padding(
                                padding: EdgeInsets.fromLTRB(
                                  12.w,
                                  8.h,
                                  12.w,
                                  4.h,
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search emotes...',
                                    hintStyle: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 14.sp,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Colors.white38,
                                      size: 20.sp,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.1),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 8.h,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value;
                                    });
                                  },
                                ),
                              )
                              : const SizedBox.shrink(),
                    );
                  },
                ),

                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 2,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    dividerColor: Colors.transparent,
                    labelPadding: EdgeInsets.symmetric(horizontal: 4.w),
                    labelStyle: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: [
                      const Tab(text: 'Emoji'),
                      const Tab(text: '⭐ Recent'),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/twitch1.png',
                              width: 16.sp,
                              height: 16.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'Twitch',
                              style: TextStyle(color: twitchPurple),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/kick.png',
                              width: 16.sp,
                              height: 16.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text('Kick', style: TextStyle(color: kickGreen)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Unicode Emojis tab
                      _buildEmojiGrid(),

                      // Recent emotes tab
                      _buildRecentEmotesGrid(),

                      // 7TV Emotes tab (Twitch)
                      _build7TVEmotesGrid(),

                      // Kick Emotes tab (same as Twitch/7TV)
                      _build7TVEmotesGrid(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiGrid() {
    const int cols = 7;
    final int rows = (widget.emojis.length / cols).ceil();

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(12.w),
      itemCount: rows,
      separatorBuilder: (context, index) => SizedBox(height: 8.h),
      itemBuilder: (context, rowIndex) {
        return Row(
          children: List.generate(cols, (colIndex) {
            final idx = rowIndex * cols + colIndex;
            if (idx >= widget.emojis.length) {
              return const Expanded(child: SizedBox.shrink());
            }

            final emoji = widget.emojis[idx];
            return Expanded(
              child: GestureDetector(
                onTap: () => widget.onEmojiSelected(emoji),
                child: Container(
                  height: 38.h,
                  alignment: Alignment.center,
                  child: Text(emoji, style: TextStyle(fontSize: 24.sp)),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildRecentEmotesGrid() {
    return Obx(() {
      final recentEmotes = widget.emoteService.getRecentEmotes();

      if (recentEmotes.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, color: Colors.white38, size: 48.sp),
              SizedBox(height: 12.h),
              Text(
                'No recent emotes',
                style: TextStyle(color: Colors.white38, fontSize: 14.sp),
              ),
              SizedBox(height: 4.h),
              Text(
                'Emotes you use will appear here',
                style: TextStyle(color: Colors.white24, fontSize: 12.sp),
              ),
            ],
          ),
        );
      }

      return _buildEmoteGridView(recentEmotes);
    });
  }

  Widget _build7TVEmotesGrid() {
    return Obx(() {
      if (widget.emoteService.isLoading.value &&
          widget.emoteService.emoteList.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 32.sp,
                height: 32.sp,
                child: const CircularProgressIndicator(
                  color: Colors.white54,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Loading emotes...',
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
              ),
            ],
          ),
        );
      }

      if (widget.emoteService.hasError.value &&
          widget.emoteService.emoteList.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade300,
                size: 48.sp,
              ),
              SizedBox(height: 12.h),
              Text(
                'Failed to load emotes',
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
              ),
              SizedBox(height: 8.h),
              GestureDetector(
                onTap: () => widget.emoteService.fetchEmotes(),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Filter emotes based on search query
      final emotes =
          _searchQuery.isEmpty
              ? widget.emoteService.emoteList.toList()
              : widget.emoteService.searchEmotes(_searchQuery);

      if (emotes.isEmpty) {
        return Center(
          child: Text(
            'No emotes found',
            style: TextStyle(color: Colors.white38, fontSize: 14.sp),
          ),
        );
      }

      return _buildEmoteGridView(emotes);
    });
  }

  Widget _buildEmoteGridView(List<Emote> emotes) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(8.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 4.w,
        mainAxisSpacing: 4.h,
        childAspectRatio: 1,
      ),
      itemCount: emotes.length,
      itemBuilder: (context, index) {
        final emote = emotes[index];
        return Tooltip(
          message: emote.name,
          preferBelow: false,
          waitDuration: const Duration(milliseconds: 500),
          child: GestureDetector(
            onTap: () => widget.onEmoteSelected(emote.name),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8.r),
              ),
              padding: EdgeInsets.all(4.w),
              child: CachedNetworkImage(
                imageUrl: emote.url,
                fit: BoxFit.contain,
                placeholder:
                    (context, url) => Center(
                      child: SizedBox(
                        width: 16.sp,
                        height: 16.sp,
                        child: const CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Center(
                      child: Text(
                        emote.name.length > 2
                            ? emote.name.substring(0, 2)
                            : emote.name,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10.sp,
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
}

/// Filter controller
class FilterController extends GetxController {
  final RxString currentFilter = 'All'.obs;

  void setFilter(String value) {
    currentFilter.value = value;
    Get.back();
  }
}
