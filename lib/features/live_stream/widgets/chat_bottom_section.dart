import 'dart:ui';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/controllers/chat_controller.dart';
import 'package:second_chat/core/localization/l10n.dart';
import '../../../../core/themes/textstyles.dart';
import '../../../controllers/Main%20Section%20Controllers/settings_controller.dart';
import '../../../core/helper/emote_parser.dart';
import '../../../core/widgets/custom_black_glass_widget.dart';
import '../../../data/models/chat_message.dart';
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
  /// Called before Title/Activity pills change the overlay; parent can collapse expanded activity.
  final VoidCallback? onOverlayViewChange;

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
    this.onOverlayViewChange,
  });

  @override
  State<ChatBottomSection> createState() => _ChatBottomSectionState();
}

class _ChatBottomSectionState extends State<ChatBottomSection>
    with WidgetsBindingObserver {
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
  late final ChatController _chatCtrl;
  late List<Map<String, dynamic>> _comments;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _expandedScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  StateSetter? _expandedSheetStateSetter;
  final filterController = Get.put(FilterController());
  Worker? _scrollWorker;
  Worker? _embedReadyWorker;

  // Emote service - initialized lazily
  late final EmoteService _emoteService;
  EmoteParser? _emoteParser;

  // Flag to prevent emoji picker from showing multiple times
  bool _emojiPickerScheduled = false;
  final Map<String, double> _lastInsetLogs = {};
  double _keyboardInset = 0.0;

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
    WidgetsBinding.instance.addObserver(this);

    _chatCtrl = Get.find<ChatController>();

    // Initialize or get existing EmoteService
    _emoteService = Get.put(EmoteService());

    // Initialize SettingsController
    _settingsController = Get.find<SettingsController>();

    // Keep local list as a fallback; primary source is ChatController.messages.
    _comments = <Map<String, dynamic>>[];

    // Listen for emote changes to update parser
    ever(_emoteService.emoteList, (_) {
      _updateEmoteParser();
    });

    // Initial parser setup
    _updateEmoteParser();

    // Auto-scroll to bottom on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleReliableScrollToBottom(animate: false);
    });

    // Scroll trigger driven by controller updates (no UI layout change).
    _scrollWorker = ever<int>(_chatCtrl.scrollTick, (_) {
      _scheduleReliableScrollToBottom(animate: true);
    });

    _embedReadyWorker = ever<Map<String, bool>>(
      _chatCtrl.platformStreamEmbedReady,
          (_) {
        if (mounted) {
          _scheduleReliableScrollToBottom(animate: false);
        }
      },
    );

    _focusNode.addListener(_onFocusChanged);
    widget.chatFilter.addListener(_syncFilterLabelFromChatFilter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFilterLabelFromChatFilter();
    });
    _log('initState completed');
  }

  /// Keeps [FilterController] label aligned with swipe / viewer-count changes.
  void _syncFilterLabelFromChatFilter() {
    final raw = widget.chatFilter.value?.trim();
    final String label;
    if (raw == null || raw.isEmpty) {
      label = 'All';
    } else {
      final k = raw.toLowerCase();
      if (k == 'twitch') {
        label = 'Twitch';
      } else if (k == 'kick') {
        label = 'Kick';
      } else if (k == 'youtube') {
        label = 'YouTube';
      } else {
        label = raw.length == 1
            ? raw.toUpperCase()
            : '${raw[0].toUpperCase()}${raw.substring(1).toLowerCase()}';
      }
    }
    if (filterController.currentFilter.value != label) {
      filterController.currentFilter.value = label;
    }
    _expandedSheetStateSetter?.call(() {});
    if (mounted) setState(() {});
  }

  String _apiPlatformForSend(String raw) {
    final k = raw.toLowerCase().trim();
    if (k.contains('kick')) return 'kick';
    if (k.contains('youtube') || k == 'yt' || k.contains('google')) {
      return 'youtube';
    }
    return 'twitch';
  }

  /// When [platformLive] has an entry for this platform and it is not live.
  bool _streamOffForSendTarget(String currentPlatform) {
    final key = _apiPlatformForSend(currentPlatform);
    final map = _chatCtrl.platformLive;
    if (map.isEmpty) return false;
    if (!map.containsKey(key)) return false;
    return map[key] != true;
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
    widget.chatFilter.removeListener(_syncFilterLabelFromChatFilter);
    _focusNode.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    _scrollWorker?.dispose();
    _embedReadyWorker?.dispose();
    _messageController.dispose();
    _mainScrollController.dispose();
    _expandedScrollController.dispose();
    _focusNode.dispose();
    _log('dispose called');
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final keyboardInset = view.viewInsets.bottom / view.devicePixelRatio;
    _keyboardInset = keyboardInset;
    _logInsetChange('metrics.keyboardInset', keyboardInset);
    if (mounted) {
      setState(() {});
      _expandedSheetStateSetter?.call(() {});
    }
  }

  void _onFocusChanged() {
    final inset = MediaQuery.maybeOf(context)?.viewInsets.bottom ?? 0.0;
    _log(
      'focus changed: hasFocus=${_focusNode.hasFocus}, '
          'hasPrimaryFocus=${_focusNode.hasPrimaryFocus}, '
          'keyboardInset.mediaQuery=$inset, keyboardInset.metrics=$_keyboardInset',
    );
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ChatBottomSection] $message');
    }
  }

  void _logInsetChange(String key, double value) {
    final prev = _lastInsetLogs[key];
    if (prev == null || (prev - value).abs() > 0.5) {
      _lastInsetLogs[key] = value;
      _log('$key=$value');
    }
  }

  /// ListView [maxScrollExtent] often updates one or two frames after data changes — a single
  /// [jumpTo]/[animateTo] can run too early and leave the list mid-scroll.
  /// Expanded chat may not be built yet; each controller is scrolled only if [hasClients].
  void _scheduleReliableScrollToBottom({required bool animate}) {
    void apply(ScrollController c) {
      if (!c.hasClients) return;
      try {
        final maxScroll = c.position.maxScrollExtent;
        if (!maxScroll.isFinite) return;
        if (animate) {
          c.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        } else {
          c.jumpTo(maxScroll);
        }
      } catch (_) {}
    }

    void applyBoth() {
      apply(_mainScrollController);
      apply(_expandedScrollController);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      applyBoth();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        applyBoth();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          applyBoth();
        });
      });
    });

    Future<void>.delayed(const Duration(milliseconds: 48), () {
      if (!mounted) return;
      applyBoth();
    });
    Future<void>.delayed(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      applyBoth();
    });
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      applyBoth();
    });
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      applyBoth();
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

  bool _isMessageFromCurrentUser(ChatMessage message) {
    final platformKey = message.platform.toLowerCase().trim();
    final ownPlatformUsername =
        (_chatCtrl.platformChatUsernames[platformKey] ?? '').trim().toLowerCase();
    final sender = message.userName.trim().toLowerCase();
    if (sender.isEmpty) return false;
    if (sender == 'you') return true;
    return ownPlatformUsername.isNotEmpty && sender == ownPlatformUsername;
  }

  List<Map<String, dynamic>> _commentsWithNamePrivacy(bool hideNames) {
    if (!hideNames) return List<Map<String, dynamic>>.from(_comments);
    return _comments
        .map(
          (e) => Map<String, dynamic>.from(e)..['name'] = '',
    )
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _getFilteredComments(String? filter) {
    // Obx callers depend on reading these reactives here.
    final hideNames = _settingsController.hideViewerNames.value;
    _settingsController.multiChatMergedMode.value;
    // Trigger reactive reads from RxMaps
    _chatCtrl.platformMessages.keys;
    _chatCtrl.platformLive.keys;
    _chatCtrl.platformStreamEmbedReady.keys;

    final normalizedFilter = filter?.toLowerCase().trim();
    final rows = <Map<String, dynamic>>[];

    void addRow(ChatMessage m) {
      final key = (m.platform).toLowerCase().trim();
      final canonicalId = m.canonicalId?.trim();
      rows.add({
        'platformKey': key,
        'canonicalId': canonicalId,
        'platform': _getPlatformAsset(key),
        'isCurrentUser': _isMessageFromCurrentUser(m),
        'name': hideNames ? '' : m.userName,
        'message': m.message,
        'embeddedEmotes': EmoteParser.embeddedEmotesFromRaw(m.raw),
        'socketEmoteOverrides': EmoteParser.socketEmoteNameOverrides(m.raw),
        '_ts': m.timestamp,
      });
    }

    if (normalizedFilter == null || normalizedFilter.isEmpty) {
      // "All" should always merge all platform histories + live socket lines.
      for (final entry in _chatCtrl.platformMessages.entries) {
        for (final m in entry.value.where(ChatController.isMainChatFeedLine)) {
          if (!_chatCtrl.isPlatformStreamEmbedReadyForChat(m.platform)) {
            continue;
          }
          addRow(m);
        }
      }
    } else {
      final list = _chatCtrl.platformMessages[normalizedFilter];
      if (list != null && list.isNotEmpty) {
        for (final m in list.where(ChatController.isMainChatFeedLine)) {
          if (!_chatCtrl.isPlatformStreamEmbedReadyForChat(m.platform)) {
            continue;
          }
          addRow(m);
        }
      } else {
        // Safe fallback while platform cache warms.
        for (final m in _chatCtrl.messages.where(ChatController.isMainChatFeedLine)) {
          if (!_chatCtrl.isPlatformStreamEmbedReadyForChat(m.platform)) {
            continue;
          }
          addRow(m);
        }
      }
    }

    if (rows.isEmpty) {
      return const [];
    }

    rows.sort((a, b) => (a['_ts'] as DateTime).compareTo(b['_ts'] as DateTime));

    // Final UI-level guard: prevent duplicate rendering when backend/socket/history
    // provide the same logical message row multiple times.
    final uniqueRows = <Map<String, dynamic>>[];
    final seenCanonical = <String>{};
    final seenFallback = <String>{};
    for (final row in rows) {
      final platformKey = (row['platformKey'] ?? '').toString();
      final canonical = (row['canonicalId'] ?? '').toString().trim();
      if (canonical.isNotEmpty) {
        final key = '$platformKey|$canonical';
        if (!seenCanonical.add(key)) continue;
      } else {
        final ts = row['_ts'] as DateTime;
        final message = (row['message'] ?? '').toString().trim();
        final name = (row['name'] ?? '').toString().trim().toLowerCase();
        final fallbackKey =
            '$platformKey|${ts.toUtc().millisecondsSinceEpoch}|$name|$message';
        if (!seenFallback.add(fallbackKey)) continue;
      }
      uniqueRows.add(row);
    }
    rows
      ..clear()
      ..addAll(uniqueRows);

    for (final row in rows) {
      row.remove('_ts');
    }

    // If no streams are live, hide chat entirely.
    if (_chatCtrl.platformLive.isNotEmpty &&
        !_chatCtrl.platformLive.values.any((v) => v == true)) {
      return const [];
    }

    if (normalizedFilter == null || normalizedFilter.isEmpty) {
      // Keep "All" scoped to currently live platforms when live-map is known.
      if (_chatCtrl.platformLive.isNotEmpty) {
        return rows
            .where(
              (item) {
            final pk = (item['platformKey'] ?? '').toString();
            return _chatCtrl.isPlatformLive(pk) &&
                _chatCtrl.isPlatformStreamEmbedReadyForChat(pk);
          },
        )
            .toList(growable: false);
      }
      return rows;
    }

    // Live platform: wait for embed WebView before showing chat.
    if (_chatCtrl.platformLive.isNotEmpty &&
        _chatCtrl.isPlatformLive(normalizedFilter) &&
        !_chatCtrl.isPlatformStreamEmbedReadyForChat(normalizedFilter)) {
      return const [];
    }

    // If selected platform is offline, hide messages.
    if (_chatCtrl.platformLive.isNotEmpty &&
        !_chatCtrl.isPlatformLive(normalizedFilter)) {
      return const [];
    }
    return rows
        .where((item) => (item['platformKey'] ?? '').toString() == normalizedFilter)
        .toList(growable: false);
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final selectedFilter = widget.chatFilter.value?.toLowerCase().trim();
    final bool isAllSelected = selectedFilter == null || selectedFilter.isEmpty;
    String currentPlatform = selectedFilter ?? 'twitch';
    if (isAllSelected && widget.selectedPlatform.value != null) {
      currentPlatform = widget.selectedPlatform.value!.toLowerCase().trim();
    }
    final authPlatform = _chatCtrl.platform.value.toLowerCase().trim().isEmpty
        ? 'twitch'
        : _chatCtrl.platform.value.toLowerCase().trim();

    if (!isAllSelected && _streamOffForSendTarget(currentPlatform)) {
      _messageController.clear();
      return;
    }
    _chatCtrl.sendMessage(
      text,
      platformForApi: isAllSelected ? 'all' : currentPlatform,
      authPlatform: authPlatform,
    );

    _messageController.clear();
    _focusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleReliableScrollToBottom(animate: false);
    });
  }

  /// Send emote directly to chat (not to text field)
  void _sendEmoteDirectly(
    String emoteName, {
    String? forcePlatform,
  }) {
    final forced = forcePlatform?.toLowerCase().trim();
    final forceTwitch = forced == 'twitch';
    final selectedFilter = widget.chatFilter.value?.toLowerCase().trim();
    final bool isAllSelected =
        !forceTwitch && (selectedFilter == null || selectedFilter.isEmpty);
    String currentPlatform = forceTwitch ? 'twitch' : (selectedFilter ?? 'twitch');
    if (!forceTwitch && isAllSelected && widget.selectedPlatform.value != null) {
      currentPlatform = widget.selectedPlatform.value!.toLowerCase().trim();
    }
    final authPlatform = forceTwitch
        ? 'twitch'
        : (_chatCtrl.platform.value.toLowerCase().trim().isEmpty
            ? 'twitch'
            : _chatCtrl.platform.value.toLowerCase().trim());

    if (!isAllSelected && _streamOffForSendTarget(currentPlatform)) {
      return;
    }
    _chatCtrl.sendMessage(
      emoteName,
      platformForApi: isAllSelected ? 'all' : currentPlatform,
      authPlatform: authPlatform,
    );

    // Track recently used
    _emoteService.addToRecentlyUsed(emoteName);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleReliableScrollToBottom(animate: false);
    });
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
                  onEmoteSelected: (emoteName, sourcePlatform) {
                    // Emote goes directly to chat
                    Navigator.of(dialogContext).pop();
                    _sendEmoteDirectly(
                      emoteName,
                      forcePlatform: sourcePlatform,
                    );
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
                child: CustomBlackGlassWidget(
                  items: [
                    context.l10n.all,
                    'Twitch',
                    'Kick',
                    'YouTube',
                  ],
                  isWeek: false,
                  initialSelectedItem: (() {
                    final f = currentFilter?.toLowerCase().trim();
                    if (f == null || f.isEmpty) return context.l10n.all;
                    if (f == 'twitch') return 'Twitch';
                    if (f == 'kick') return 'Kick';
                    if (f == 'youtube') return 'YouTube';
                    return filterController.currentFilter.value;
                  })(),
                  onItemSelected: (selected) {
                    // Convert selection to filter value
                    String? filterValue;
                    final allLabel = context.l10n.all.toLowerCase();
                    final selectedKey = selected.toLowerCase();

                    if (selectedKey == 'all' || selectedKey == allLabel) {
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

    void openMenu(BuildContext context, String? filter) {
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
    }

    return ValueListenableBuilder<String?>(
      valueListenable: widget.chatFilter,
      builder: (context, filter, _) {
        if (filter == null) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => openMenu(context, filter),
              borderRadius: BorderRadius.circular(10.r),
              // Fills row height (parent Row uses crossAxisAlignment: stretch) so the
              // whole vertical band is hit-testable; horizontal padding includes the
              // former trailing gap so taps there open the menu instead of the bar
              // behind (e.g. main view GestureDetector that opens expanded chat).
              child: Padding(
                padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 0),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.all,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.unfold_more,
                        color: Colors.white.withOpacity(0.6),
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Obx(() {
          final label =
              '${filter[0].toUpperCase()}${filter.substring(1)}';
          Color labelColor;
          if (filter == 'twitch') {
            labelColor = _settingsController.twitchColor.value ?? twitchPurple;
          } else if (filter == 'kick') {
            labelColor = _settingsController.kickColor.value ?? kickGreen;
          } else if (filter == 'youtube') {
            labelColor = _settingsController.youtubeColor.value ?? youtubeRed;
          } else {
            labelColor = Colors.white;
          }

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => openMenu(context, filter),
              borderRadius: BorderRadius.circular(10.r),
              child: Padding(
                padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 0),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 16.sp,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.unfold_more,
                        color: Colors.white.withOpacity(0.6),
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  EmoteParser? _emoteParserForRow({
    required List<Map<String, Object>>? embeddedEmotes,
    required Map<String, String>? socketEmoteOverrides,
  }) {
    if (_emoteParser == null) return null;
    final emb = embeddedEmotes;
    if (emb != null && emb.isNotEmpty) return _emoteParser;
    final o = socketEmoteOverrides;
    if (o == null || o.isEmpty) return _emoteParser;
    return EmoteParser(
      emoteUrlMap: {..._emoteService.emoteUrlMap, ...o},
      textStyle: sfProText400(12.sp, Colors.white),
      emoteSize: 28,
    );
  }

  /// Build chat message with emote parsing
  Widget _chatItem(
      String platform,
      String name,
      String message,
      Color nameColor, {
        Key? key,
        bool isCurrentUser = false,
        String? platformKey,
        List<Map<String, Object>>? embeddedEmotes,
        Map<String, String>? socketEmoteOverrides,
      }) {
    final emb = embeddedEmotes;
    final parser = _emoteParserForRow(
      embeddedEmotes: emb,
      socketEmoteOverrides: socketEmoteOverrides,
    );
    final List<InlineSpan> messageSpans =
    emb != null && emb.isNotEmpty && _emoteParser != null
        ? _emoteParser!.parseWithEmbeddedEmotes(message, emb)
        : parser?.parse(message) ??
        [
          TextSpan(
            text: message,
            style: sfProText400(12.sp, Colors.white),
          ),
        ];

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
                      child: isCurrentUser
                          ? Padding(
                              padding: EdgeInsets.only(right: 6.w),
                              child: Icon(
                                Icons.mic,
                                size: 14.sp,
                                color: _settingsController.getPlatformColor(
                                  (platformKey ?? '').toLowerCase().trim(),
                                ),
                              ),
                            )
                          : Padding(
                              padding: EdgeInsets.only(right: 6.w),
                              child: Image.asset(
                                platform,
                                width: 14.sp,
                                height: 14.sp,
                                fit: BoxFit.contain,
                              ),
                            ),
                    ),
                    if (name.isNotEmpty)
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
    _log('openExpandedChat called');
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
      _log('expanded sheet closed');
    });
    _log('expanded sheet opened');
  }

  /// Opens expanded chat and automatically shows emoji picker (only once)
  void _openExpandedChatWithEmoji(BuildContext context) {
    // Reset the flag before opening
    _emojiPickerScheduled = false;
    _log('openExpandedChatWithEmoji called');

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
      _log('expanded sheet (emoji mode) closed');
    });
    _log('expanded sheet (emoji mode) opened');
  }

  /// Builds the expanded chat content (shared between normal and emoji-trigger open)
  Widget _buildExpandedChatContent(
      BuildContext context,
      StateSetter setSheetState,
      ) {
    final keyboardInset = math.max(
      MediaQuery.of(context).viewInsets.bottom,
      _keyboardInset,
    );
    _logInsetChange('expanded.keyboardInset', keyboardInset);
    return FractionallySizedBox(
      heightFactor: 1.0,
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
                      const Spacer(),
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
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: ValueListenableBuilder<String?>(
                        valueListenable: widget.chatFilter,
                        builder: (context, filter, child) {
                          return Obx(() {
                            final filteredList = _getFilteredComments(filter);
                            return ListView.builder(
                              key: ValueKey(
                                'expanded_chat_${filter ?? 'all'}',
                              ),
                              controller: _expandedScrollController,
                              padding: EdgeInsets.only(bottom: 16.h + 20.h),
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
                                  isCurrentUser: item['isCurrentUser'] == true,
                                  platformKey: item['platformKey']?.toString(),
                                  embeddedEmotes:
                                  item['embeddedEmotes']
                                  as List<Map<String, Object>>?,
                                  socketEmoteOverrides:
                                  item['socketEmoteOverrides']
                                  as Map<String, String>?,
                                  key: ValueKey(
                                    'expanded_${item['name']}_${index}_${item['message']}',
                                  ),
                                );
                              },
                            );
                          });
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
                    16.h + keyboardInset,
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  hintText: context.l10n.writeAMessage,
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
                            Center(
                              child: GestureDetector(
                                onTap: () {
                                  _showEmojiEmotePicker(context, setSheetState);
                                },
                                child: SizedBox(
                                  height: 20.h,
                                  width: 20.w,
                                  child: Image.asset('assets/images/smile.png'),
                                ),
                              ),
                            ),
                            SizedBox(width: 9.w),
                            _buildPlatformSelector(setSheetState),
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
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
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
            // Visual drag handle bar (only this area resizes the sheet)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
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
              child: Container(
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
            ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Row(
                children: [
                  Obx(() {
                    final chatCtrl = _chatCtrl;
                    final filter = widget.chatFilter.value?.toLowerCase().trim();
                    final isAllSelected = filter == null || filter.isEmpty;
                    final currentPlatform = isAllSelected
                        ? widget.selectedPlatform.value?.toLowerCase().trim() ?? ''
                        : filter ?? '';

                    // Access reactive maps to ensure GetX tracks dependencies
                    // (even when not needed, to avoid "improper use of GetX" error)
                    // Using .keys to trigger reactive read of RxMap
                    chatCtrl.platformLive.keys;
                    chatCtrl.platformStreamEmbedReady.keys;

                    // Button is enabled only if platform is live AND embed is ready
                    final bool isEnabled = currentPlatform.isEmpty ||
                        (chatCtrl.isPlatformLive(currentPlatform) &&
                         chatCtrl.isPlatformStreamEmbedReadyForChat(currentPlatform));

                    return ValueListenableBuilder<bool>(
                      valueListenable: widget.titleSelected,
                      builder: (context, val, _) {
                        return GestureDetector(
                          onTap: isEnabled ? () {
                            widget.onOverlayViewChange?.call();
                            final newVal = !val;
                            final rawFilter =
                                widget.chatFilter.value?.toLowerCase().trim();
                            final isAllFilter =
                                rawFilter == null ||
                                rawFilter.isEmpty ||
                                rawFilter == 'all';
                            if (newVal) {
                              // Title behavior:
                              // - All filter: always open the main 3-tile selector first.
                              // - Specific filter: open that platform directly.
                              widget.selectedPlatform.value =
                                  isAllFilter ? null : rawFilter;
                            }
                            widget.titleSelected.value = newVal;
                            if (newVal) {
                              widget.showActivity.value = false;
                            }
                            widget.showServiceCard.value =
                                newVal || widget.showActivity.value;
                          } : null,
                          child: Opacity(
                            opacity: isEnabled ? 1.0 : 0.4,
                            child: pillButton(
                              "Title",
                              isActive: val,
                              assetPath: 'assets/images/magic.png',
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  SizedBox(width: 12.w),
                  Obx(() {
                    final chatCtrl = _chatCtrl;
                    final filter = widget.chatFilter.value?.toLowerCase().trim();
                    final isAllSelected = filter == null || filter.isEmpty;
                    final currentPlatform = isAllSelected
                        ? widget.selectedPlatform.value?.toLowerCase().trim() ?? ''
                        : filter ?? '';

                    // Access reactive maps to ensure GetX tracks dependencies
                    // (even when not needed, to avoid "improper use of GetX" error)
                    // Using .keys to trigger reactive read of RxMap
                    chatCtrl.platformLive.keys;
                    chatCtrl.platformStreamEmbedReady.keys;

                    // Button is enabled only if platform is live AND embed is ready
                    final bool isEnabled = currentPlatform.isEmpty ||
                        (chatCtrl.isPlatformLive(currentPlatform) &&
                         chatCtrl.isPlatformStreamEmbedReadyForChat(currentPlatform));

                    return ValueListenableBuilder<bool>(
                      valueListenable: widget.showActivity,
                      builder: (context, active, _) {
                        return GestureDetector(
                          onTap: isEnabled ? () {
                            widget.onOverlayViewChange?.call();
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
                          } : null,
                          child: Opacity(
                            opacity: isEnabled ? 1.0 : 0.4,
                            child: pillButton(
                              context.l10n.activity,
                              isActive: active,
                              assetPath: 'assets/images/line.png',
                            ),
                          ),
                        );
                      },
                    );
                  }),
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
                        return Obx(() {
                          final filteredList = _getFilteredComments(filter);
                          final keyboardHeight = math.max(
                            MediaQuery.of(context).viewInsets.bottom,
                            _keyboardInset,
                          );
                          _logInsetChange('main.keyboardInset', keyboardHeight);
                          return AnimatedPadding(
                            padding: EdgeInsets.only(bottom: keyboardHeight),
                            duration: const Duration(milliseconds: 100),
                            child: ListView.builder(
                              key: ValueKey(
                                'main_chat_${filter ?? 'all'}',
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
                                  isCurrentUser: item['isCurrentUser'] == true,
                                  platformKey: item['platformKey']?.toString(),
                                  embeddedEmotes:
                                  item['embeddedEmotes']
                                  as List<Map<String, Object>>?,
                                  socketEmoteOverrides:
                                  item['socketEmoteOverrides']
                                  as Map<String, String>?,
                                  key: ValueKey(
                                    'main_${item['name']}_${index}_${item['message']}',
                                  ),
                                );
                              },
                            ),
                          );
                        });
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
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
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
                                  ),
                                  // Emoji icon - opens expanded chat WITH emoji picker
                                  Center(
                                    child: GestureDetector(
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
  final Function(String, String?) onEmoteSelected;

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

  String? get _activeEmotePlatform {
    // Tabs: 0=Emoji, 1=Recent, 2=Twitch
    if (_tabController.index == 2) return 'twitch';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
                            hintText: context.l10n.searchEmotes,
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
                      Tab(text: context.l10n.emoji),
                      Tab(text: context.l10n.recent),
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
                      // Kick emotes tab disabled.
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

                      // Twitch Emotes tab
                      _buildTwitchEmotesGrid(),

                      // Kick/7TV Emotes tab disabled.
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
                context.l10n.noRecentEmotes,
                style: TextStyle(color: Colors.white38, fontSize: 14.sp),
              ),
              SizedBox(height: 4.h),
              Text(
                context.l10n.emotesYouUseWillAppearHere,
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
                context.l10n.loadingEmotes,
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
                context.l10n.failedToLoadEmotes,
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
                    context.l10n.retry,
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
            context.l10n.noEmotesFound,
            style: TextStyle(color: Colors.white38, fontSize: 14.sp),
          ),
        );
      }

      return _buildEmoteGridView(emotes);
    });
  }

  Widget _buildTwitchEmotesGrid() {
    return Obx(() {
      if (widget.emoteService.isTwitchLoading.value &&
          widget.emoteService.twitchEmoteList.isEmpty) {
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
                context.l10n.loadingEmotes,
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
              ),
            ],
          ),
        );
      }

      if (widget.emoteService.hasTwitchError.value &&
          widget.emoteService.twitchEmoteList.isEmpty) {
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
                context.l10n.failedToLoadEmotes,
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
              ),
              SizedBox(height: 8.h),
              GestureDetector(
                onTap: () => widget.emoteService.fetchTwitchEmotes(),
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
                    context.l10n.retry,
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      final emotes = _searchQuery.isEmpty
          ? widget.emoteService.twitchEmoteList.toList()
          : widget.emoteService.searchTwitchEmotes(_searchQuery);

      if (emotes.isEmpty) {
        return Center(
          child: Text(
            context.l10n.noEmotesFound,
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
            onTap: () => widget.onEmoteSelected(emote.name, _activeEmotePlatform),
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
