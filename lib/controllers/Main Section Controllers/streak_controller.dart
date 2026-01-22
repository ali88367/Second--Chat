import 'package:get/get.dart';

enum CellType { tick, cross, dot, freeze }

class StreamStreaksController extends GetxController {
  var selectedDays = <String, bool>{
    'Mon': false, 'Tue': false, 'Wed': false, 'Thur': false, 'Fri': false, 'Sat': false, 'Sun': false,
  }.obs;

  RxBool threeTimesWeek = false.obs;
  RxBool isSelectingThreeDays = false.obs;
  RxList<int> selectedMenuNumbers = <int>[].obs;
  final List<int> _fullNumberList = [1, 2, 3, 4, 5, 6, 7];

  List<int> get availableNumbers => _fullNumberList.where((n) => !selectedMenuNumbers.contains(n)).toList();
  int get selectedCount => selectedMenuNumbers.length;
  bool get areDaysDisabled => threeTimesWeek.value;

  final calendarRows = <RxList<CellType>>[
    RxList.of([CellType.tick, CellType.cross, CellType.tick, CellType.tick, CellType.cross, CellType.freeze, CellType.cross]),
    RxList.of([CellType.cross, CellType.cross, CellType.cross, CellType.tick, CellType.tick, CellType.tick, CellType.cross]),
    RxList.of(List.generate(7, (_) => CellType.tick)),
    RxList.of([CellType.tick, CellType.tick, CellType.tick, CellType.dot, CellType.dot, CellType.dot, CellType.dot]),
  ];

  final singleRowCells = RxList<CellType>.of(List.generate(7, (_) => CellType.dot));

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

  // UPDATED: Now replaces the rightmost tick with a freeze
  void addFreezeAfterStreak() {
    if (manualFreezeCount.value >= 3) return;

    final targetWeek = calendarRows[bestWeekIndex.value];

    // Find the rightmost (last) tick index in the best week
    int lastTickIndex = targetWeek.lastIndexOf(CellType.tick);

    if (lastTickIndex != -1) {
      // Replace that tick with a freeze
      targetWeek[lastTickIndex] = CellType.freeze;

      targetWeek.refresh();
      updateFreezeCount();
      calculateLongestStreak();
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
    if (selectedMenuNumbers.contains(number)) {
      selectedMenuNumbers.remove(number);
    } else {
      if (selectedMenuNumbers.length < 3) { selectedMenuNumbers.add(number); }
    }
    if (selectedMenuNumbers.length == 3) {
      threeTimesWeek.value = true;
      isSelectingThreeDays.value = false;
      syncMenuToDays();
    } else {
      threeTimesWeek.value = false;
    }
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

  void syncMenuToDays() {
    if (!threeTimesWeek.value) return;
    final dayKeys = selectedDays.keys.toList();
    selectedDays.updateAll((key, value) => false);
    for (final n in selectedMenuNumbers) {
      if (n > 0 && n <= dayKeys.length) {
        selectedDays[dayKeys[n - 1]] = true;
      }
    }
    selectedDays.refresh();
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