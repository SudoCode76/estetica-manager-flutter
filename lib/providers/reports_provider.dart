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
}

class ReportsProvider extends ChangeNotifier {
  final ReportsRepository _repo = ReportsRepository();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Map<String, dynamic> _financialData = {};
  Map<String, dynamic> _clientsData = {};

  Map<String, dynamic> get financialData => _financialData;
  Map<String, dynamic> get clientsData => _clientsData;

  // ── Estado de navegación de fecha ──────────────────────────────────────────
  ReportDateMode _dateMode = ReportDateMode.period;
  ReportDateMode get dateMode => _dateMode;

  /// Fecha seleccionada en modo [ReportDateMode.singleDay].
  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  /// Rango seleccionado en modo [ReportDateMode.dateRange].
  DateTimeRange? _selectedRange;
  DateTimeRange? get selectedRange => _selectedRange;

  // ── Helpers de bounds ──────────────────────────────────────────────────────

  /// Devuelve [start, end] en hora local para el período clásico.
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

  // ── Métodos públicos de carga ──────────────────────────────────────────────

  /// Carga usando el período clásico (hoy/semana/mes/año).
  Future<void> loadReports(int sucursalId, ReportPeriod period) async {
    _dateMode = ReportDateMode.period;
    debugPrint(
      'ReportsProvider.loadReports: sucursalId=$sucursalId, period=$period',
    );

    _isLoading = true;
    notifyListeners();

    try {
      final dates = _getDates(period);
      final start = dates.$1.toUtc();
      final end = dates.$2.toUtc();

      debugPrint('ReportsProvider: Cargando datos desde $start hasta $end');

      final results = await Future.wait([
        _repo.getFinancialReport(
          sucursalId: sucursalId,
          start: start,
          end: end,
        ),
        _repo.getClientsReport(sucursalId: sucursalId, start: start, end: end),
      ]);

      _financialData = results[0] as Map<String, dynamic>? ?? {};
      _clientsData = results[1] as Map<String, dynamic>? ?? {};

      debugPrint('ReportsProvider: Datos cargados exitosamente');
    } catch (e, stack) {
      debugPrint('ReportsProvider ERROR cargando reportes: $e');
      debugPrint('Stack: $stack');
      _financialData = {};
      _clientsData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga el reporte para un único día histórico [date] (hora local).
  Future<void> fetchReportForDate(int sucursalId, DateTime date) async {
    _dateMode = ReportDateMode.singleDay;
    _selectedDate = date;
    _selectedRange = null;

    debugPrint(
      'ReportsProvider.fetchReportForDate: sucursalId=$sucursalId, date=$date',
    );

    _isLoading = true;
    notifyListeners();

    try {
      final start = DateTime(date.year, date.month, date.day).toUtc();
      final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc();

      debugPrint('ReportsProvider: Día único $start → $end');

      final results = await Future.wait([
        _repo.getFinancialReport(
          sucursalId: sucursalId,
          start: start,
          end: end,
        ),
        _repo.getClientsReport(sucursalId: sucursalId, start: start, end: end),
      ]);

      _financialData = results[0] as Map<String, dynamic>? ?? {};
      _clientsData = results[1] as Map<String, dynamic>? ?? {};

      debugPrint('ReportsProvider: Día único cargado');
    } catch (e, stack) {
      debugPrint('ReportsProvider ERROR fetchReportForDate: $e');
      debugPrint('Stack: $stack');
      _financialData = {};
      _clientsData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga el reporte para un rango de fechas [range] (hora local).
  Future<void> fetchReportForRange(int sucursalId, DateTimeRange range) async {
    _dateMode = ReportDateMode.dateRange;
    _selectedRange = range;

    debugPrint(
      'ReportsProvider.fetchReportForRange: sucursalId=$sucursalId, '
      'start=${range.start}, end=${range.end}',
    );

    _isLoading = true;
    notifyListeners();

    try {
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      ).toUtc();
      final end = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      ).toUtc();

      debugPrint('ReportsProvider: Rango $start → $end');

      final results = await Future.wait([
        _repo.getFinancialReport(
          sucursalId: sucursalId,
          start: start,
          end: end,
        ),
        _repo.getClientsReport(sucursalId: sucursalId, start: start, end: end),
      ]);

      _financialData = results[0] as Map<String, dynamic>? ?? {};
      _clientsData = results[1] as Map<String, dynamic>? ?? {};

      debugPrint('ReportsProvider: Rango cargado');
    } catch (e, stack) {
      debugPrint('ReportsProvider ERROR fetchReportForRange: $e');
      debugPrint('Stack: $stack');
      _financialData = {};
      _clientsData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
