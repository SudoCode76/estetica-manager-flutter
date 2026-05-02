import 'package:flutter/material.dart';
import 'package:app_estetica/repositories/finance_repository.dart';
import 'package:app_estetica/providers/reports_provider.dart';

class FinanceProvider extends ChangeNotifier {
  final FinanceRepository _repo;
  static const int _recentLimit = 100;

  FinanceProvider({required FinanceRepository repo}) : _repo = repo;

  bool _isLoading = false;
  bool _isSavingExpense = false;
  String? _error;
  ReportDateMode _dateMode = ReportDateMode.singleDay;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedRange;
  DateTime? _selectedMonth;
  int? _selectedYear;
  Map<String, dynamic> _dashboard = {
    'total_ingresos': 0.0,
    'total_egresos': 0.0,
    'ingresos_por_sucursal': <Map<String, dynamic>>[],
    'egresos_por_sucursal': <Map<String, dynamic>>[],
    'movimientos_recientes': <Map<String, dynamic>>[],
  };

  bool get isLoading => _isLoading;
  bool get isSavingExpense => _isSavingExpense;
  String? get error => _error;
  ReportDateMode get dateMode => _dateMode;
  DateTime get selectedDate => _selectedDate;
  DateTimeRange? get selectedRange => _selectedRange;
  DateTime? get selectedMonth => _selectedMonth;
  int? get selectedYear => _selectedYear;
  Map<String, dynamic> get dashboard => _dashboard;

  Future<void> loadDashboard({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    final today = DateTime.now();
    await fetchDashboardForDate(DateTime(today.year, today.month, today.day));
  }

  Future<void> fetchDashboardForDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    _dateMode = ReportDateMode.singleDay;
    _selectedDate = normalized;
    _selectedRange = null;
    _selectedMonth = null;
    _selectedYear = null;

    await _fetchBetween(
      start: normalized,
      end: DateTime(date.year, date.month, date.day, 23, 59, 59),
    );
  }

  Future<void> fetchDashboardForRange(DateTimeRange range) async {
    _dateMode = ReportDateMode.dateRange;
    _selectedRange = range;
    _selectedMonth = null;
    _selectedYear = null;

    await _fetchBetween(
      start: DateTime(range.start.year, range.start.month, range.start.day),
      end: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
    );
  }

  Future<void> fetchDashboardForMonth(int year, int month) async {
    _dateMode = ReportDateMode.monthPick;
    _selectedMonth = DateTime(year, month);
    _selectedRange = null;
    _selectedYear = null;

    await _fetchBetween(
      start: DateTime(year, month, 1),
      end: DateTime(year, month + 1, 0, 23, 59, 59),
    );
  }

  Future<void> fetchDashboardForYear(int year) async {
    _dateMode = ReportDateMode.yearPick;
    _selectedYear = year;
    _selectedRange = null;
    _selectedMonth = null;

    await _fetchBetween(
      start: DateTime(year, 1, 1),
      end: DateTime(year, 12, 31, 23, 59, 59),
    );
  }

  Future<void> refreshCurrent() async {
    switch (_dateMode) {
      case ReportDateMode.singleDay:
      case ReportDateMode.period:
        return fetchDashboardForDate(_selectedDate);
      case ReportDateMode.dateRange:
        if (_selectedRange != null) {
          return fetchDashboardForRange(_selectedRange!);
        }
        return;
      case ReportDateMode.monthPick:
        if (_selectedMonth != null) {
          return fetchDashboardForMonth(
            _selectedMonth!.year,
            _selectedMonth!.month,
          );
        }
        return;
      case ReportDateMode.yearPick:
        if (_selectedYear != null) {
          return fetchDashboardForYear(_selectedYear!);
        }
        return;
    }
  }

  Future<void> _fetchBetween({
    required DateTime start,
    required DateTime end,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dashboard = await _repo.getDashboard(
        start: start.toUtc(),
        end: end.toUtc(),
        recentLimit: _recentLimit,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> searchExpenseCategories(String query) {
    return _repo.searchExpenseCategories(query);
  }

  Future<void> registerExpense({
    required double amount,
    required String description,
    required int sucursalId,
    required String categoryName,
    required DateTime expenseDate,
  }) async {
    if (_isSavingExpense) return;

    _isSavingExpense = true;
    notifyListeners();

    try {
      await _repo.registerExpense(
        amount: amount,
        description: description,
        sucursalId: sucursalId,
        categoryName: categoryName,
        expenseDate: expenseDate,
      );
      await refreshCurrent();
    } finally {
      _isSavingExpense = false;
      notifyListeners();
    }
  }
}
