import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:second_chat/controllers/auth_controller.dart';
import 'package:second_chat/core/localization/get_l10n.dart';

enum CellType { tick, cross, dot, freeze }

class StreakData {
  const StreakData({
    required this.currentStreak,
    required this.longestStreak,
    required this.selectedDays,
    required this.targetDaysPerWeek,
    required this.completedThisWeek,
    required this.remainingThisWeek,
    required this.freezeTokens,
    required this.freezeAllowancePerMonth,
    required this.freezeUsedThisMonth,
    required this.status,
    required this.isInDanger,
    required this.weekStartDate,
    required this.lastCompletedDate,
    required this.completedDates,
    required this.frozenDates,
    required this.weekGrid,
    this.raw,
  });

  final int currentStreak;
  final int longestStreak;
  final List<String> selectedDays;
  final int targetDaysPerWeek;
  final int completedThisWeek;
  final int remainingThisWeek;
  final int freezeTokens;
  final int freezeAllowancePerMonth;
  final int freezeUsedThisMonth;
  final String status;
  final bool isInDanger;
  final DateTime? weekStartDate;
  final DateTime? lastCompletedDate;
  final List<DateTime> completedDates;
  final List<DateTime> frozenDates;
  final List<CellType> weekGrid;
  final Map<String, dynamic>? raw;

  bool get isConfigured {
    if (selectedDays.isNotEmpty) return true;
    if (targetDaysPerWeek > 0) return true;
    if (currentStreak > 0 || longestStreak > 0) return true;
    if (completedDates.isNotEmpty || frozenDates.isNotEmpty) return true;
    if (weekGrid.isNotEmpty) return true;
    if (status.isNotEmpty && status.toLowerCase() != 'inactive') return true;
    return false;
  }

  bool get hasCreatedStreak {
    return currentStreak > 0 ||
        completedDates.isNotEmpty ||
        lastCompletedDate != null;
  }

  int get remainingFreezes =>
      (freezeAllowancePerMonth - freezeUsedThisMonth)
          .clamp(0, freezeAllowancePerMonth)
          .toInt();

  bool isDateCompleted(DateTime date) {
    final local = _stripTime(date);
    if (lastCompletedDate != null &&
        _isSameDay(_stripTime(lastCompletedDate!), local)) {
      return true;
    }
    for (final d in completedDates) {
      if (_isSameDay(_stripTime(d), local)) return true;
    }
    return false;
  }

  bool isDateFrozen(DateTime date) {
    final local = _stripTime(date);
    for (final d in frozenDates) {
      if (_isSameDay(_stripTime(d), local)) return true;
    }
    return false;
  }

  StreakData copyWith({
    int? currentStreak,
    int? longestStreak,
    List<String>? selectedDays,
    int? targetDaysPerWeek,
    int? completedThisWeek,
    int? remainingThisWeek,
    int? freezeTokens,
    int? freezeAllowancePerMonth,
    int? freezeUsedThisMonth,
    String? status,
    bool? isInDanger,
    DateTime? weekStartDate,
    DateTime? lastCompletedDate,
    List<DateTime>? completedDates,
    List<DateTime>? frozenDates,
    List<CellType>? weekGrid,
  }) {
    return StreakData(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      selectedDays: selectedDays ?? this.selectedDays,
      targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
      completedThisWeek: completedThisWeek ?? this.completedThisWeek,
      remainingThisWeek: remainingThisWeek ?? this.remainingThisWeek,
      freezeTokens: freezeTokens ?? this.freezeTokens,
      freezeAllowancePerMonth:
          freezeAllowancePerMonth ?? this.freezeAllowancePerMonth,
      freezeUsedThisMonth: freezeUsedThisMonth ?? this.freezeUsedThisMonth,
      status: status ?? this.status,
      isInDanger: isInDanger ?? this.isInDanger,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      completedDates: completedDates ?? this.completedDates,
      frozenDates: frozenDates ?? this.frozenDates,
      weekGrid: weekGrid ?? this.weekGrid,
      raw: raw,
    );
  }

  factory StreakData.fromPayload(dynamic payload) {
    final overviewData = _extractOverviewData(payload);
    if (overviewData != null) {
      final parsed = _fromOverviewData(overviewData);
      if (parsed != null) return parsed;
    }
    final map = _extractStreakMap(payload);
    final settings = _asMap(
      map['settings'] ?? map['setting'] ?? map['config'],
    );
    final state = _asMap(
      map['state'] ?? map['status'] ?? map['data'] ?? map['current'],
    );

    final selectedDays = _asStringList(
      map['selectedDays'] ??
          map['selected_days'] ??
          state['selectedDays'] ??
          state['selected_days'],
    );
    final status = _asString(map['status'] ?? state['status']);
    final isInDanger =
        _asBool(
          map['inDanger'] ??
              map['isInDanger'] ??
              map['in_danger'] ??
              state['inDanger'] ??
              state['isInDanger'] ??
              state['in_danger'] ??
              map['danger'],
        ) ||
        status.toLowerCase() == 'danger';
    final weekStartDate = _parseDate(
      map['weekStartDate'] ??
          map['week_start_date'] ??
          map['weekStart'] ??
          map['week_start'] ??
          map['weekStartAt'] ??
          state['weekStartDate'] ??
          state['week_start_date'],
    );
    final lastCompletedDate = _parseDate(
      state['lastCheckInDate'] ??
          state['last_check_in_date'] ??
          state['lastCheckInAt'] ??
          map['lastCheckInDate'] ??
          map['last_check_in_date'] ??
          map['lastCompletedDate'] ??
          map['lastCompletedAt'] ??
          map['lastCompletionDate'] ??
          map['lastCompletionAt'],
    );
    final completedDatesRaw = _asDateList(
      state['history'] ??
          state['historyDates'] ??
          state['history_dates'] ??
          map['history'] ??
          map['completedDates'] ??
          map['completed_dates'] ??
          map['completedDays'] ??
          map['completed_days'],
    );
    final completedDates = List<DateTime>.from(completedDatesRaw);
    if (lastCompletedDate != null &&
        !completedDates.any(
          (d) => _isSameDay(_stripTime(d), _stripTime(lastCompletedDate)),
        )) {
      completedDates.add(lastCompletedDate);
    }

    final frozenDates = _asDateList(
      state['frozenDates'] ??
          state['frozen_dates'] ??
          state['freezeDates'] ??
          state['freeze_days'] ??
          map['frozenDates'] ??
          map['freezeDates'] ??
          map['frozen_dates'] ??
          map['freeze_days'],
    );

    final rawWeekGrid = _extractWeekGrid(map);
    final weekGrid =
        rawWeekGrid == null ? const <CellType>[] : _normalizeRow(rawWeekGrid);

    final currentStreak = _asInt(
      state['currentStreak'] ??
          state['current_streak'] ??
          state['current'] ??
          map['currentStreak'] ??
          map['current_streak'] ??
          map['current'],
    );
    final longestStreak = _asInt(
      state['bestStreak'] ??
          state['best_streak'] ??
          state['best'] ??
          map['bestStreak'] ??
          map['best_streak'] ??
          map['best'] ??
          map['longestStreak'] ??
          map['longest_streak'],
    );
    final targetDaysPerWeek = _asInt(
      settings['weeklyGoal'] ??
          settings['weekly_goal'] ??
          settings['timesPerWeek'] ??
          settings['times_per_week'] ??
          map['weeklyGoal'] ??
          map['weekly_goal'] ??
          map['timesPerWeek'] ??
          map['times_per_week'] ??
          state['weeklyGoal'] ??
          state['weekly_goal'] ??
          state['timesPerWeek'] ??
          state['times_per_week'] ??
          map['targetDaysPerWeek'] ??
          map['target_days_per_week'],
      fallback: selectedDays.length,
    );
    final fallbackCompleted =
        weekGrid.isNotEmpty
            ? _countCompletedFromWeekGrid(weekGrid)
            : _countCompletedFromDates(
              historyDates: completedDates,
              frozenDates: frozenDates,
              weekStart: weekStartDate,
            );
    final completedThisWeek = _asInt(
      map['completedThisWeek'] ??
          map['completed_this_week'] ??
          state['completedThisWeek'] ??
          state['completed_this_week'],
      fallback: fallbackCompleted,
    );
    final remainingThisWeek = _asInt(
      map['remainingThisWeek'] ??
          map['remaining_this_week'] ??
          state['remainingThisWeek'] ??
          state['remaining_this_week'],
      fallback: (targetDaysPerWeek - completedThisWeek)
          .clamp(0, targetDaysPerWeek),
    );
    final freezeAllowancePerMonth = _asInt(
      settings['freezeAllowancePerMonth'] ??
          settings['freeze_allowance_per_month'] ??
          map['freezeAllowancePerMonth'] ??
          map['freeze_allowance_per_month'] ??
          state['freezeAllowancePerMonth'] ??
          state['freeze_allowance_per_month'],
    );
    final freezeUsedThisMonth = _asInt(
      state['freezeUsedThisMonth'] ??
          state['freeze_used_this_month'] ??
          map['freezeUsedThisMonth'] ??
          map['freeze_used_this_month'],
    );
    final remainingFreezes =
        (freezeAllowancePerMonth - freezeUsedThisMonth)
            .clamp(0, freezeAllowancePerMonth)
            .toInt();

    return StreakData(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      selectedDays: selectedDays,
      targetDaysPerWeek: targetDaysPerWeek,
      completedThisWeek: completedThisWeek,
      remainingThisWeek: remainingThisWeek,
      freezeTokens: remainingFreezes,
      freezeAllowancePerMonth: freezeAllowancePerMonth,
      freezeUsedThisMonth: freezeUsedThisMonth,
      status: status,
      isInDanger: isInDanger,
      weekStartDate: weekStartDate,
      lastCompletedDate: lastCompletedDate,
      completedDates: completedDates,
      frozenDates: frozenDates,
      weekGrid: weekGrid,
      raw: map.isEmpty ? null : map,
    );
  }
}

class StreakCompleteResult {
  const StreakCompleteResult({
    required this.success,
    required this.alreadyCompleted,
    required this.skipped,
    this.message,
  });

  final bool success;
  final bool alreadyCompleted;
  final bool skipped;
  final String? message;

  bool get didUpdate => success || alreadyCompleted;
}

class StreamStreaksController extends GetxController {
  var selectedDays =
      <String, bool>{
        'Mon': false,
        'Tue': false,
        'Wed': false,
        'Thur': false,
        'Fri': false,
        'Sat': false,
        'Sun': false,
      }.obs;

  RxBool threeTimesWeek = false.obs;
  RxBool isSelectingThreeDays = false.obs;
  RxInt selectedTimesPerWeek = 0.obs;
  RxList<int> selectedMenuNumbers = <int>[].obs;
  final List<int> _fullNumberList = [1, 2, 3, 4, 5, 6, 7];

  final Rxn<StreakData> current = Rxn<StreakData>();
  final RxList<List<CellType>> historyRows = <List<CellType>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isHistoryLoading = false.obs;
  final RxBool isMutating = false.obs;

  List<int> get availableNumbers =>
      _fullNumberList.where((n) => !selectedMenuNumbers.contains(n)).toList();
  int get selectedCount => selectedMenuNumbers.length;
  bool get areDaysDisabled => false;
  int get selectedDaysCount => selectedDays.values.where((v) => v).length;
  bool get isThreeTimesSelectionComplete =>
      !threeTimesWeek.value ||
      (selectedTimesPerWeek.value > 0 &&
          selectedDaysCount == selectedTimesPerWeek.value);

  StreakData? get streak => current.value;
  bool get hasStreak => current.value?.hasCreatedStreak ?? false;
  bool get supportsDayEditing => false;

  List<String> selectedDaysPayload() {
    return _uiDayOrder
        .where((day) => selectedDays[day] == true)
        .map((day) => _uiToApiDay[day]!)
        .toList();
  }

  void resetSelection() {
    selectedDays.updateAll((key, value) => false);
    selectedDays.refresh();
    threeTimesWeek.value = false;
    isSelectingThreeDays.value = false;
    selectedTimesPerWeek.value = 0;
    selectedMenuNumbers.clear();
  }

  void syncSelectionFromStreak(StreakData data) {
    selectedDays.updateAll((key, value) => false);
    for (final apiDay in data.selectedDays) {
      final uiDay = _apiToUiDay[_normalizeDay(apiDay)];
      if (uiDay != null) {
        selectedDays[uiDay] = true;
      }
    }
    selectedDays.refresh();
    threeTimesWeek.value = false;
    isSelectingThreeDays.value = false;
    selectedTimesPerWeek.value = 0;
    selectedMenuNumbers.clear();
  }

  Future<bool> ensureSession({bool showErrors = true}) async {
    final token = await _getAccessToken(showErrors: showErrors);
    return token != null && token.isNotEmpty;
  }

  Future<StreakData?> fetchCurrentStreak({
    bool force = false,
    bool silent = true,
  }) async {
    if (isLoading.value && !force) return current.value;
    isLoading.value = true;
    try {
      final accessToken = await _getAccessToken(showErrors: !silent);
      if (accessToken == null || accessToken.isEmpty) {
        current.value = null;
        historyRows.clear();
        return null;
      }

      final auth = Get.find<AuthController>();
      final res = await auth.api.client.dio.get<dynamic>(
        '/api/v1/streaks/overview',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      _logStreakResponse('GET /api/v1/streaks/overview', res.data);
      final snapshot = StreakData.fromPayload(res.data);
      if (kDebugMode) {
        debugPrint(
          'STREAK CREATED CHECK: ${snapshot.hasCreatedStreak} '
          '(currentStreak=${snapshot.currentStreak}, '
          'historyCount=${snapshot.completedDates.length}, '
          'lastCheckInDate=${snapshot.lastCompletedDate?.toIso8601String() ?? 'null'})',
        );
      }
      current.value = snapshot;
      historyRows.assignAll(_buildHistoryRowsFromDates(snapshot));
      return current.value;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        current.value = null;
        historyRows.clear();
      } else {
        debugPrint('STREAK LOAD ERROR: ${e.response?.data ?? e.message}');
        if (!silent) {
          _showConnectionIssue();
        }
      }
    } catch (e) {
      debugPrint('STREAK LOAD ERROR: $e');
      if (!silent) {
        _showConnectionIssue();
      }
    } finally {
      isLoading.value = false;
    }
    return current.value;
  }

  Future<List<List<CellType>>> fetchHistory({
    bool force = false,
    bool silent = true,
  }) async {
    if (isHistoryLoading.value && !force) return historyRows;
    isHistoryLoading.value = true;
    try {
      await fetchCurrentStreak(force: force, silent: silent);
      return historyRows;
    } finally {
      isHistoryLoading.value = false;
    }
  }

  Future<bool> createStreak({
    required List<String> selectedDays,
    required int targetDaysPerWeek,
    bool showErrors = true,
  }) async {
    if (isMutating.value) return false;
    isMutating.value = true;
    try {
      debugPrint('STREAK CREATE SKIPPED: use overview-based streak flow.');
    } finally {
      isMutating.value = false;
    }
    return false;
  }

  Future<bool> updateStreak({
    required List<String> selectedDays,
    bool showErrors = true,
  }) async {
    if (isMutating.value) return false;
    isMutating.value = true;
    try {
      debugPrint('STREAK UPDATE SKIPPED: use overview-based streak flow.');
    } finally {
      isMutating.value = false;
    }
    return false;
  }

  Future<StreakCompleteResult> markStreakComplete({
    required DateTime date,
    bool showErrors = false,
  }) async {
    final accessToken = await _getAccessToken(showErrors: showErrors);
    if (accessToken == null || accessToken.isEmpty) {
      return const StreakCompleteResult(
        success: false,
        alreadyCompleted: false,
        skipped: true,
        message: 'missing_session',
      );
    }

    final currentStreak =
        await fetchCurrentStreak(force: true, silent: true);
    if (currentStreak == null) {
      return const StreakCompleteResult(
        success: false,
        alreadyCompleted: false,
        skipped: true,
        message: 'no_streak',
      );
    }

    if (currentStreak.isDateCompleted(date) ||
        currentStreak.isDateFrozen(date)) {
      return const StreakCompleteResult(
        success: false,
        alreadyCompleted: true,
        skipped: false,
        message: 'already_completed',
      );
    }

    try {
      final auth = Get.find<AuthController>();
      final res = await auth.api.client.dio.post<dynamic>(
        '/api/v1/streaks/check-in',
        data: {'date': _formatDate(date)},
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      _logStreakResponse('POST /api/v1/streaks/check-in', res.data);
      final snapshot = StreakData.fromPayload(res.data);
      current.value = snapshot;
      historyRows.assignAll(_buildHistoryRowsFromDates(snapshot));

      return const StreakCompleteResult(
        success: true,
        alreadyCompleted: false,
        skipped: false,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 409 || status == 400) {
        await fetchCurrentStreak(force: true, silent: true);
        return const StreakCompleteResult(
          success: false,
          alreadyCompleted: true,
          skipped: false,
          message: 'already_completed',
        );
      }
      debugPrint('STREAK COMPLETE ERROR: ${e.response?.data ?? e.message}');
      if (showErrors) {
        _showConnectionIssue();
      }
    } catch (e) {
      debugPrint('STREAK COMPLETE ERROR: $e');
      if (showErrors) {
        _showConnectionIssue();
      }
    }

    return const StreakCompleteResult(
      success: false,
      alreadyCompleted: false,
      skipped: false,
      message: 'failed',
    );
  }

  Future<bool> freezeStreak({
    DateTime? date,
    bool showErrors = true,
  }) async {
    if (isMutating.value) return false;
    isMutating.value = true;
    try {
      final accessToken = await _getAccessToken(showErrors: showErrors);
      if (accessToken == null || accessToken.isEmpty) return false;

      final auth = Get.find<AuthController>();
      final res = await auth.api.client.dio.post<dynamic>(
        '/api/v1/streaks/freeze/use',
        data: {'date': _formatDate(date ?? DateTime.now())},
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      _logStreakResponse('POST /api/v1/streaks/freeze/use', res.data);
      final snapshot = StreakData.fromPayload(res.data);
      current.value = snapshot;
      historyRows.assignAll(_buildHistoryRowsFromDates(snapshot));
      return true;
    } on DioException catch (e) {
      debugPrint('STREAK FREEZE ERROR: ${e.response?.data ?? e.message}');
      if (showErrors) {
        _showConnectionIssue();
      }
    } catch (e) {
      debugPrint('STREAK FREEZE ERROR: $e');
      if (showErrors) {
        _showConnectionIssue();
      }
    } finally {
      isMutating.value = false;
    }
    return false;
  }

  List<CellType> buildCurrentWeekRow() {
    final streak = current.value;
    if (streak == null) {
      return List.generate(7, (_) => CellType.cross);
    }
    if (streak.weekGrid.isNotEmpty) {
      return _normalizeRow(streak.weekGrid);
    }
    final weekStart = streak.weekStartDate ?? _startOfWeek(DateTime.now());
    return _buildWeekRowFromDates(
      weekStart: weekStart,
      historyDates: streak.completedDates,
      frozenDates: streak.frozenDates,
    );
  }

  List<List<CellType>> buildCalendarRows({int maxRows = 4}) {
    final rows = <List<CellType>>[];
    if (current.value != null) {
      rows.add(buildCurrentWeekRow());
    }
    for (final row in historyRows) {
      if (rows.length >= maxRows) break;
      rows.add(_normalizeRow(row));
    }
    while (rows.length < maxRows) {
      rows.add(List.generate(7, (_) => CellType.cross));
    }
    return rows;
  }

  List<List<int>> getTickGroups(List<CellType> row) {
    final groups = <List<int>>[];
    int start = -1;
    for (int i = 0; i < row.length; i++) {
      if (row[i] == CellType.tick) {
        if (start == -1) start = i;
      } else {
        if (start != -1) {
          groups.add([start, i - 1]);
          start = -1;
        }
      }
    }
    if (start != -1) groups.add([start, row.length - 1]);
    return groups;
  }

  void toggleMenuNumber(int number) {
    if (selectedTimesPerWeek.value == number) {
      selectedTimesPerWeek.value = 0;
      selectedMenuNumbers.clear();
      selectedDays.updateAll((key, value) => false);
      selectedDays.refresh();
    } else {
      selectedTimesPerWeek.value = number;
      selectedMenuNumbers.assignAll([number]);
      selectedDays.updateAll((key, value) => false);
      selectedDays.refresh();
    }

    threeTimesWeek.value = selectedTimesPerWeek.value > 0;
    isSelectingThreeDays.value = false;
    selectedMenuNumbers.refresh();
  }

  void toggleDay(String day) {
    if (!threeTimesWeek.value) {
      selectedDays[day] = !selectedDays[day]!;
      selectedDays.refresh();
      return;
    }

    final currentlySelected = selectedDays[day] ?? false;
    final count = selectedDays.values.where((v) => v).length;
    final maxAllowed = selectedTimesPerWeek.value;

    if (currentlySelected) {
      selectedDays[day] = false;
      selectedDays.refresh();
      return;
    }

    if (maxAllowed <= 0 || count >= maxAllowed) return;
    selectedDays[day] = true;
    selectedDays.refresh();
  }

  void toggleThreeTimesWeek(bool value) {
    threeTimesWeek.value = value;
    if (value) {
      isSelectingThreeDays.value = true;
      selectedMenuNumbers.clear();
      selectedTimesPerWeek.value = 0;
      selectedDays.updateAll((key, value) => false);
    } else {
      isSelectingThreeDays.value = false;
      selectedMenuNumbers.clear();
      selectedTimesPerWeek.value = 0;
      selectedDays.updateAll((key, value) => false);
      selectedDays.refresh();
    }
  }

  void clearSelectionsIfBelow3() {
    if (selectedTimesPerWeek.value <= 0) {
      selectedMenuNumbers.clear();
      selectedTimesPerWeek.value = 0;
      selectedDays.updateAll((key, value) => false);
      selectedDays.refresh();
      threeTimesWeek.value = false;
      isSelectingThreeDays.value = false;
    }
  }

  Future<String?> _getAccessToken({bool showErrors = false}) async {
    final auth = Get.find<AuthController>();
    final tokens = await auth.api.tokenStore.read();
    final accessToken = tokens?.accessToken?.trim();
    if (accessToken == null || accessToken.isEmpty) {
      if (showErrors) {
        _showSessionMissing();
      }
      return null;
    }
    return accessToken;
  }

  void _showSessionMissing() {
    final l10n = getAppL10n();
    _showSnack(
      l10n?.sessionMissing ?? 'Session missing',
      l10n?.sessionMissingMessage ?? 'Please log in again.',
    );
  }

  void _showConnectionIssue() {
    final l10n = getAppL10n();
    _showSnack(
      l10n?.connectionIssue ?? 'Connection issue',
      l10n?.pleaseTryAgain ?? 'Please try again.',
    );
  }

  void _showSnack(String title, String message) {
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF2C2C2E),
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    );
  }

  List<List<CellType>> _parseHistoryRows(dynamic payload) {
    final list = _extractHistoryList(payload);
    final fallbackSelected = current.value?.selectedDays ?? const <String>[];
    final rows = <List<CellType>>[];

    for (final entry in list) {
      final row = _rowFromHistoryEntry(entry, fallbackSelected);
      if (row != null) {
        rows.add(_normalizeRow(row));
      }
    }
    return rows;
  }

  List<CellType>? _rowFromHistoryEntry(
    dynamic entry,
    List<String> fallbackSelected,
  ) {
    if (entry == null) return null;

    if (entry is List) {
      return _rowFromStatusList(entry);
    }

    if (entry is Map) {
      final nestedDays =
          entry['days'] ??
          entry['weekDays'] ??
          entry['weekdays'] ??
          (entry['week'] is Map ? (entry['week'] as Map)['days'] : null);

      final explicit =
          _rowFromStatusList(nestedDays) ?? _rowFromStatusMap(nestedDays);
      if (explicit != null) return explicit;

      final selected = _asStringList(
        entry['selectedDays'] ?? entry['selected_days'],
      );
      final completedDates = _asDateList(
        entry['completedDates'] ??
            entry['completed_dates'] ??
            entry['dates'] ??
            entry['completedDays'],
      );
      final frozenDates = _asDateList(
        entry['frozenDates'] ??
            entry['freezeDates'] ??
            entry['freeze_days'] ??
            entry['frozen_days'],
      );
      final completedCount = _asInt(
        entry['completedThisWeek'] ?? entry['completed'] ?? entry['count'],
      );

      final useSelected = selected.isNotEmpty ? selected : fallbackSelected;
      if (useSelected.isEmpty &&
          completedDates.isEmpty &&
          frozenDates.isEmpty &&
          completedCount == 0) {
        return null;
      }

      return _buildRowFromSelected(
        selectedDays: useSelected,
        completedCount: completedCount,
        completedDates: completedDates,
        frozenDates: frozenDates,
      );
    }

    return null;
  }

  void _logStreakResponse(String label, dynamic data) {
    if (!kDebugMode) return;
    final str = _stringifyResponse(data);
    debugPrint('STREAK API RESPONSE $label:');
    const chunkSize = 800;
    for (int i = 0; i < str.length; i += chunkSize) {
      final end = (i + chunkSize) < str.length ? (i + chunkSize) : str.length;
      debugPrint(str.substring(i, end));
    }
  }
}

const List<String> _orderedDays = <String>[
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
];

const List<String> _uiDayOrder = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thur',
  'Fri',
  'Sat',
  'Sun',
];

const Map<String, String> _uiToApiDay = {
  'Mon': 'mon',
  'Tue': 'tue',
  'Wed': 'wed',
  'Thur': 'thu',
  'Fri': 'fri',
  'Sat': 'sat',
  'Sun': 'sun',
};

const Map<String, String> _apiToUiDay = {
  'mon': 'Mon',
  'tue': 'Tue',
  'wed': 'Wed',
  'thu': 'Thur',
  'fri': 'Fri',
  'sat': 'Sat',
  'sun': 'Sun',
};

String _normalizeDay(String raw) {
  final value = raw.toString().trim().toLowerCase();
  switch (value) {
    case 'mon':
    case 'monday':
      return 'mon';
    case 'tue':
    case 'tues':
    case 'tuesday':
      return 'tue';
    case 'wed':
    case 'wednesday':
      return 'wed';
    case 'thu':
    case 'thur':
    case 'thurs':
    case 'thursday':
      return 'thu';
    case 'fri':
    case 'friday':
      return 'fri';
    case 'sat':
    case 'saturday':
      return 'sat';
    case 'sun':
    case 'sunday':
      return 'sun';
    default:
      return _orderedDays.contains(value) ? value : '';
  }
}

String _weekdayKey(DateTime date) {
  switch (date.weekday) {
    case DateTime.monday:
      return 'mon';
    case DateTime.tuesday:
      return 'tue';
    case DateTime.wednesday:
      return 'wed';
    case DateTime.thursday:
      return 'thu';
    case DateTime.friday:
      return 'fri';
    case DateTime.saturday:
      return 'sat';
    case DateTime.sunday:
      return 'sun';
    default:
      return 'mon';
  }
}

int? _weekdayIndexFromKey(String key) {
  final normalized = _normalizeDay(key);
  if (normalized.isEmpty) return null;
  return _orderedDays.indexOf(normalized);
}

int _weekdayIndexFromDate(DateTime date) {
  final idx = date.weekday - 1;
  if (idx < 0) return 0;
  if (idx > 6) return 6;
  return idx;
}

DateTime _stripTime(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

Map<String, dynamic> _extractStreakMap(dynamic payload) {
  dynamic data = payload;
  if (data is Map && data['data'] != null) {
    data = data['data'];
  }
  if (data is Map && data['streak'] != null) {
    data = data['streak'];
  }
  if (data is Map && data['overview'] != null) {
    data = data['overview'];
  }
  if (data is Map && data['streamStreaks'] != null) {
    data = data['streamStreaks'];
  }
  if (data is Map && data['stream_streaks'] != null) {
    data = data['stream_streaks'];
  }
  if (data is Map) {
    final pref =
        data['userPreference'] ?? data['user_preference'] ?? data['preferences'];
    if (pref is Map) {
      final notif =
          pref['notification_settings'] ??
          pref['notificationSettings'] ??
          pref['notifications'];
      if (notif is Map) {
        final streamStreaks =
            notif['streamStreaks'] ?? notif['stream_streaks'];
        if (streamStreaks is Map) {
          data = streamStreaks;
        }
      }
    }
  }
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return <String, dynamic>{};
}

List<dynamic> _extractHistoryList(dynamic payload) {
  if (payload is List) return payload;
  if (payload is Map) {
    for (final key in [
      'data',
      'history',
      'streakHistory',
      'weeks',
      'items',
      'results',
    ]) {
      final value = payload[key];
      if (value is List) return value;
    }
  }
  return const <dynamic>[];
}

Map<String, dynamic>? _extractOverviewData(dynamic payload) {
  if (payload is Map) {
    dynamic data = payload;
    if (data['data'] is Map) {
      data = data['data'];
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final hasStreak = map['streak'] is Map;
      final hasWeeklyGoal =
          map['weeklyGoal'] is Map || map['weekly_goal'] is Map;
      final hasFreeze = map['freeze'] is Map;
      if (hasStreak || hasWeeklyGoal || hasFreeze) {
        return map;
      }
    }
  }
  return null;
}

StreakData? _fromOverviewData(Map<String, dynamic> data) {
  final streakMap = _asMap(data['streak']);
  final weeklyGoal =
      _asMap(data['weeklyGoal'] ?? data['weekly_goal']);
  final freezeMap = _asMap(data['freeze']);
  if (streakMap.isEmpty && weeklyGoal.isEmpty && freezeMap.isEmpty) {
    return null;
  }

  final currentStreak = _asInt(
    streakMap['current'] ??
        streakMap['currentStreak'] ??
        streakMap['current_streak'],
  );
  final longestStreak = _asInt(
    streakMap['best'] ??
        streakMap['bestStreak'] ??
        streakMap['best_streak'] ??
        streakMap['longestStreak'] ??
        streakMap['longest_streak'],
  );
  final status = _asString(data['status'] ?? streakMap['status']);
  final isInDanger =
      _asBool(
        streakMap['inDanger'] ??
            streakMap['isInDanger'] ??
            streakMap['in_danger'] ??
            data['inDanger'] ??
            data['isInDanger'] ??
            data['in_danger'],
      ) ||
      status.toLowerCase() == 'danger';

  final targetDaysPerWeek = _asInt(
    weeklyGoal['timesPerWeek'] ??
        weeklyGoal['times_per_week'] ??
        weeklyGoal['targetDaysPerWeek'] ??
        weeklyGoal['target_days_per_week'],
  );
  final completedThisWeek = _asInt(
    weeklyGoal['completedThisWeek'] ?? weeklyGoal['completed_this_week'],
  );
  final remainingThisWeek = _asInt(
    weeklyGoal['remainingThisWeek'] ?? weeklyGoal['remaining_this_week'],
    fallback:
        (targetDaysPerWeek - completedThisWeek) < 0
            ? 0
            : (targetDaysPerWeek - completedThisWeek),
  );

  final weekList =
      weeklyGoal['week'] ??
      weeklyGoal['days'] ??
      weeklyGoal['weekDays'] ??
      weeklyGoal['week_days'];
  var weekGrid = const <CellType>[];
  final completedDates = List<DateTime>.from(
    _asDateList(
      streakMap['history'] ??
          streakMap['historyDates'] ??
          streakMap['history_dates'] ??
          streakMap['completedDates'] ??
          streakMap['completed_dates'] ??
          data['history'] ??
          data['historyDates'] ??
          data['history_dates'] ??
          data['completedDates'] ??
          data['completed_dates'],
    ),
  );
  final frozenDates = List<DateTime>.from(
    _asDateList(
      streakMap['frozenDates'] ??
          streakMap['freezeDates'] ??
          streakMap['frozen_dates'] ??
          streakMap['freeze_days'] ??
          data['frozenDates'] ??
          data['freezeDates'] ??
          data['frozen_dates'] ??
          data['freeze_days'],
    ),
  );
  DateTime? weekStartDate;
  DateTime? lastCompletedDate = _parseDate(
    streakMap['lastCheckInDate'] ??
        streakMap['last_check_in_date'] ??
        streakMap['lastCheckInAt'] ??
        streakMap['lastCompletedDate'] ??
        streakMap['last_completed_date'] ??
        streakMap['lastCompletedAt'] ??
        data['lastCheckInDate'] ??
        data['last_check_in_date'] ??
        data['lastCheckInAt'] ??
        data['lastCompletedDate'] ??
        data['last_completed_date'] ??
        data['lastCompletedAt'],
  );
  if (weekList is List) {
    final row = List<CellType>.filled(7, CellType.cross);
    for (var i = 0; i < weekList.length && i < 7; i++) {
      final day = _asMap(weekList[i]);
      final completed = _asBool(day['completed']);
      final frozen = _asBool(day['frozen']);
      final date = _parseDate(day['date']);
      final cell =
          frozen ? CellType.freeze : (completed ? CellType.tick : CellType.cross);
      final idx = date != null ? _weekdayIndexFromDate(date) : i;
      row[idx] = cell;
      if (date != null) {
        weekStartDate ??= _startOfWeek(date);
        if (completed) {
          if (!completedDates.any(
            (d) => _isSameDay(_stripTime(d), _stripTime(date)),
          )) {
            completedDates.add(date);
          }
          if (lastCompletedDate == null ||
              lastCompletedDate.isBefore(date)) {
            lastCompletedDate = date;
          }
        }
        if (frozen) {
          if (!frozenDates.any(
            (d) => _isSameDay(_stripTime(d), _stripTime(date)),
          )) {
            frozenDates.add(date);
          }
        }
      }
    }
    weekGrid = _normalizeRow(row);
  }

  weekStartDate ??= _parseDate(
    weeklyGoal['weekStart'] ?? weeklyGoal['week_start'],
  );
  final lastCheckIn = lastCompletedDate;
  if (lastCheckIn != null &&
      !completedDates.any(
        (d) => _isSameDay(_stripTime(d), _stripTime(lastCheckIn)),
      )) {
    completedDates.add(lastCheckIn);
  }

  final freezeAllowancePerMonth = _asInt(
    freezeMap['allowancePerMonth'] ??
        freezeMap['allowance_per_month'],
  );
  final freezeUsedThisMonth = _asInt(
    freezeMap['usedThisMonth'] ?? freezeMap['used_this_month'],
  );
  final freezeAvailable = _asInt(
    freezeMap['available'],
    fallback:
        (freezeAllowancePerMonth - freezeUsedThisMonth) < 0
            ? 0
            : (freezeAllowancePerMonth - freezeUsedThisMonth),
  );

  return StreakData(
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    selectedDays: const <String>[],
    targetDaysPerWeek: targetDaysPerWeek,
    completedThisWeek: completedThisWeek,
    remainingThisWeek: remainingThisWeek,
    freezeTokens: freezeAvailable,
    freezeAllowancePerMonth: freezeAllowancePerMonth,
    freezeUsedThisMonth: freezeUsedThisMonth,
    status: status,
    isInDanger: isInDanger,
    weekStartDate: weekStartDate,
    lastCompletedDate: lastCompletedDate,
    completedDates: completedDates,
    frozenDates: frozenDates,
    weekGrid: weekGrid,
    raw: data,
  );
}

List<CellType>? _extractWeekGrid(Map<String, dynamic> map) {
  dynamic raw =
      map['weekGrid'] ??
      map['week_grid'] ??
      map['week'] ??
      map['currentWeek'] ??
      map['current_week'] ??
      map['grid'] ??
      map['weekDays'] ??
      map['weekdays'];

  if (raw == null && map['ui'] is Map) {
    final ui = map['ui'] as Map;
    raw =
        ui['weekGrid'] ??
        ui['week_grid'] ??
        ui['week'] ??
        ui['currentWeek'] ??
        ui['current_week'] ??
        ui['grid'];
  }

  if (raw == null && map['state'] is Map) {
    final state = map['state'] as Map;
    raw =
        state['weekGrid'] ??
        state['week_grid'] ??
        state['week'] ??
        state['currentWeek'] ??
        state['current_week'];
  }

  if (raw is Map && raw['days'] != null) {
    raw = raw['days'];
  }

  return _rowFromStatusList(raw) ?? _rowFromStatusMap(raw);
}

int _countCompletedFromWeekGrid(List<CellType> row) {
  var count = 0;
  for (final cell in row) {
    if (cell == CellType.tick || cell == CellType.freeze) {
      count++;
    }
  }
  return count;
}

int _countCompletedFromDates({
  required List<DateTime> historyDates,
  required List<DateTime> frozenDates,
  DateTime? weekStart,
}) {
  final start = _startOfWeek(weekStart ?? DateTime.now());
  var count = 0;
  for (final d in historyDates) {
    if (_isSameDay(_startOfWeek(d), start)) {
      count++;
    }
  }
  for (final d in frozenDates) {
    if (_isSameDay(_startOfWeek(d), start)) {
      count++;
    }
  }
  return count;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    return v == 'true' || v == '1' || v == 'yes';
  }
  return false;
}

String _asString(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value
        .map((e) => _normalizeDay(e.toString()))
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (value is String && value.contains(',')) {
    return value
        .split(',')
        .map((e) => _normalizeDay(e))
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value.trim());
  }
  if (value is num) {
    final raw = value.toInt();
    if (raw == 0) return null;
    final isMillis = raw > 1000000000000;
    return DateTime.fromMillisecondsSinceEpoch(
      isMillis ? raw : raw * 1000,
      isUtc: true,
    ).toLocal();
  }
  return null;
}

List<DateTime> _asDateList(dynamic value) {
  if (value is List) {
    return value
        .map(_parseDate)
        .whereType<DateTime>()
        .toList();
  }
  final single = _parseDate(value);
  if (single != null) return [single];
  return const <DateTime>[];
}

CellType _cellFromStatus(dynamic value) {
  if (value is CellType) return value;
  if (value is bool) return value ? CellType.tick : CellType.cross;
  if (value is num) {
    if (value == 1) return CellType.tick;
    if (value == 2) return CellType.freeze;
    if (value == 3) return CellType.dot;
    return CellType.cross;
  }
  final s = value.toString().trim().toLowerCase();
  switch (s) {
    case 'tick':
    case 'done':
    case 'complete':
    case 'completed':
    case 'success':
    case '1':
    case 'true':
      return CellType.tick;
    case 'freeze':
    case 'frozen':
      return CellType.freeze;
    case 'dot':
    case 'pending':
    case 'scheduled':
      return CellType.dot;
    case 'cross':
    case 'missed':
    case 'skipped':
    case '0':
    case 'false':
    default:
      return CellType.cross;
  }
}

List<CellType>? _rowFromStatusList(dynamic value) {
  if (value is List) {
    final row = value.map(_cellFromStatus).toList();
    if (row.length == 7) return row;
  }
  return null;
}

List<CellType>? _rowFromStatusMap(dynamic value) {
  if (value is Map) {
    final row = List<CellType>.filled(7, CellType.cross);
    var used = false;
    value.forEach((key, status) {
      int? idx;
      if (key is int) {
        idx = key;
      } else if (key is String) {
        idx = _weekdayIndexFromKey(key);
      }
      if (idx == null || idx < 0 || idx > 6) return;
      row[idx] = _cellFromStatus(status);
      used = true;
    });
    return used ? row : null;
  }
  return null;
}

List<CellType> _normalizeRow(List<CellType> row) {
  if (row.length == 7) return row;
  final normalized = List<CellType>.filled(7, CellType.cross);
  for (int i = 0; i < row.length && i < 7; i++) {
    normalized[i] = row[i];
  }
  return normalized;
}

List<CellType> _buildRowFromSelected({
  required List<String> selectedDays,
  required int completedCount,
  List<DateTime> completedDates = const <DateTime>[],
  List<DateTime> frozenDates = const <DateTime>[],
}) {
  final row = List<CellType>.filled(7, CellType.cross);
  final selectedSet = selectedDays
      .map(_normalizeDay)
      .where((d) => d.isNotEmpty)
      .toSet();

  for (int i = 0; i < _orderedDays.length; i++) {
    if (selectedSet.contains(_orderedDays[i])) {
      row[i] = CellType.dot;
    }
  }

  if (completedDates.isNotEmpty) {
    for (final d in completedDates) {
      final idx = _weekdayIndexFromDate(d);
      row[idx] = CellType.tick;
    }
  } else if (completedCount > 0) {
    var remaining = completedCount;
    for (int i = 0; i < _orderedDays.length && remaining > 0; i++) {
      if (selectedSet.contains(_orderedDays[i])) {
        row[i] = CellType.tick;
        remaining--;
      }
    }
  }

  if (frozenDates.isNotEmpty) {
    for (final d in frozenDates) {
      final idx = _weekdayIndexFromDate(d);
      row[idx] = CellType.freeze;
    }
  }

  return row;
}

DateTime _startOfWeek(DateTime date) {
  final local = _stripTime(date);
  final diff = local.weekday - DateTime.monday;
  return local.subtract(Duration(days: diff < 0 ? 0 : diff));
}

List<CellType> _buildWeekRowFromDates({
  required DateTime weekStart,
  required List<DateTime> historyDates,
  required List<DateTime> frozenDates,
}) {
  final row = List<CellType>.filled(7, CellType.cross);
  for (final d in historyDates) {
    final start = _startOfWeek(d);
    if (_isSameDay(start, weekStart)) {
      row[_weekdayIndexFromDate(d)] = CellType.tick;
    }
  }
  for (final d in frozenDates) {
    final start = _startOfWeek(d);
    if (_isSameDay(start, weekStart)) {
      row[_weekdayIndexFromDate(d)] = CellType.freeze;
    }
  }
  return row;
}

List<List<CellType>> _buildHistoryRowsFromDates(StreakData data) {
  final rowsByWeek = <DateTime, List<CellType>>{};

  for (final d in data.completedDates) {
    final start = _startOfWeek(d);
    final row =
        rowsByWeek.putIfAbsent(
          start,
          () => List<CellType>.filled(7, CellType.cross),
        );
    row[_weekdayIndexFromDate(d)] = CellType.tick;
  }

  for (final d in data.frozenDates) {
    final start = _startOfWeek(d);
    final row =
        rowsByWeek.putIfAbsent(
          start,
          () => List<CellType>.filled(7, CellType.cross),
        );
    row[_weekdayIndexFromDate(d)] = CellType.freeze;
  }

  final currentWeekStart =
      data.weekStartDate != null
          ? _startOfWeek(data.weekStartDate!)
          : _startOfWeek(DateTime.now());
  rowsByWeek.removeWhere((key, _) => _isSameDay(key, currentWeekStart));

  final keys = rowsByWeek.keys.toList()
    ..sort((a, b) => b.compareTo(a));
  return keys.map((k) => _normalizeRow(rowsByWeek[k]!)).toList();
}

String _stringifyResponse(dynamic data) {
  if (data == null) return 'null';
  if (data is String) return data;
  try {
    return const JsonEncoder.withIndent('  ').convert(data);
  } catch (_) {
    try {
      return data.toString();
    } catch (_) {
      return 'unprintable_response';
    }
  }
}
