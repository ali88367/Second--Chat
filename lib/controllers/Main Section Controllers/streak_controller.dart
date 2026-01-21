import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

  // --- INTERACTIVE MENU NUMBERS ---
  int get selectedCount => selectedMenuNumbers.length;

  List<int> get availableMenuNumbers => List.generate(7, (i) => i + 1)
      .where((n) => !selectedMenuNumbers.contains(n))
      .toList();

  bool get areDaysDisabled => threeTimesWeek.value;

  // --- CALENDAR STATE ---
  final calendarRows = <RxList<CellType>>[
    RxList.of([CellType.tick, CellType.cross, CellType.tick, CellType.tick, CellType.cross, CellType.freeze, CellType.cross]),
    RxList.of([CellType.cross, CellType.cross, CellType.cross, CellType.tick, CellType.tick, CellType.tick, CellType.cross]),
    RxList.of(List.generate(7, (_) => CellType.tick)),
    RxList.of([CellType.tick, CellType.tick, CellType.tick, CellType.dot, CellType.dot, CellType.dot, CellType.dot]),
  ];

  final singleRowCells = RxList<CellType>.of([
    CellType.tick, CellType.cross, CellType.tick, CellType.tick, CellType.tick, CellType.cross, CellType.cross,
  ]);

  final lastTappedRow = RxnInt();
  final lastTappedCol = RxnInt();

  // Track active freezes
  RxInt manualFreezeCount = 0.obs;

  RxBool threeTimesWeek = false.obs;
  RxBool isSelectingThreeDays = false.obs;
  RxList<int> selectedMenuNumbers = <int>[].obs;

  @override
  void onInit() {
    super.onInit();
    _calculateInitialFreezes();
  }

  void _calculateInitialFreezes() {
    int count = 0;
    for (var row in calendarRows) {
      count += row.where((cell) => cell == CellType.freeze).length;
    }
    manualFreezeCount.value = count;
  }

  // --- SELECTION LOGIC ---
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

  // --- UPDATED CALENDAR LOGIC (SNACKBAR REMOVED) ---
  void toggleCalendarCell(int rowIdx, int colIdx, {bool isSingleRow = false}) {
    final RxList<CellType> targetRow = isSingleRow ? singleRowCells : calendarRows[rowIdx];
    final CellType current = targetRow[colIdx];

    // 1. FREEZE -> CROSS (Revert and refund count)
    if (current == CellType.freeze) {
      targetRow[colIdx] = CellType.cross;
      manualFreezeCount.value--;

      if (lastTappedRow.value == rowIdx && lastTappedCol.value == colIdx) {
        lastTappedCol.value = null;
      }

      targetRow.refresh();
      return;
    }

    // 2. TICK, CROSS or DOT -> FREEZE
    if (current == CellType.tick || current == CellType.cross || current == CellType.dot) {
      // Only proceed if we haven't hit the 3-freeze limit
      if (manualFreezeCount.value < 3) {
        targetRow[colIdx] = CellType.freeze;
        manualFreezeCount.value++;

        lastTappedRow.value = rowIdx;
        lastTappedCol.value = colIdx;

        targetRow.refresh();
      }
      // Snackbar removed from here. If limit is hit, nothing happens.
      return;
    }
  }

  // Highlighting Logic: Only looks for CellType.tick.
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