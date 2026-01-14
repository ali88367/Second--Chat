import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:second_chat/core/widgets/custom_switch.dart';

/// Added CellType for Calendar logic
enum CellType { tick, cross, dot, freeze }

class StreamStreaksController extends GetxController {
  var selectedDays = <String, bool>{
    'Mon': false,
    'Tue': false,
    'Wed': false,
    'Thur': false,
    'Fri': false,
    'Sat': false,
    'Sun': false,
  }.obs;

  var threeTimesWeek = false.obs;
  var isSelectingThreeDays = false.obs;

  /// Interactive menu numbers
  var selectedMenuNumbers = <int>[].obs;

  int get selectedCount => selectedMenuNumbers.length;

  List<int> get availableMenuNumbers => List.generate(7, (i) => i + 1)
      .where((n) => !selectedMenuNumbers.contains(n))
      .toList();

  bool get areDaysDisabled => threeTimesWeek.value;

  // --- NEW CALENDAR STATE FOR ALL SCREENS ---

  /// Multi-row state (Screen 1)
  final calendarRows = <RxList<CellType>>[
    RxList.of([CellType.tick, CellType.cross, CellType.tick, CellType.tick, CellType.cross, CellType.freeze, CellType.cross]),
    RxList.of([CellType.cross, CellType.cross, CellType.cross, CellType.tick, CellType.tick, CellType.tick, CellType.cross]),
    RxList.of(List.generate(7, (_) => CellType.tick)),
    RxList.of([CellType.tick, CellType.tick, CellType.tick, CellType.dot, CellType.dot, CellType.dot, CellType.dot]),
    RxList.of(List.generate(7, (_) => CellType.dot)),
  ];

  /// Single-row state (Screens 2 & 3)
  final singleRowCells = RxList<CellType>.of([
    CellType.tick, CellType.cross, CellType.tick, CellType.tick, CellType.tick, CellType.cross, CellType.cross,
  ]);

  final lastTappedRow = RxnInt();
  final lastTappedCol = RxnInt();

  // --- EXISTING LOGIC ---

  void toggleMenuNumber(int number) {
    if (selectedMenuNumbers.contains(number)) {
      selectedMenuNumbers.remove(number);
    } else {
      if (selectedMenuNumbers.length < 3) {
        selectedMenuNumbers.add(number);
      }
    }

    if (selectedMenuNumbers.length == 3) {
      isSelectingThreeDays.value = false;
      threeTimesWeek.value = true;
      syncMenuToDays();
    }
  }

  void toggleDay(String day) {
    if (areDaysDisabled) return;
    selectedDays[day] = !selectedDays[day]!;
    selectedDays.refresh();
  }

  void toggleThreeTimesWeek(bool value) {
    threeTimesWeek.value = value;

    if (value) {
      isSelectingThreeDays.value = true;
      selectedMenuNumbers.clear();
      selectedDays.updateAll((key, value) => false);
    } else {
      isSelectingThreeDays.value = false;
      selectedMenuNumbers.clear();
    }
  }

  void syncMenuToDays() {
    if (!threeTimesWeek.value) return;

    final days = selectedDays.keys.toList();
    selectedDays.updateAll((key, value) => false);

    for (final n in selectedMenuNumbers) {
      selectedDays[days[n - 1]] = true;
    }

    selectedDays.refresh();
  }

  // --- NEW CALENDAR ACTIONS ---

  void toggleCalendarCell(int rowIdx, int colIdx, {bool isSingleRow = false}) {
    final targetRow = isSingleRow ? singleRowCells : calendarRows[rowIdx];
    final current = targetRow[colIdx];

    if (current == CellType.cross) {
      targetRow[colIdx] = CellType.tick;
      lastTappedRow.value = rowIdx;
      lastTappedCol.value = colIdx;
    } else if (current == CellType.tick) {
      targetRow[colIdx] = CellType.cross;
      if (lastTappedRow.value == rowIdx && lastTappedCol.value == colIdx) {
        lastTappedCol.value = null;
      }
    }
  }

  /// Unified Grouping Logic for Highlighting
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
}