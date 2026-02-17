import 'package:get/get.dart';

enum CellType { tick, cross, dot, freeze }

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

  List<int> get availableNumbers =>
      _fullNumberList.where((n) => !selectedMenuNumbers.contains(n)).toList();
  int get selectedCount => selectedMenuNumbers.length;
  bool get areDaysDisabled => false;
  int get selectedDaysCount => selectedDays.values.where((v) => v).length;
  bool get isThreeTimesSelectionComplete =>
      !threeTimesWeek.value ||
      (selectedTimesPerWeek.value > 0 &&
          selectedDaysCount == selectedTimesPerWeek.value);

  final calendarRows = <RxList<CellType>>[
    RxList.of([
      CellType.cross,
      CellType.cross,
      CellType.tick,
      CellType.tick,
      CellType.cross,
      CellType.freeze,
      CellType.cross,
    ]),
    RxList.of([
      CellType.cross,
      CellType.cross,
      CellType.cross,
      CellType.tick,
      CellType.tick,
      CellType.tick,
      CellType.cross,
    ]),
    // Row 3: Monday-Friday streak only
    RxList.of([
      CellType.tick, // Mon
      CellType.tick, // Tue
      CellType.tick, // Wed
      CellType.tick, // Thur
      CellType.tick, // Fri
      CellType.cross, // Sat
      CellType.cross, // Sun
    ]),
    // Row 4: All crosses
    RxList.of(List.generate(7, (_) => CellType.cross)),
  ];

  final singleRowCells = RxList<CellType>.of(
    List.generate(7, (_) => CellType.dot),
  );

  final lastTappedRow = RxnInt();
  final lastTappedCol = RxnInt();

  RxInt refreshTrigger = 0.obs;
  RxInt manualFreezeCount = 0.obs;
  RxInt longestStreak = 0.obs;
  RxInt bestWeekIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    calculateLongestStreak();
    updateFreezeCount();
  }

  void calculateLongestStreak() {
    int maxStreakOverall = 0;
    int bestIdx = 0;
    for (int i = 0; i < calendarRows.length; i++) {
      int currentWeekMax = 0;
      int tempCount = 0;
      for (var cell in calendarRows[i]) {
        if (cell == CellType.tick) {
          tempCount++;
          if (tempCount > currentWeekMax) currentWeekMax = tempCount;
        } else {
          tempCount = 0;
        }
      }
      if (currentWeekMax > maxStreakOverall) {
        maxStreakOverall = currentWeekMax;
        bestIdx = i;
      }
    }
    longestStreak.value = maxStreakOverall;
    bestWeekIndex.value = bestIdx;
    singleRowCells.assignAll(calendarRows[bestIdx]);
    refreshTrigger.value++;
  }

  void updateFreezeCount() {
    int count = 0;
    for (var row in calendarRows) {
      count += row.where((cell) => cell == CellType.freeze).length;
    }
    manualFreezeCount.value = count;
  }

  void addFreezeAfterStreak() {
    // Check if we have freezes available
    if (manualFreezeCount.value >= 3) return;

    final targetWeek = calendarRows[bestWeekIndex.value];

    // 1. Find the rightmost (last) tick index in the best week
    int lastTickIndex = targetWeek.lastIndexOf(CellType.tick);

    // 2. The "day next to the last day" is lastTickIndex + 1
    int nextDayIndex = lastTickIndex + 1;

    // 3. Ensure the next day is within the 7-day bounds and not already a tick
    if (nextDayIndex < targetWeek.length) {
      targetWeek[nextDayIndex] = CellType.freeze;

      targetWeek.refresh();
      updateFreezeCount();
      calculateLongestStreak(); // Recalculate to update the singleRowCells preview
    }
  }

  void toggleCalendarCell(int rowIdx, int colIdx, {bool isSingleRow = false}) {
    lastTappedCol.value = colIdx;
    if (!isSingleRow) lastTappedRow.value = rowIdx;

    int actualRow = isSingleRow ? bestWeekIndex.value : rowIdx;
    final RxList<CellType> targetRow = calendarRows[actualRow];
    final CellType current = targetRow[colIdx];

    if (current == CellType.freeze) {
      targetRow[colIdx] = CellType.cross;
    } else if (manualFreezeCount.value < 3) {
      targetRow[colIdx] = CellType.freeze;
    }

    targetRow.refresh();
    updateFreezeCount();
    calculateLongestStreak();
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

  // Call this when popup is closed to clear selections if less than 3 are selected
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
