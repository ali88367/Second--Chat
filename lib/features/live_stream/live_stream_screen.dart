import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/streak_controller.dart';

import '../../../../core/themes/textstyles.dart';
import 'package:second_chat/core/utils/app_clock_format.dart';
import '../../../controllers/Main Section Controllers/settings_controller.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/platform_categories_controller.dart';
import '../../core/constants/app_colors/app_colors.dart';
import '../../core/widgets/stream_header_buttons.dart';
import '../../core/localization/l10n.dart';
import '../Invite/Invite_screen.dart';
import '../Streaks/streak_sheet_router.dart';
import '../main_section/settings/settings_bottomsheet_column.dart';
import 'widgets/chat_bottom_section.dart';
import 'widgets/live_stream_helper_widgets.dart';
import 'widgets/live_stream_embed_stack.dart';
import 'widgets/stream_title_edit_panel.dart';
// import 'socket_log_screen.dart';

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
  bool _streakCompletionChecked = false;
  bool _streakSheetOpening = false;
  Worker? _platformLiveWorker;

  // Resizable bottom section state
  double _bottomSectionHeight = 0;
  double? _bottomSectionMaxHeight;
  bool _activityPanelExpanded = false;
  double _activityLayoutMin = 0;
  double _activityLayoutMax = 0;
  double? _bottomSectionHeightBeforeActivityExpand;
  double? _bottomSectionHeightBeforeCategoryMenu;
  bool _isInitialHeightSet = false;
  static const double _categoryMenuBottomHeightFraction = 0.42;
  static const double _dragSensitivity = 1.8;
  static const double _minBottomSectionHeightFactor = 0.20;
  static const double _minUpperSectionHeight = 50.0;
  final Map<String, double> _lastLayoutLogs = {};

  // ── Activity section state ──────────────────────────────────────────
  double _activityHeight = 0;
  bool _isDraggingActivity = false;
  static const double _activityMinHeight = 0.3;
  static const double _activityMaxHeight = 0.65;
  final ScrollController _activityScrollController = ScrollController();
  final TextEditingController _streamTitleEditController =
      TextEditingController();
  final TextEditingController _streamCategoryEditController =
      TextEditingController();
  final ValueNotifier<bool> _isEditingStreamDetails = ValueNotifier(false);
  final ValueNotifier<bool> _isSavingStreamDetails = ValueNotifier(false);
  final ValueNotifier<String?> _editingPlatformKey = ValueNotifier(null);
  final ValueNotifier<bool> _categoryMenuOpen = ValueNotifier(false);
  final ValueNotifier<String?> _selectedCategoryId = ValueNotifier(null);
  late final SettingsController _settingsCtrl;
  late final StreamStreaksController _streakCtrl;

  @override
  void initState() {
    super.initState();
    _settingsCtrl = Get.find<SettingsController>();
    _streakCtrl = Get.find<StreamStreaksController>();
    unawaited(_refreshStreakOnEntry());
    _chatFilter.addListener(_updateImageBasedOnFilter);
    _chatFilter.addListener(_syncSelectedPlatformFromFilter);
    _showActivity.addListener(_onShowActivityOpened);
    _categoryMenuOpen.addListener(_syncLayoutForCategoryMenu);
    _platformLiveWorker = ever<Map<String, bool>>(
      Get.find<ChatController>().platformLive,
      (_) {
        _collapseOverlaysIfStreamWentOffline();
        _syncSelectedPlatformFromFilter();
      },
    );
    _warmPrefetchBottomSheets();
    _maybeCompleteStreakForToday();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(Get.find<ChatController>().ensureStreamRealtimeBootstrap());
    });
  }

  void _warmPrefetchBottomSheets() {
    unawaited(_refreshStreakOnEntry());
    final invites =
    Get.isRegistered<InviteController>()
        ? Get.find<InviteController>()
        : Get.put(InviteController(), permanent: true);
    invites.loadInvitesIfNeeded();
  }

  Future<void> _refreshStreakOnEntry() async {
    final hasSession = await _streakCtrl.ensureSession(showErrors: false);
    if (!hasSession) return;
    await _streakCtrl.fetchCurrentStreak(force: true, silent: true);
  }

  void _onShowActivityOpened() {
    if (!_showActivity.value || !mounted) return;
    setState(() {
      _activityPanelExpanded = false;
      _activityHeight = 0;
      _bottomSectionHeightBeforeActivityExpand = null;
    });
  }

  /// Shrinks chat while the inline category list is open so the title panel can grow.
  void _syncLayoutForCategoryMenu() {
    if (!mounted || !_isInitialHeightSet) return;

    final screenHeight = Get.height;
    final minHeight = _bottomSectionMinHeight(screenHeight);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final maxHeight =
        screenHeight -
            _layoutTopPadding(context) -
            _minUpperSectionHeight -
            16.h -
            12.h -
            bottomInset;
    final clampedMaxHeight = maxHeight > minHeight ? maxHeight : minHeight;
    final effectiveMaxHeight =
        _bottomSectionMaxHeight == null
            ? clampedMaxHeight
            : math.min(clampedMaxHeight, _bottomSectionMaxHeight!);

    final shrinkChat =
        _showServiceCard.value &&
        _titleSelected.value &&
        _categoryMenuOpen.value;

    if (shrinkChat) {
      final topPadding = _layoutTopPadding(context);
      final availableHeight =
          screenHeight - topPadding - (16.h + bottomInset);
      final compactTarget = math
          .min(
            availableHeight * _categoryMenuBottomHeightFraction,
            effectiveMaxHeight,
          )
          .clamp(minHeight, effectiveMaxHeight)
          .toDouble();

      _bottomSectionHeightBeforeCategoryMenu ??= _bottomSectionHeight;
      if (_bottomSectionHeight != compactTarget) {
        setState(() => _bottomSectionHeight = compactTarget);
      }
      return;
    }

    if (_bottomSectionHeightBeforeCategoryMenu != null) {
      final restored = _bottomSectionHeightBeforeCategoryMenu!
          .clamp(minHeight, effectiveMaxHeight)
          .toDouble();
      setState(() {
        _bottomSectionHeight = restored;
        _bottomSectionHeightBeforeCategoryMenu = null;
      });
    }
  }

  static const List<String> _streamPlatformKeys = [
    'twitch',
    'kick',
    'youtube',
    'tiktok',
  ];

  bool _anyPlatformLive(ChatController chatCtrl) {
    for (final k in _streamPlatformKeys) {
      if (chatCtrl.isPlatformLive(k)) return true;
    }
    return false;
  }

  /// When [ChatController.platformLive] updates from the socket, return the user from the
  /// title/activity/service overlay to the stream preview if the stream they were tied to
  /// is no longer live (specific filter → that platform; **All** + pinned row → that
  /// platform; **All** without a pin → only when no platform is live).
  void _collapseOverlaysIfStreamWentOffline() {
    if (!mounted) return;
    final overlayOpen = _showServiceCard.value || _showActivity.value;
    if (!overlayOpen) return;

    final chatCtrl = Get.find<ChatController>();
    final raw = (_chatFilter.value ?? '').trim().toLowerCase();
    final isAll = raw.isEmpty || raw == 'all';

    final bool shouldClose;
    if (!isAll) {
      shouldClose = !chatCtrl.isPlatformLive(raw);
    } else {
      final pinned = _selectedPlatform.value?.trim().toLowerCase();
      if (pinned != null && pinned.isNotEmpty) {
        shouldClose = !chatCtrl.isPlatformLive(pinned);
      } else {
        shouldClose = !_anyPlatformLive(chatCtrl);
      }
    }
    if (!shouldClose) return;

    _titleSelected.value = false;
    _showActivity.value = false;
    _showServiceCard.value = false;
    _selectedPlatform.value = null;
    _isEditingStreamDetails.value = false;
    _isSavingStreamDetails.value = false;
    _categoryMenuOpen.value = false;
    _editingPlatformKey.value = null;
    _selectedCategoryId.value = null;
    setState(() {
      _activityHeight = 0;
      _activityPanelExpanded = false;
      _isDraggingActivity = false;
      _bottomSectionHeightBeforeActivityExpand = null;
      _bottomSectionHeightBeforeCategoryMenu = null;
    });
    _syncLayoutForCategoryMenu();
  }

  void _syncSelectedPlatformFromFilter() {
    final chatCtrl = Get.find<ChatController>();
    final selected = _chatFilter.value?.toLowerCase().trim();
    if (selected == null || selected.isEmpty) {
      // "All": single webview should follow the first live platform.
      final firstLive = <String>['twitch', 'kick', 'youtube'].firstWhere(
        (k) => chatCtrl.isPlatformLive(k),
        orElse: () => '',
      );
      final fallback = firstLive.isNotEmpty
          ? firstLive
          : _normalizeUiPlatform(chatCtrl.platform.value);
      if (_selectedPlatform.value != fallback) {
        _selectedPlatform.value = fallback;
      }
      if (chatCtrl.platform.value.toLowerCase().trim() != fallback) {
        chatCtrl.selectPlatformInstant(fallback);
      }
      return;
    }
    if (_selectedPlatform.value != selected) {
      _selectedPlatform.value = selected;
    }
    if (chatCtrl.platform.value.toLowerCase().trim() == selected) return;
    chatCtrl.selectPlatformInstant(selected);
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

  Future<void> _maybeCompleteStreakForToday() async {
    if (_streakCompletionChecked) return;
    _streakCompletionChecked = true;

    try {
      await _refreshStreakOnEntry();
    } catch (e) {
      debugPrint('STREAK COMPLETE ERROR: $e');
    }
  }

  Future<void> _openStreakSheet({bool forceFreezePreview = false}) async {
    if (_streakSheetOpening) return;
    _streakSheetOpening = true;
    try {
      final hasSession = await _streakCtrl.ensureSession(showErrors: true);
      if (!hasSession || !mounted) return;

      await Get.bottomSheet(
        StreakSheetRouter(forceFreezePreview: forceFreezePreview),
        isDismissible: true,
        isScrollControlled: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        enterBottomSheetDuration: const Duration(milliseconds: 220),
        exitBottomSheetDuration: const Duration(milliseconds: 200),
      );
    } finally {
      _streakSheetOpening = false;
      if (mounted) {
        unawaited(_streakCtrl.fetchCurrentStreak(force: true, silent: true));
      }
    }
  }

  @override
  void dispose() {
    _chatFilter.removeListener(_updateImageBasedOnFilter);
    _chatFilter.removeListener(_syncSelectedPlatformFromFilter);
    _showActivity.removeListener(_onShowActivityOpened);
    _categoryMenuOpen.removeListener(_syncLayoutForCategoryMenu);
    _platformLiveWorker?.dispose();
    _showServiceCard.dispose();
    _selectedPlatform.dispose();
    _showActivity.dispose();
    _titleSelected.dispose();
    _topBarImage.dispose();
    _chatFilter.dispose();
    _activityScrollController.dispose();
    _streamTitleEditController.dispose();
    _streamCategoryEditController.dispose();
    _isEditingStreamDetails.dispose();
    _isSavingStreamDetails.dispose();
    _editingPlatformKey.dispose();
    _categoryMenuOpen.dispose();
    _selectedCategoryId.dispose();
    super.dispose();
  }

  void _startEditingStreamDetails({
    required String platformKey,
    required String title,
    required String category,
  }) {
    _streamTitleEditController.text = title;
    _streamCategoryEditController.text = category;
    _selectedCategoryId.value = null;
    _categoryMenuOpen.value = false;
    final normalized = _normalizeUiPlatform(platformKey);
    _editingPlatformKey.value = normalized;
    _isEditingStreamDetails.value = true;
    unawaited(
      Get.find<PlatformCategoriesController>().ensureCategoriesFor(normalized),
    );
  }

  void _toggleCategoryMenu() {
    if (!_isEditingStreamDetails.value) return;

    final opening = !_categoryMenuOpen.value;
    final key = _editingPlatformKey.value?.trim() ?? '';
    if (opening && key.isNotEmpty) {
      unawaited(
        Get.find<PlatformCategoriesController>().ensureCategoriesFor(key),
      );
    }
    _categoryMenuOpen.value = opening;
    _syncLayoutForCategoryMenu();
  }

  void _dismissCategoryMenu() {
    if (!_categoryMenuOpen.value) return;
    _categoryMenuOpen.value = false;
    _syncLayoutForCategoryMenu();
  }

  void _onCategoryPicked(String name, String id) {
    _streamCategoryEditController.text = name;
    _selectedCategoryId.value = id;
    _dismissCategoryMenu();
  }

  Future<void> _saveStreamDetails(BuildContext context) async {
    final platformKey = _editingPlatformKey.value;
    if (platformKey == null || platformKey.trim().isEmpty) return;
    final nextTitle = _streamTitleEditController.text.trim();
    final nextCategory = _streamCategoryEditController.text.trim();
    if (nextTitle.isEmpty) return;

    _isSavingStreamDetails.value = true;
    final chatCtrl = Get.find<ChatController>();
    final ok = await chatCtrl.updateStreamMetadata(
      platformKey: platformKey,
      title: nextTitle,
      category: nextCategory,
      categoryId: _selectedCategoryId.value,
    );
    if (!mounted) return;
    _isSavingStreamDetails.value = false;
    if (ok) {
      _isEditingStreamDetails.value = false;
      _dismissCategoryMenu();
      _editingPlatformKey.value = null;
      _selectedCategoryId.value = null;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save stream details')),
      );
    }
  }

  Widget _streamMetaRow({
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
      decoration: BoxDecoration(
        color: greyy,
        borderRadius: BorderRadius.circular(28.r),
      ),
      child: Row(
        children: [Expanded(child: content)],
      ),
    );
  }

  void _collapseActivityExpandedIfNeeded(BuildContext context) {
    if (!_activityPanelExpanded) return;
    final screenHeight = Get.height;
    final minHeight = _bottomSectionMinHeight(screenHeight);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final maxBottom =
        screenHeight -
            _layoutTopPadding(context) -
            16.h -
            _minUpperSectionHeight -
            12.h -
            bottomInset;
    final clampedMaxBottom = maxBottom > minHeight ? maxBottom : minHeight;
    final effectiveMaxBottom =
    _bottomSectionMaxHeight == null
        ? clampedMaxBottom
        : math.min(clampedMaxBottom, _bottomSectionMaxHeight!);
    setState(() {
      final restored =
      (_bottomSectionHeightBeforeActivityExpand ?? effectiveMaxBottom)
          .clamp(minHeight, effectiveMaxBottom)
          .toDouble();
      _bottomSectionHeight = restored;
      _bottomSectionHeightBeforeActivityExpand = null;
      if (_activityLayoutMin > 0) {
        _activityHeight = _activityLayoutMin;
      }
      _activityPanelExpanded = false;
    });
  }

  void _handleFilterTap(String platformKey) {
    if (mounted) {
      _collapseActivityExpandedIfNeeded(context);
    }
    final selectingNew = _chatFilter.value != platformKey;
    if (selectingNew && _showServiceCard.value) {
      final chatCtrl = Get.find<ChatController>();
      if (!chatCtrl.isPlatformLive(platformKey)) {
        return;
      }
    }
    if (_chatFilter.value == platformKey) {
      _chatFilter.value = null;
    } else {
      _chatFilter.value = platformKey;
    }
  }

  void _handlePlatformSwipe(bool swipeRight) {
    if (mounted) {
      _collapseActivityExpandedIfNeeded(context);
    }
    const platforms = [null, 'twitch', 'kick', 'youtube'];
    if (!_showServiceCard.value) {
      final currentIndex = platforms.indexOf(_chatFilter.value);
      if (swipeRight) {
        _chatFilter.value =
            platforms[(currentIndex + 1) % platforms.length];
      } else {
        _chatFilter.value =
            platforms[(currentIndex - 1 + platforms.length) % platforms.length];
      }
      return;
    }

    final chatCtrl = Get.find<ChatController>();
    var idx = platforms.indexOf(_chatFilter.value);
    for (var attempt = 0; attempt < platforms.length; attempt++) {
      if (swipeRight) {
        idx = (idx + 1) % platforms.length;
      } else {
        idx = (idx - 1 + platforms.length) % platforms.length;
      }
      final next = platforms[idx];
      if (next == null || chatCtrl.isPlatformLive(next)) {
        _chatFilter.value = next;
        return;
      }
    }
    _chatFilter.value = null;
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[LiveStreamScreen] $message');
    }
  }

  void _logValueChange(String key, double value) {
    final prev = _lastLayoutLogs[key];
    if (prev == null || (prev - value).abs() > 0.5) {
      _lastLayoutLogs[key] = value;
      _log('$key=$value');
    }
  }

  String _formatViewerCount(int? count) {
    if (count == null) return '—';
    if (count < 1000) return '$count';
    if (count < 1000000) {
      final v = (count / 1000);
      final s = v.toStringAsFixed(v < 10 ? 1 : 0);
      return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}K';
    }
    if (count < 1000000000) {
      final v = (count / 1000000);
      final s = v.toStringAsFixed(v < 10 ? 1 : 0);
      return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}M';
    }
    final v = (count / 1000000000);
    final s = v.toStringAsFixed(v < 10 ? 1 : 0);
    return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}B';
  }

  String _assetForPlatform(String platform) {
    switch (_normalizeUiPlatform(platform)) {
      case 'kick':
        return 'assets/images/kick.png';
      case 'youtube':
        return 'assets/images/youtube.png';
      case 'twitch':
      default:
        return 'assets/images/twitch.png';
    }
  }

  String _normalizeUiPlatform(String? raw) {
    final v = (raw ?? '').toLowerCase().trim();
    if (v.contains('kick')) return 'kick';
    if (v.contains('youtube') || v == 'yt' || v.contains('google')) {
      return 'youtube';
    }
    return 'twitch';
  }

  static const List<String> _activityPlatformOrder = [
    'twitch',
    'kick',
    'youtube',
  ];

  List<String> _livePlatformKeys(ChatController chatCtrl) {
    return _activityPlatformOrder
        .where((k) => chatCtrl.isPlatformLive(k))
        .toList(growable: false);
  }

  /// Whether [e] belongs in the activity rail for the current chat filter.
  /// For **All**, only platforms with `live == true` are included (fixes wrong
  /// stream when [ChatController.platform] still points at an offline tab).
  bool _activityEventMatchesChatFilter({
    required ChatController chatCtrl,
    required String? chatFilter,
    required Map<String, dynamic> e,
  }) {
    final raw = (e['platform'] ?? '').toString().trim();
    final normalizedFilter = chatFilter?.toLowerCase().trim();
    final eventKey = raw.isEmpty ? '' : _normalizeUiPlatform(raw);

    if (normalizedFilter != null && normalizedFilter.isNotEmpty) {
      if (!chatCtrl.isPlatformLive(normalizedFilter)) return false;
      if (!chatCtrl.isPlatformStreamEmbedReadyForChat(normalizedFilter)) {
        return false;
      }
      if (raw.isEmpty) return true;
      return eventKey == normalizedFilter;
    }

    final live = _livePlatformKeys(chatCtrl);
    if (live.isEmpty) return false;
    if (raw.isEmpty) {
      if (live.length != 1) return false;
      return chatCtrl.isPlatformStreamEmbedReadyForChat(live.first);
    }
    if (!chatCtrl.isPlatformStreamEmbedReadyForChat(eventKey)) return false;
    return live.contains(eventKey);
  }

  /// Primary line: `{username} joined|followed|unfollowed` when [type] matches; else fallback.
  (String primary, String secondary) _activityRowLines({
    required String user,
    required String typeRaw,
  }) {
    final type = typeRaw.toLowerCase().trim();
    final u = user.trim();
    if (type == 'join' || type == 'viewer_join' || type == 'viewer join') {
      return (u.isNotEmpty ? '$u has joined chat' : 'Someone has joined chat', '');
    }
    if (type == 'follow' || type == 'new_follower' || type == 'new follow') {
      return (u.isNotEmpty ? '$u followed' : 'Someone followed', '');
    }
    if (type == 'subscribe' ||
        type == 'subscription' ||
        type == 'new_subscriber' ||
        type == 'new subscriber') {
      return (u.isNotEmpty ? '$u subscribed' : 'Someone subscribed', '');
    }
    if (type == 'unfollow' ||
        type == 'unfollowed' ||
        type == 'follow_off' ||
        type == 'followoff') {
      return (u.isNotEmpty ? '$u unfollowed' : 'Someone unfollowed', '');
    }
    if (type == 'unsubscribe') {
      return (u.isNotEmpty ? '$u unsubscribed' : 'Someone unsubscribed', '');
    }
    final primary =
    u.isNotEmpty ? u : (typeRaw.isNotEmpty ? typeRaw : 'Activity');
    final secondary =
    u.isNotEmpty &&
        typeRaw.isNotEmpty &&
        typeRaw.toLowerCase() != u.toLowerCase()
        ? typeRaw
        : '';
    return (primary, secondary);
  }

  String _formatActivityTime(dynamic tsRaw) {
    return formatAppClockTimeFromRaw(
      tsRaw,
      clockFormat: _settingsCtrl.clockFormat.value,
    );
  }

  double _bottomSectionMinHeight(double screenHeight) {
    final minByFactor = screenHeight * _minBottomSectionHeightFactor;

    // Keep collapsed size large enough for fixed header UI + counter row.
    final minByContent =
        (12.h + 59.4.h + 12.h) + // counter row wrapper in parent
            (10.h + 8.h + 4.h + 8.h + 16.h + 36.h + 16.h) + // chat header chrome
            8.h; // small safety buffer to avoid edge overflow on some devices

    return minByFactor > minByContent ? minByFactor : minByContent;
  }

  double _mainContentTopOffset(BuildContext context) {
    final safeTop = MediaQuery.of(context).viewPadding.top;
    final dynamicOffset =
        safeTop +
            28.h + // top padding used by top icon row
            36.w + // icon row visual height
            12.h; // spacing below row
    final legacyOffset = 117.h;
    return dynamicOffset > legacyOffset ? dynamicOffset : legacyOffset;
  }

  double _layoutTopPadding(BuildContext context) {
    return _mainContentTopOffset(context) + 5.h;
  }

  void _toggleActivityPanelExpand(BuildContext context) {
    final screenHeight = Get.height;
    final minHeight = _bottomSectionMinHeight(screenHeight);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final maxBottom =
        screenHeight -
            _layoutTopPadding(context) -
            16.h -
            _minUpperSectionHeight -
            12.h -
            bottomInset;
    final clampedMaxBottom = maxBottom > minHeight ? maxBottom : minHeight;
    final effectiveMaxBottom =
    _bottomSectionMaxHeight == null
        ? clampedMaxBottom
        : math.min(clampedMaxBottom, _bottomSectionMaxHeight!);

    setState(() {
      final nextExpanded = !_activityPanelExpanded;
      if (nextExpanded) {
        _bottomSectionHeightBeforeActivityExpand ??=
            _bottomSectionHeight
                .clamp(minHeight, effectiveMaxBottom)
                .toDouble();
        _bottomSectionHeight = minHeight;
        if (_activityLayoutMax > 0) {
          _activityHeight = _activityLayoutMax;
        }
      } else {
        final restored =
        (_bottomSectionHeightBeforeActivityExpand ?? effectiveMaxBottom)
            .clamp(minHeight, effectiveMaxBottom)
            .toDouble();
        _bottomSectionHeight = restored;
        _bottomSectionHeightBeforeActivityExpand = null;
        if (_activityLayoutMin > 0) {
          _activityHeight = _activityLayoutMin;
        }
      }
      _activityPanelExpanded = nextExpanded;
    });
  }

  Widget _buildInteractiveCounterRow() {
    return Obx(() {
      final chatCtrl = Get.find<ChatController>();
      final showViewerCounts = _settingsCtrl.viewerCount.value;
      final twitchViews = chatCtrl.platformViewerCounts['twitch'];
      final kickViews = chatCtrl.platformViewerCounts['kick'];
      final youtubeViews = chatCtrl.platformViewerCounts['youtube'];
      String viewerCountText(String platformKey, int? count) {
        if (!showViewerCounts) return '-';
        final embedReady = chatCtrl.isPlatformStreamEmbedReadyForChat(platformKey);
        if (!embedReady) return '0';
        return _formatViewerCount(count);
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
                  count: viewerCountText('twitch', twitchViews),
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
                  count: viewerCountText('kick', kickViews),
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
                  count: viewerCountText('youtube', youtubeViews),
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

  Widget _buildResizableActivityContainer(
      BuildContext context,
      double availableHeight,
      ) {
    final double screenHeight = Get.height;
    final double minHeightFromScreen = screenHeight * _activityMinHeight;
    final double maxHeightFromScreen = screenHeight * _activityMaxHeight;
    final double slotCap =
    (availableHeight > 0 ? availableHeight : maxHeightFromScreen)
        .toDouble();
    // Fill the upper stream slot when expanded (no artificial shrink).
    final double maxHeight = math.max(minHeightFromScreen, slotCap);
    final double originalHeight =
    minHeightFromScreen.clamp(0, maxHeight).toDouble();

    if (_activityHeight == 0) {
      _activityHeight = _activityPanelExpanded ? maxHeight : originalHeight;
    }

    final double clampedHeight = _activityHeight.clamp(
      originalHeight,
      maxHeight,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final parentMax =
        constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : slotCap;
        final effectiveMax =
        math
            .min(parentMax, maxHeight)
            .clamp(0.0, double.infinity)
            .toDouble();
        final effectiveMin = originalHeight.clamp(0, effectiveMax).toDouble();
        _activityLayoutMin = effectiveMin;
        _activityLayoutMax = effectiveMax;

        final double height;
        if (_isDraggingActivity) {
          height = clampedHeight.clamp(effectiveMin, effectiveMax).toDouble();
        } else if (_activityPanelExpanded) {
          height = effectiveMax;
        } else {
          height = _activityHeight.clamp(effectiveMin, effectiveMax).toDouble();
        }
        final activityPanel = AnimatedContainer(
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
              Positioned(
                top: 10.h,
                left: 12.w,
                child: Text(
                  context.l10n.activity,
                  style: sfProText600(13.sp, Colors.white),
                ),
              ),
              // ─── Scrollable activity rows ───────────────────────
              Positioned.fill(
                child: ScrollbarTheme(
                  data: ScrollbarThemeData(
                    thumbColor: MaterialStateProperty.all(Colors.grey.shade500),
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
                        top: 28.h,
                        bottom: 26.h,
                      ),
                      physics:
                      _isDraggingActivity
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                      child: ValueListenableBuilder<String?>(
                        valueListenable: _chatFilter,
                        builder: (context, chatFilterSnap, _) {
                          return Obx(() {
                            final chatCtrl = Get.find<ChatController>();
                            chatCtrl.platform.value;
                            chatCtrl.platformLive.keys;
                            _settingsCtrl.clockFormat.value;
                            final liveKeys = _livePlatformKeys(chatCtrl);
                            final filterKey =
                                chatFilterSnap?.toLowerCase().trim();
                            // Prefer controller activity list (wired to sockets).
                            // Chat "normal" lines stay in chat; activity = everything else.
                            final events = chatCtrl.activityEvents
                                .where((e) {
                              final t =
                              (e['type'] ?? e['eventType'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase();
                              return t != 'normal';
                            })
                                .where(
                                  (e) => _activityEventMatchesChatFilter(
                                    chatCtrl: chatCtrl,
                                    chatFilter: filterKey,
                                    e: e,
                                  ),
                                )
                                .toList(growable: false);
                            if (events.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 24.h),
                                  child: Text(
                                    context.l10n.noActivityYet,
                                    textAlign: TextAlign.center,
                                    style: sfProText400(13.sp, Colors.white54),
                                  ),
                                ),
                              );
                            }
                            // Render newest first.
                            final list =
                                events.reversed.toList(growable: false);
                            final scopeKey =
                                '${filterKey ?? 'all'}_${liveKeys.join('_')}';
                            return RepaintBoundary(
                              child: Column(
                                key: ValueKey<String>('activity_$scopeKey'),
                                children: [
                              for (var i = 0; i < list.length; i++) ...[
                                Builder(
                                  builder: (ctx) {
                                    final e = list[i];
                                    final platform =
                                    (e['platform'] ?? '').toString();
                                    final meta = e['metadata'];
                                    final metaMap =
                                    meta is Map
                                        ? meta.cast<String, dynamic>()
                                        : const <String, dynamic>{};
                                    final user =
                                    (metaMap['user'] ??
                                        metaMap['username'] ??
                                        metaMap['user_name'] ??
                                        metaMap['user_login'] ??
                                        metaMap['name'] ??
                                        e['username'] ??
                                        '')
                                        .toString()
                                        .trim();
                                    final type =
                                    (e['type'] ?? e['eventType'] ?? '')
                                        .toString()
                                        .trim();
                                    final time = _formatActivityTime(
                                      e['timestamp'] ?? e['created_at'],
                                    );
                                    final lines = _activityRowLines(
                                      user: user,
                                      typeRaw: type,
                                    );
                                    final fallbackPlatform =
                                        liveKeys.length == 1
                                            ? liveKeys.first
                                            : (filterKey != null &&
                                                    filterKey.isNotEmpty
                                                ? filterKey
                                                : _normalizeUiPlatform(
                                                    chatCtrl.platform.value,
                                                  ));
                                    final pKey = _normalizeUiPlatform(
                                      platform.isNotEmpty
                                          ? platform
                                          : fallbackPlatform,
                                    );
                                    return activityRow(
                                      _assetForPlatform(pKey),
                                      pKey,
                                      lines.$1,
                                      time,
                                      lines.$2,
                                    );
                                  },
                                ),
                                if (i != list.length - 1)
                                  SizedBox(height: 12.h),
                              ],
                            ],
                              ),
                            );
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12.w,
                bottom: 10.h,
                child: GestureDetector(
                  onTap: () => _toggleActivityPanelExpand(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(38, 37, 41, 1),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: Colors.white12, width: 1.w),
                    ),
                    child: Text(
                      _activityPanelExpanded
                          ? context.l10n.seeLess
                          : context.l10n.seeMore,
                      style: sfProText400(11.sp, Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        // Expanded: no parent vertical-drag — avoids collapsing when scrolling /
        // tapping the list. Collapse only via See less (or filter / other controls).
        if (_activityPanelExpanded) {
          return activityPanel;
        }

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (_) {
            setState(() {
              _isDraggingActivity = true;
              final startH = _activityHeight.clamp(effectiveMin, effectiveMax);
              _activityHeight = startH;
            });
          },
          onVerticalDragUpdate: (details) {
            final delta = details.delta.dy * _activityDragSensitivity;
            if (delta < 0 && _activityHeight <= effectiveMin) {
              return;
            }
            setState(() {
              _activityHeight = (_activityHeight + delta).clamp(
                effectiveMin,
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
          child: activityPanel,
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
                      Obx(() {
                        final streakTotal =
                            _streakCtrl.current.value?.headerStreakTotal ?? 0;
                        return StreakButton(
                          count: streakTotal,
                          onTap: _openStreakSheet,
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                        );
                      }),
                      Row(
                        children: [
                          // Socket log screen (temporarily disabled)
                          // GestureDetector(
                          //   onTap: () {
                          //     Get.to(() => const SocketLogScreen());
                          //   },
                          //   child: Container(
                          //     width: 36.w,
                          //     height: 36.w,
                          //     alignment: Alignment.center,
                          //     decoration: BoxDecoration(
                          //       color: const Color(0xFF2C2C2E),
                          //       borderRadius: BorderRadius.circular(10.r),
                          //     ),
                          //     child: Icon(
                          //       Icons.terminal_rounded,
                          //       size: 20.sp,
                          //       color: Colors.white70,
                          //     ),
                          //   ),
                          // ),
                          // SizedBox(width: 6.w),
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
                                enterBottomSheetDuration: Duration.zero,
                                exitBottomSheetDuration: Duration.zero,
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
                      final layoutTopPadding = _layoutTopPadding(context);
                      final mainContentTopOffset = _mainContentTopOffset(
                        context,
                      );
                      if (!_isInitialHeightSet) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            final screenHeight = Get.height;
                            final topPadding = layoutTopPadding;
                            final spacing = 12.h;
                            final bottomPadding =
                                16.h +
                                    MediaQuery.of(context).viewPadding.bottom;
                            final minHeight = _bottomSectionMinHeight(
                              screenHeight,
                            );
                            final maxHeight =
                                screenHeight -
                                    topPadding -
                                    spacing -
                                    _minUpperSectionHeight -
                                    bottomPadding;
                            final safeMaxHeight =
                            maxHeight > minHeight ? maxHeight : minHeight;
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
                            final legacyInitialHeight =
                            initialBottomHeight > 200.h
                                ? initialBottomHeight
                                : 200.h;
                            setState(() {
                              _bottomSectionHeight =
                                  legacyInitialHeight
                                      .clamp(minHeight, safeMaxHeight)
                                      .toDouble();
                              _bottomSectionMaxHeight = _bottomSectionHeight;
                              _isInitialHeightSet = true;
                            });
                          }
                        });
                      }

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          SizedBox(height: mainContentTopOffset),

                          // ── Upper section ──
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, upperConstraints) {
                                final upperSectionHeight =
                                upperConstraints.maxHeight.isFinite &&
                                    upperConstraints.maxHeight > 0
                                    ? upperConstraints.maxHeight
                                    : 226.h;
                                final streamPreviewHeight =
                                upperSectionHeight.toDouble();

                                return AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _showActivity,
                                    _showServiceCard,
                                    _isEditingStreamDetails,
                                    _categoryMenuOpen,
                                  ]),
                                  builder: (context, _) {
                                    final showActivity = _showActivity.value;
                                    final showCard = _showServiceCard.value;
                                    final lockUpperScroll =
                                        showCard ||
                                        showActivity ||
                                        _isDraggingActivity ||
                                        _categoryMenuOpen.value;

                                    final streamCardContent =
                                        ValueListenableBuilder<
                                            bool
                                        >(
                                          valueListenable: _showServiceCard,
                                          builder: (
                                            context,
                                            showCardInner,
                                            child,
                                          ) {
                                                    final chatCtrl =
                                                    Get.find<
                                                        ChatController
                                                    >();
                                                    final settingsCtrl =
                                                    Get.find<
                                                        SettingsController
                                                    >();

                                                    final webView = SizedBox(
                                                      height:
                                                      streamPreviewHeight,
                                                      child: Obx(() {
                                                        final multi =
                                                            settingsCtrl
                                                                .multiScreenPreview
                                                                .value ==
                                                                true;
                                                        return Container(
                                                          width:
                                                          MediaQuery.of(
                                                            context,
                                                          ).size.width,
                                                          margin:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 5.w,
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
                                                            child: Padding(
                                                              padding:
                                                              EdgeInsets.all(
                                                                multi
                                                                    ? 8.w
                                                                    : 0,
                                                              ),
                                                              child:
                                                              multi
                                                                  ? LiveStreamMultiEmbedGrid(
                                                                streamPreviewHeight:
                                                                streamPreviewHeight,
                                                                globalMuted:
                                                                showCard || showActivity,
                                                                onStreamReady: (
                                                                    platformKey,
                                                                    runningUrl,
                                                                    ) {
                                                                  Get.find<
                                                                      ChatController
                                                                  >()
                                                                      .onPlatformStreamWebViewReady(
                                                                    platformKey:
                                                                    platformKey,
                                                                    runningUrl:
                                                                    runningUrl,
                                                                  );
                                                                },
                                                              )
                                                                  : LiveStreamSingleEmbedStack(
                                                                streamPreviewHeight:
                                                                streamPreviewHeight,
                                                                globalMuted:
                                                                showCard || showActivity,
                                                                onStreamReady: (
                                                                    platformKey,
                                                                    runningUrl,
                                                                    ) {
                                                                  Get.find<
                                                                      ChatController
                                                                  >()
                                                                      .onPlatformStreamWebViewReady(
                                                                    platformKey:
                                                                    platformKey,
                                                                    runningUrl:
                                                                    runningUrl,
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }),
                                                    );

                                                    return SizedBox(
                                                      height:
                                                      streamPreviewHeight,
                                                      child: Stack(
                                                        fit: StackFit.expand,
                                                        clipBehavior:
                                                        Clip.none,
                                                        children: [
                                                          Offstage(
                                                            offstage: showCard,
                                                            child: webView,
                                                          ),
                                                          if (showCard)
                                                            Positioned.fill(
                                                              child: ValueListenableBuilder<
                                                                  bool
                                                              >(
                                                                valueListenable:
                                                                _titleSelected,
                                                                builder: (
                                                                    context,
                                                                    titleSelected,
                                                                    _,
                                                                    ) {
                                                                  if (titleSelected) {
                                                                    return ValueListenableBuilder<
                                                                        String?
                                                                    >(
                                                                      valueListenable:
                                                                      _selectedPlatform,
                                                                      builder: (
                                                                          context,
                                                                          platform,
                                                                          _,
                                                                          ) {
                                                                        if (platform !=
                                                                            null) {
                                                                          final activePlatform = _normalizeUiPlatform(
                                                                            platform,
                                                                          );
                                                                          return Column(
                                                                                children: [
                                                                              Expanded(
                                                                                child: Container(
                                                                                  width:
                                                                                  double.infinity,
                                                                                  padding: EdgeInsets.symmetric(
                                                                                    horizontal:
                                                                                    12.w,
                                                                                    vertical:
                                                                                    12.h,
                                                                                  ),
                                                                                  decoration: BoxDecoration(
                                                                                    color:
                                                                                    black,
                                                                                    borderRadius: BorderRadius.circular(
                                                                                      20.r,
                                                                                    ),
                                                                                  ),
                                                                                  child: Column(
                                                                                    children: [
                                                                                      Padding(
                                                                                        padding: EdgeInsets.symmetric(
                                                                                          horizontal:
                                                                                          8.w,
                                                                                        ),
                                                                                        child: Row(
                                                                                          children: [
                                                                                            GestureDetector(
                                                                                              onTap: () {
                                                                                                _collapseActivityExpandedIfNeeded(
                                                                                                  context,
                                                                                                );
                                                                                                final rawFilter =
                                                                                                    (_chatFilter.value ?? '')
                                                                                                        .trim()
                                                                                                        .toLowerCase();
                                                                                                final isAllFilter =
                                                                                                    rawFilter.isEmpty ||
                                                                                                        rawFilter == 'all';
                                                                                                if (isAllFilter) {
                                                                                                  // In "All", back should return from a specific
                                                                                                  // platform details view to the 3-tile chooser.
                                                                                                  _selectedPlatform.value = null;
                                                                                                  _titleSelected.value = true;
                                                                                                  _showServiceCard.value = true;
                                                                                                  _showActivity.value = false;
                                                                                                  _isEditingStreamDetails.value =
                                                                                                      false;
                                                                                                  _isSavingStreamDetails.value =
                                                                                                      false;
                                                                                                  _categoryMenuOpen.value = false;
                                                                                                  _editingPlatformKey.value = null;
                                                                                                } else {
                                                                                                  // In platform-specific filters, back closes title panel.
                                                                                                  _selectedPlatform.value = null;
                                                                                                  _showServiceCard.value = false;
                                                                                                  _titleSelected.value = false;
                                                                                                  _showActivity.value = false;
                                                                                                  _activityHeight = 0;
                                                                                                  _isDraggingActivity = false;
                                                                                                  _isEditingStreamDetails.value =
                                                                                                      false;
                                                                                                  _isSavingStreamDetails.value =
                                                                                                      false;
                                                                                                  _categoryMenuOpen.value = false;
                                                                                                  _editingPlatformKey.value = null;
                                                                                                }
                                                                                              },
                                                                                              child: Container(
                                                                                                padding: EdgeInsets.all(
                                                                                                  8.w,
                                                                                                ),
                                                                                                decoration: BoxDecoration(
                                                                                                  color:
                                                                                                  Colors.grey.shade900,
                                                                                                  shape:
                                                                                                  BoxShape.circle,
                                                                                                ),
                                                                                                child: Transform.translate(
                                                                                                  offset: const Offset(
                                                                                                    2,
                                                                                                    0,
                                                                                                  ),
                                                                                                  child: Icon(
                                                                                                    Icons.arrow_back_ios,
                                                                                                    color:
                                                                                                    Colors.white,
                                                                                                    size:
                                                                                                    16.sp,
                                                                                                  ),
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                            const Spacer(),
                                                                                            Obx(
                                                                                                  () {
                                                                                                final displayKey = _normalizeUiPlatform(
                                                                                                  activePlatform,
                                                                                                );
                                                                                                final iconAsset = _assetForPlatform(
                                                                                                  displayKey,
                                                                                                );
                                                                                                final iconColor = _settingsCtrl.getPlatformColor(
                                                                                                  displayKey,
                                                                                                );
                                                                                                return Center(
                                                                                                  child: Image.asset(
                                                                                                    iconAsset,
                                                                                                    color:
                                                                                                    iconColor,
                                                                                                    width:
                                                                                                    22.w,
                                                                                                    height:
                                                                                                    22.h,
                                                                                                  ),
                                                                                                );
                                                                                              },
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
                                                                                        16.h,
                                                                                      ),
                                                                                      Expanded(
                                                                                        child: Obx(
                                                                                            () {
                                                                                          final metaKey = _normalizeUiPlatform(
                                                                                            activePlatform,
                                                                                          ).toString().trim();
                                                                                          final titleLive =
                                                                                              (chatCtrl.streamTitleByPlatform[metaKey] ??
                                                                                                      '')
                                                                                                  .trim();
                                                                                          final categoryLive =
                                                                                              (chatCtrl.streamCategoryByPlatform[metaKey] ??
                                                                                                      '')
                                                                                                  .trim();
                                                                                          final titlePanel =
                                                                                              titleLive.isNotEmpty
                                                                                                  ? titleLive
                                                                                                  : context.l10n.streamMetaEmpty;
                                                                                          final categoryPanel =
                                                                                              categoryLive.isNotEmpty
                                                                                                  ? categoryLive
                                                                                                  : context.l10n.streamMetaEmpty;
                                                                                          return ValueListenableBuilder<bool>(
                                                                                            valueListenable:
                                                                                                _isEditingStreamDetails,
                                                                                            builder: (
                                                                                              context,
                                                                                              isEditing,
                                                                                              _,
                                                                                            ) {
                                                                                              return ValueListenableBuilder<
                                                                                                  String?>
                                                                                                (
                                                                                                valueListenable:
                                                                                                    _editingPlatformKey,
                                                                                                builder: (
                                                                                                  context,
                                                                                                  editingKey,
                                                                                                  __,
                                                                                                ) {
                                                                                                  return ValueListenableBuilder<
                                                                                                      bool>(
                                                                                                    valueListenable:
                                                                                                        _isSavingStreamDetails,
                                                                                                    builder: (
                                                                                                      context,
                                                                                                      isSaving,
                                                                                                      ___,
                                                                                                    ) {
                                                                                                      final isEditingThis =
                                                                                                          isEditing &&
                                                                                                          editingKey ==
                                                                                                              metaKey;
                                                                                                      return StreamTitleEditPanel(
                                                                                                        platformKey: metaKey,
                                                                                                        isEditing: isEditingThis,
                                                                                                        isSaving: isSaving,
                                                                                                        titleDisplay: titlePanel,
                                                                                                        categoryDisplay: categoryPanel,
                                                                                                        titleField: isEditingThis
                                                                                                            ? TextField(
                                                                                                                controller: _streamTitleEditController,
                                                                                                                style: sfProText600(13.sp, Colors.white),
                                                                                                                decoration: const InputDecoration(
                                                                                                                  isDense: true,
                                                                                                                  border: InputBorder.none,
                                                                                                                  enabledBorder: InputBorder.none,
                                                                                                                  focusedBorder: InputBorder.none,
                                                                                                                  disabledBorder: InputBorder.none,
                                                                                                                  contentPadding: EdgeInsets.zero,
                                                                                                                ),
                                                                                                              )
                                                                                                            : Text(
                                                                                                                titlePanel,
                                                                                                                style: sfProText600(13.sp, Colors.white),
                                                                                                              ),
                                                                                                        categoryController: _streamCategoryEditController,
                                                                                                        categoryMenuOpen: _categoryMenuOpen,
                                                                                                        selectedCategoryId: _selectedCategoryId,
                                                                                                        onToggleCategoryMenu: _toggleCategoryMenu,
                                                                                                        onCategoryPicked: _onCategoryPicked,
                                                                                                        onEditOrSave: isSaving
                                                                                                            ? () {}
                                                                                                            : () {
                                                                                                                if (isEditingThis) {
                                                                                                                  _saveStreamDetails(context);
                                                                                                                } else {
                                                                                                                  _startEditingStreamDetails(
                                                                                                                    platformKey: metaKey,
                                                                                                                    title: titleLive,
                                                                                                                    category: categoryLive,
                                                                                                                  );
                                                                                                                }
                                                                                                              },
                                                                                                        metaRowBuilder: (child) => _streamMetaRow(content: child),
                                                                                                      );
                                                                                                    },
                                                                                                  );
                                                                                                },
                                                                                              );
                                                                                            },
                                                                                          );
                                                                                        },
                                                                                      ),),
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          );
                                                                        }

                                                                        return Column(
                                                                          children: [
                                                                            Expanded(
                                                                              child: Center(
                                                                                child: Container(
                                                                                  width:
                                                                                  double.infinity,
                                                                                  padding: EdgeInsets.symmetric(
                                                                                    horizontal:
                                                                                    14.w,
                                                                                    vertical:
                                                                                    8.h,
                                                                                  ),
                                                                                  decoration: BoxDecoration(
                                                                                    color:
                                                                                    black,
                                                                                    borderRadius: BorderRadius.circular(
                                                                                      20.r,
                                                                                    ),
                                                                                  ),
                                                                                  child: Column(
                                                                                    mainAxisSize:
                                                                                    MainAxisSize.min,
                                                                                    mainAxisAlignment:
                                                                                    MainAxisAlignment.start,
                                                                                    children: [
                                                                                      Obx(
                                                                                            () {
                                                                                          final rawFilter =
                                                                                              (_chatFilter.value ?? '')
                                                                                                  .trim()
                                                                                                  .toLowerCase();
                                                                                          final isAllFilter =
                                                                                              rawFilter.isEmpty ||
                                                                                                  rawFilter == 'all';
                                                                                          if (isAllFilter) {
                                                                                            return Column(
                                                                                              mainAxisSize:
                                                                                                  MainAxisSize.min,
                                                                                              children: List.generate(3, (index) {
                                                                                                const platforms = <String>[
                                                                                                  'twitch',
                                                                                                  'kick',
                                                                                                  'youtube',
                                                                                                ];
                                                                                                final platformKey = platforms[index];
                                                                                                return Padding(
                                                                                                  padding: EdgeInsets.only(
                                                                                                    bottom: index == platforms.length - 1 ? 0 : 6.h,
                                                                                                  ),
                                                                                                  child: serviceRow(
                                                                                                    asset: _assetForPlatform(
                                                                                                      platformKey,
                                                                                                    ),
                                                                                                    iconColor:
                                                                                                        _settingsCtrl.getPlatformColor(
                                                                                                      platformKey,
                                                                                                    ),
                                                                                                    title:
                                                                                                        context.l10n.title,
                                                                                                    subtitle:
                                                                                                        context.l10n.category,
                                                                                                    onTap: () {
                                                                                                      _collapseActivityExpandedIfNeeded(
                                                                                                        context,
                                                                                                      );
                                                                                                      _selectedPlatform.value =
                                                                                                          platformKey;
                                                                                                      _titleSelected.value =
                                                                                                          true;
                                                                                                      _showServiceCard.value =
                                                                                                          true;
                                                                                                    },
                                                                                                  ),
                                                                                                );
                                                                                              }),
                                                                                            );
                                                                                          }

                                                                                          final currentPlatform = _normalizeUiPlatform(
                                                                                            _chatFilter.value ??
                                                                                                chatCtrl.platform.value,
                                                                                          );
                                                                                          return serviceRow(
                                                                                            asset: _assetForPlatform(
                                                                                              currentPlatform,
                                                                                            ),
                                                                                            iconColor: _settingsCtrl.getPlatformColor(
                                                                                              currentPlatform,
                                                                                            ),
                                                                                            title:
                                                                                                context.l10n.title,
                                                                                            subtitle:
                                                                                                context.l10n.category,
                                                                                            onTap: () {
                                                                                              _collapseActivityExpandedIfNeeded(
                                                                                                context,
                                                                                              );
                                                                                              _selectedPlatform.value = currentPlatform;
                                                                                              _titleSelected.value = true;
                                                                                              _showServiceCard.value = true;
                                                                                            },
                                                                                          );
                                                                                        },
                                                                                      ),
                                                                                      SizedBox(height: 6.h),
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        );
                                                                      },
                                                                    );
                                                                  }

                                                                  return const SizedBox.shrink();
                                                                },
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );

                                    return SizedBox(
                                      height: upperSectionHeight,
                                      width: double.infinity,
                                      child: Stack(
                                        clipBehavior: Clip.hardEdge,
                                        children: [
                                          IgnorePointer(
                                            ignoring: showActivity,
                                            child: lockUpperScroll
                                                ? SizedBox(
                                                    height: upperSectionHeight,
                                                    width: double.infinity,
                                                    child: streamCardContent,
                                                  )
                                                : SingleChildScrollView(
                                                    physics:
                                                        const ClampingScrollPhysics(),
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          BoxConstraints(
                                                        minHeight:
                                                            upperSectionHeight,
                                                      ),
                                                      child: streamCardContent,
                                                    ),
                                                  ),
                                          ),
                                          if (showActivity)
                                            Positioned.fill(
                                              child:
                                              _buildResizableActivityContainer(
                                                context,
                                                upperSectionHeight,
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 3.h),
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
    _logValueChange('layout.bottomInset', bottomInset);
    _logValueChange('layout.keyboardInset', keyboardInset);

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
                onOverlayViewChange:
                    () => _collapseActivityExpandedIfNeeded(context),
              ),
            ),
          ],
        ),
      );
    }

    final screenHeight = Get.height;
    const double bottomGap = 16;
    final minHeight = _bottomSectionMinHeight(screenHeight);
    final maxHeight =
        screenHeight -
            _layoutTopPadding(context) -
            _minUpperSectionHeight -
            bottomGap.h -
            12.h -
            bottomInset;
    final clampedMaxHeight = maxHeight > minHeight ? maxHeight : minHeight;
    final effectiveMaxHeight =
    _bottomSectionMaxHeight == null
        ? clampedMaxHeight
        : math.min(clampedMaxHeight, _bottomSectionMaxHeight!);

    final currentHeight =
    _bottomSectionHeight.clamp(minHeight, effectiveMaxHeight).toDouble();
    _logValueChange('layout.currentHeight', currentHeight);

    return SizedBox(
      height: currentHeight,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 8.h, bottom: 6.h),
            child: _buildInteractiveCounterRow(),
          ),
          Expanded(
            child: ChatBottomSection(
              showServiceCard: _showServiceCard,
              showActivity: _showActivity,
              selectedPlatform: _selectedPlatform,
              titleSelected: _titleSelected,
              chatFilter: _chatFilter,
              onOverlayViewChange:
                  () => _collapseActivityExpandedIfNeeded(context),
              onResize: (delta) {
                final adjustedDelta = delta * _dragSensitivity;
                setState(() {
                  _bottomSectionHeight =
                      (_bottomSectionHeight - adjustedDelta)
                          .clamp(minHeight, effectiveMaxHeight)
                          .toDouble();
                });
              },
              onResizeEnd: () {
                setState(() {
                  _bottomSectionHeight =
                      _bottomSectionHeight
                          .clamp(minHeight, effectiveMaxHeight)
                          .toDouble();
                });
              },
              onPlatformSwipe: _handlePlatformSwipe,
            ),
          ),
        ],
      ),
    );
  }
}
