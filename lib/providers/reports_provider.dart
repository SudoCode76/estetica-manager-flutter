import 'package:flutter/material.dart';
import 'package:app_estetica/screens/admin/reports/report_period.dart';
import 'package:app_estetica/repositories/reports_repository.dart';

/// Modo de navegación de fecha del reporte financiero.
enum ReportDateMode {
  /// Usa el período clásico (hoy / semana / mes / año).
  period,

  /// Muestra un único día histórico.
  singleDay,

  /// Muestra un rango de fechas personalizado.
  dateRange,

  /// Mes completo seleccionado explícitamente.
  monthPick,

  /// Año completo seleccionado explícitamente.
  yearPick,
}

/// Granularidad del eje X del gráfico de barras.
enum ChartGranularity {
  /// Agrupado por hora — día único.
  hourly,

  /// Agrupado por día — rango ≤ 7 días o período semana/mes.
  daily,

  /// Agrupado por día del mes — mes completo.
  monthly,

  /// Agrupado por mes — año completo.
  yearly,

  /// No mostrar gráfico — rango > 7 días arbitrario.
  none,
}

class ReportsProvider extends ChangeNotifier {
  final ReportsRepository _repo = ReportsRepository();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Map<String, dynamic> _financialData = {};
  Map<String, dynamic> _clientsData = {};

  Map<String, dynamic> get financialData => _financialData;
  Map<String, dynamic> get clientsData => _clientsData;

  // ── Estado de navegación ───────────────────────────────────────────────────
  ReportDateMode _dateMode = ReportDateMode.period;
  ReportDateMode get dateMode => _dateMode;

  /// Período clásico activo (null cuando se usa DateNavBar).
  ReportPeriod? _activePeriod = ReportPeriod.month;
  ReportPeriod? get activePeriod => _activePeriod;

  /// Fecha seleccionada en modo singleDay.
  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  /// Rango seleccionado en modo dateRange.
  DateTimeRange? _selectedRange;
  DateTimeRange? get selectedRange => _selectedRange;

  /// Mes seleccionado en modo monthPick (día siempre = 1).
  DateTime? _selectedMonth;
  DateTime? get selectedMonth => _selectedMonth;

  /// Año seleccionado en modo yearPick.
  int? _selectedYear;
  int? get selectedYear => _selectedYear;

  // ── Granularidad calculada ─────────────────────────────────────────────────

  ChartGranularity get chartGranularity {
    switch (_dateMode) {
      case ReportDateMode.yearPick:
        return ChartGranularity.yearly;

      case ReportDateMode.monthPick:
        return ChartGranularity.monthly;

      case ReportDateMode.singleDay:
        return ChartGranularity.hourly;

      case ReportDateMode.dateRange:
        final r = _selectedRange;
        if (r == null) return ChartGranularity.none;
        final days = r.end.difference(r.start).inDays + 1;
        if (days <= 1) return ChartGranularity.hourly;
        if (days <= 7) return ChartGranularity.daily;
        return ChartGranularity.none;

      case ReportDateMode.period:
        switch (_activePeriod) {
          case ReportPeriod.today:
            return ChartGranularity.hourly;
          case ReportPeriod.week:
            return ChartGranularity.daily;
          case ReportPeriod.month:
            return ChartGranularity.daily;
          case ReportPeriod.year:
            return ChartGranularity.yearly;
          case null:
            return ChartGranularity.none;
        }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  (DateTime, DateTime) _getDates(ReportPeriod period) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    DateTime start;
    switch (period) {
      case ReportPeriod.today:
        start = DateTime(now.year, now.month, now.day);
        break;
      case ReportPeriod.week:
        start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        break;
      case ReportPeriod.month:
        start = DateTime(now.year, now.month, 1);
        break;
      case ReportPeriod.year:
        start = DateTime(now.year, 1, 1);
        break;
    }
    return (start, end);
  }

  void _resetSelections() {
    _selectedRange = null;
    _selectedMonth = null;
    _selectedYear = null;
  }

  Future<void> _fetchBoth({
    required int sucursalId,
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    final results = await Future.wait([
      _repo.getFinancialReport(
        sucursalId: sucursalId,
        start: startUtc,
        end: endUtc,
      ),
      _repo.getClientsReport(
        sucursalId: sucursalId,
        start: startUtc,
        end: endUtc,
      ),
    ]);
    _financialData = results[0] as Map<String, dynamic>? ?? {};
    _clientsData = results[1] as Map<String, dynamic>? ?? {};
  }

  // ── Métodos públicos ───────────────────────────────────────────────────────

  /// Período clásico (Hoy / Semana / Mes / Año).
  Future<void> loadReports(int sucursalId, ReportPeriod period) async {
    _dateMode = ReportDateMode.period;
    _activePeriod = period;
    _resetSelections();

    debugPrint(
      'ReportsProvider.loadReports: sucursalId=$sucursalId, period=$period',
    );

    _isLoading = true;
    notifyListeners();

    try {
      final dates = _getDates(period);
      await _fetchBoth(
        sucursalId: sucursalId,
        startUtc: dates.$1.toUtc(),
        endUtc: dates.$2.toUtc(),
      );
      debugPrint('ReportsProvider: loadReports OK');
    } catch (e, stack) {
      debugPrint('ReportsProvider ERROR loadReports: $e\n$stack');
      _financialData = {};
      _clientsData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Día único histórico.
  Future<void> fetchReportForDate(int sucursalId, DateTime date) async {
    _dateMode = ReportDateMode.singleDay;
    _activePeriod = null;
    _selectedDate = date;
    _resetSelections();

    debugPrint(
      'ReportsProvider.fetchReportForDate: sucursalId=$sucursalId, date=$date',
    );

    _isLoading = true;
    notifyListeners();

    try {
      await _fetchBoth(
        sucursalId: sucursalId,
        startUtc: DateTime(date.year, date.month, date.day).toUtc(),
        endUtc: DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc(),
      );
      debugPrint('ReportsProvider: fetchReportForDate OK');
    } catch (e, stack) {
      debugPrint('ReportsProvider ERROR fetchReportForDate: $e\n$stack');
      _financialData = {};
      _clientsData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Rango de fechas personalizado.
  Future<void> fetchReportForRange(int sucursalId, DateTimeRange range) async {
    _dateMode = ReportDateMode.dateRange;
    _activePeriod = null;
    _selectedRange = range;
    _selectedMonth = null;
    _selectedYear = null;

    debugPrint(
      'ReportsProvider.fetchReportForRange: sucursalId=$sucursalId, '
      'start=${range.start}, end=${range.end}',
    );

    _isLoading = true;
    notifyListeners();

    try {
      await _fetchBoth(
        sucursalId: sucursalId,
        startUtc: DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        ).toUtc(),
        endUtc: DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        ).toUtc(),
      );
      debugPrint('ReportsProvider: fetchReportForRange OK');
    } catch (e, stack) {
      debugPrint('ReportsProvider ERROR fetchReportForRange: $e\n$stack');
      _financialData = {};
      _clientsData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mes completo ([year], [month]).
  Future<void> fetchReportForMonth(int sucursalId, int year, int month) async {
    _dateMode = ReportDateMode.monthPick;
    _activePeriod = null;
    _selectedMonth = DateTime(year, month);
    _selectedRange = null;
    _selectedYear = null;

    debugPrint(
      'ReportsProvider.fetchReportForMonth: sucursalId=$sucursalId, '
      'year=$year, month=$month',
    );

    _isLoading = true;
    notifyListeners();

    try {
      // Último día del mes = día 0 del mes siguiente
      await _fetchBoth(
        sucursalId: sucursalId,
        startUtc: DateTime(year, month, 1).toUtc(),
        endUtc: DateTime(year, month + 1, 0, 23, 59, 59).toUtc(),
      );
      debugPrint('ReportsProvider: fetchReportForMonth OK');
    } catch (e, stack) {
      debugPrint('ReportsProvider ERROR fetchReportForMonth: $e\n$stack');
      _financialData = {};
      _clientsData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Año completo [year].
  Future<void> fetchReportForYear(int sucursalId, int year) async {
    _dateMode = ReportDateMode.yearPick;
    _activePeriod = null;
    _selectedYear = year;
    _selectedRange = null;
    _selectedMonth = null;

    debugPrint(
      'ReportsProvider.fetchReportForYear: sucursalId=$sucursalId, year=$year',
    );

    _isLoading = true;
    notifyListeners();

    try {
      await _fetchBoth(
        sucursalId: sucursalId,
        startUtc: DateTime(year, 1, 1).toUtc(),
        endUtc: DateTime(year, 12, 31, 23, 59, 59).toUtc(),
      );
      debugPrint('ReportsProvider: fetchReportForYear OK');
    } catch (e, stack) {
      debugPrint('ReportsProvider ERROR fetchReportForYear: $e\n$stack');
      _financialData = {};
      _clientsData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
