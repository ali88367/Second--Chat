import 'package:dio/dio.dart';
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
    required this.status,
    required this.isInDanger,
    required this.weekStartDate,
    required this.lastCompletedDate,
    required this.completedDates,
    required this.frozenDates,
    this.raw,
  });

  final int currentStreak;
  final int longestStreak;
  final List<String> selectedDays;
  final int targetDaysPerWeek;
  final int completedThisWeek;
  final int remainingThisWeek;
  final int freezeTokens;
  final String status;
  final bool isInDanger;
  final DateTime? weekStartDate;
  final DateTime? lastCompletedDate;
  final List<DateTime> completedDates;
  final List<DateTime> frozenDates;
  final Map<String, dynamic>? raw;

  bool get isConfigured {
    if (selectedDays.isNotEmpty) return true;
    if (targetDaysPerWeek > 0) return true;
    if (currentStreak > 0 || longestStreak > 0) return true;
    if (status.isNotEmpty && status.toLowerCase() != 'inactive') return true;
    return false;
  }

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

  StreakData copyWith({
    int? currentStreak,
    int? longestStreak,
    List<String>? selectedDays,
    int? targetDaysPerWeek,
    int? completedThisWeek,
    int? remainingThisWeek,
    int? freezeTokens,
    String? status,
    bool? isInDanger,
    DateTime? weekStartDate,
    DateTime? lastCompletedDate,
    List<DateTime>? completedDates,
    List<DateTime>? frozenDates,
  }) {
    return StreakData(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      selectedDays: selectedDays ?? this.selectedDays,
      targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
      completedThisWeek: completedThisWeek ?? this.completedThisWeek,
      remainingThisWeek: remainingThisWeek ?? this.remainingThisWeek,
      freezeTokens: freezeTokens ?? this.freezeTokens,
      status: status ?? this.status,
      isInDanger: isInDanger ?? this.isInDanger,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      completedDates: completedDates ?? this.completedDates,
      frozenDates: frozenDates ?? this.frozenDates,
      raw: raw,
    );
  }

  factory StreakData.fromPayload(dynamic payload) {
    final map = _extractStreakMap(payload);
    final selectedDays = _asStringList(
      map['selectedDays'] ?? map['selected_days'],
    );
    final status = _asString(map['status']);
    final isInDanger =
        _asBool(map['isInDanger']) || status.toLowerCase() == 'danger';
    final weekStartRaw = _asString(
      map['weekStartDate'] ??
          map['week_start_date'] ??
          map['weekStart'] ??
          map['week_start'],
    );
    final weekStartDate =
        weekStartRaw.isEmpty ? null : DateTime.tryParse(weekStartRaw);
    final lastCompletedRaw = _asString(
      map['lastCompletedDate'] ??
          map['lastCompletedAt'] ??
          map['lastCompletionDate'] ??
          map['lastCompletionAt'],
    );
    final lastCompletedDate =
        lastCompletedRaw.isEmpty ? null : DateTime.tryParse(lastCompletedRaw);
    final completedDates = _asDateList(
      map['completedDates'] ??
          map['completed_dates'] ??
          map['completedDays'] ??
          map['completed_days'],
    );
    final frozenDates = _asDateList(
      map['frozenDates'] ??
          map['freezeDates'] ??
          map['frozen_dates'] ??
          map['freeze_days'],
    );

    final currentStreak = _asInt(map['currentStreak']);
    final longestStreak = _asInt(map['longestStreak']);
    final completedThisWeek = _asInt(
      map['completedThisWeek'] ?? map['completed_this_week'],
    );
    final targetDaysPerWeek = _asInt(
      map['targetDaysPerWeek'] ?? map['target_days_per_week'],
      fallback: selectedDays.length,
    );
    final remainingThisWeek = _asInt(
      map['remainingThisWeek'] ?? map['remaining_this_week'],
      fallback: (targetDaysPerWeek - completedThisWeek)
          .clamp(0, targetDaysPerWeek),
    );
    final freezeTokens = _asInt(
      map['freezeTokens'] ??
          map['remainingFreezes'] ??
          map['remaining_freezes'] ??
          map['freezesRemaining'] ??
          map['freeze_tokens'],
    );

    return StreakData(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      selectedDays: selectedDays,
      targetDaysPerWeek: targetDaysPerWeek,
      completedThisWeek: completedThisWeek,
      remainingThisWeek: remainingThisWeek,
      freezeTokens: freezeTokens,
      status: status,
      isInDanger: isInDanger,
      weekStartDate: weekStartDate,
      lastCompletedDate: lastCompletedDate,
      completedDates: completedDates,
      frozenDates: frozenDates,
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
  bool get hasStreak => current.value?.isConfigured ?? false;

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
        return null;
      }

      final auth = Get.find<AuthController>();
      final res = await auth.api.client.dio.get<dynamic>(
        '/api/v1/streak',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      final snapshot = StreakData.fromPayload(res.data);
      current.value = snapshot.isConfigured ? snapshot : null;
      return current.value;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        current.value = null;
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
      final accessToken = await _getAccessToken(showErrors: !silent);
      if (accessToken == null || accessToken.isEmpty) {
        historyRows.clear();
        return historyRows;
      }

      final auth = Get.find<AuthController>();
      final res = await auth.api.client.dio.get<dynamic>(
        '/api/v1/streak/history',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      final rows = _parseHistoryRows(res.data);
      historyRows.assignAll(rows);
      return historyRows;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        debugPrint('STREAK HISTORY ERROR: ${e.response?.data ?? e.message}');
      }
      if (!silent) {
        _showConnectionIssue();
      }
    } catch (e) {
      debugPrint('STREAK HISTORY ERROR: $e');
      if (!silent) {
        _showConnectionIssue();
      }
    } finally {
      isHistoryLoading.value = false;
    }
    return historyRows;
  }

  Future<bool> createStreak({
    required List<String> selectedDays,
    required int targetDaysPerWeek,
    bool showErrors = true,
  }) async {
    if (isMutating.value) return false;
    isMutating.value = true;
    try {
      final accessToken = await _getAccessToken(showErrors: showErrors);
      if (accessToken == null || accessToken.isEmpty) return false;

      final auth = Get.find<AuthController>();
      await auth.api.client.dio.post<dynamic>(
        '/api/v1/streak',
        data: {
          'selectedDays': selectedDays,
          'targetDaysPerWeek': targetDaysPerWeek,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      await fetchCurrentStreak(force: true, silent: true);
      await fetchHistory(force: true, silent: true);
      return true;
    } on DioException catch (e) {
      debugPrint('STREAK CREATE ERROR: ${e.response?.data ?? e.message}');
      if (showErrors) {
        _showConnectionIssue();
      }
    } catch (e) {
      debugPrint('STREAK CREATE ERROR: $e');
      if (showErrors) {
        _showConnectionIssue();
      }
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
      final accessToken = await _getAccessToken(showErrors: showErrors);
      if (accessToken == null || accessToken.isEmpty) return false;

      final auth = Get.find<AuthController>();
      await auth.api.client.dio.patch<dynamic>(
        '/api/v1/streak',
        data: {'selectedDays': selectedDays},
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      await fetchCurrentStreak(force: true, silent: true);
      await fetchHistory(force: true, silent: true);
      return true;
    } on DioException catch (e) {
      debugPrint('STREAK UPDATE ERROR: ${e.response?.data ?? e.message}');
      if (showErrors) {
        _showConnectionIssue();
      }
    } catch (e) {
      debugPrint('STREAK UPDATE ERROR: $e');
      if (showErrors) {
        _showConnectionIssue();
      }
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

    final todayKey = _weekdayKey(date);
    if (!currentStreak.selectedDays.contains(todayKey)) {
      return const StreakCompleteResult(
        success: false,
        alreadyCompleted: false,
        skipped: true,
        message: 'not_scheduled',
      );
    }

    if (currentStreak.isDateCompleted(date)) {
      return const StreakCompleteResult(
        success: false,
        alreadyCompleted: true,
        skipped: false,
        message: 'already_completed',
      );
    }

    try {
      final auth = Get.find<AuthController>();
      await auth.api.client.dio.post<dynamic>(
        '/api/v1/streak/complete',
        data: {'date': _formatDate(date)},
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      await fetchCurrentStreak(force: true, silent: true);
      await fetchHistory(force: true, silent: true);

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

  Future<bool> freezeStreak({bool showErrors = true}) async {
    if (isMutating.value) return false;
    isMutating.value = true;
    try {
      final accessToken = await _getAccessToken(showErrors: showErrors);
      if (accessToken == null || accessToken.isEmpty) return false;

      final auth = Get.find<AuthController>();
      final res = await auth.api.client.dio.post<dynamic>(
        '/api/v1/streak/freeze',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      final snapshot = StreakData.fromPayload(res.data);
      if (snapshot.isConfigured) {
        current.value = snapshot;
      }

      await fetchCurrentStreak(force: true, silent: true);
      await fetchHistory(force: true, silent: true);
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
    return _buildRowFromSelected(
      selectedDays: streak.selectedDays,
      completedCount: streak.completedThisWeek,
      completedDates: streak.completedDates,
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
