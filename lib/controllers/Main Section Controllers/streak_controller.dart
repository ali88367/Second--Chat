import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum CellType { tick, cross, dot, freeze }

class StreamStreaksController extends GetxController {
  // --- SELECTION STATE ---
  var selectedDays = <String, bool>{
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

  // Logic tracking for the glass menu
  // These are the numbers that have been tapped and moved "UP"
  RxList<int> selectedMenuNumbers = <int>[].obs;

  // The master list of all possible numbers (1-7)
  final List<int> _fullNumberList = [1, 2, 3, 4, 5, 6, 7];

  // --- GETTERS ---

  // Numbers that are NOT selected (to be shown in the bottom section of the menu)
  // This updates automatically whenever selectedMenuNumbers changes
  List<int> get availableNumbers =>
      _fullNumberList.where((n) => !selectedMenuNumbers.contains(n)).toList();

  int get selectedCount => selectedMenuNumbers.length;
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
  RxInt manualFreezeCount = 0.obs;

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

  // --- UPDATED SELECTION LOGIC ---

  /// Handles moving numbers between the top and bottom sections of the menu
  void toggleMenuNumber(int number) {
    if (selectedMenuNumbers.contains(number)) {
      // If already selected, remove it (it moves back down)
      selectedMenuNumbers.remove(number);
    } else {
      // If not selected, move it to the top (limit to 3)
      if (selectedMenuNumbers.length < 3) {
        selectedMenuNumbers.add(number);
      }
    }

    // Set main switch state based on whether we hit the goal of 3 selections
    if (selectedMenuNumbers.length == 3) {
      threeTimesWeek.value = true;
      isSelectingThreeDays.value = false;
      syncMenuToDays(); // Map 1,2,3... to Mon,Tue,Wed...
    } else {
      threeTimesWeek.value = false;
    }

    // Refresh the lists to ensure the UI rebuilds
    selectedMenuNumbers.refresh();
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

  /// Synchronizes the selected numbers (1-7) to the actual day keys (Mon-Sun)
  void syncMenuToDays() {
    if (!threeTimesWeek.value) return;
    final dayKeys = selectedDays.keys.toList();

    // Reset all days first
    selectedDays.updateAll((key, value) => false);

    // Turn on the days corresponding to the selected numbers
    for (final n in selectedMenuNumbers) {
      if (n > 0 && n <= dayKeys.length) {
        selectedDays[dayKeys[n - 1]] = true;
      }
    }
    selectedDays.refresh();
  }

  // --- CALENDAR LOGIC ---
  void toggleCalendarCell(int rowIdx, int colIdx, {bool isSingleRow = false}) {
    final RxList<CellType> targetRow = isSingleRow ? singleRowCells : calendarRows[rowIdx];
    final CellType current = targetRow[colIdx];

    if (current == CellType.freeze) {
      targetRow[colIdx] = CellType.cross;
      manualFreezeCount.value--;
      targetRow.refresh();
      return;
    }

    if (manualFreezeCount.value < 3) {
      targetRow[colIdx] = CellType.freeze;
      manualFreezeCount.value++;
      targetRow.refresh();
    }
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
}