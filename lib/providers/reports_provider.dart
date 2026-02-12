import 'package:flutter/material.dart';
import 'package:app_estetica/screens/admin/reports/report_period.dart';
import 'package:app_estetica/repositories/reports_repository.dart';

class ReportsProvider extends ChangeNotifier {
  final ReportsRepository _repo = ReportsRepository();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Map<String, dynamic> _financialData = {};
  Map<String, dynamic> _clientsData = {};
  Map<String, dynamic> _servicesData = {};

  Map<String, dynamic> get financialData => _financialData;
  Map<String, dynamic> get clientsData => _clientsData;
  Map<String, dynamic> get servicesData => _servicesData;

  // Calcula las fechas basado en el enum
  (DateTime, DateTime) _getDates(ReportPeriod period) {
    final now = DateTime.now();
    // Final del día de hoy
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    DateTime start;
    switch (period) {
      case ReportPeriod.today:
        start = DateTime(now.year, now.month, now.day);
        break;
      case ReportPeriod.week:
        // Lunes de esta semana
        start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
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

  Future<void> loadReports(int sucursalId, ReportPeriod period) async {
    debugPrint('ReportsProvider.loadReports: sucursalId=$sucursalId, period=$period');

    _isLoading = true;
    notifyListeners();

    try {
      final dates = _getDates(period);
      // Enviamos fechas en UTC (Supabase espera timestamps en UTC)
      final start = dates.$1.toUtc();
      final end = dates.$2.toUtc();

      debugPrint('ReportsProvider: Cargando datos desde $start hasta $end');

      final results = await Future.wait([
        _repo.getFinancialReport(sucursalId: sucursalId, start: start, end: end),
        _repo.getClientsReport(sucursalId: sucursalId, start: start, end: end),
        _repo.getServicesReport(sucursalId: sucursalId, start: start, end: end),
      ]);

      // Los repositorios ya devuelven mapas normalizados
      _financialData = results[0] as Map<String, dynamic>? ?? {};
      _clientsData = results[1] as Map<String, dynamic>? ?? {};
      _servicesData = results[2] as Map<String, dynamic>? ?? {};

      debugPrint('ReportsProvider: Datos cargados exitosamente');
      debugPrint('  - financialData keys: ${_financialData.keys}');
      debugPrint('  - clientsData keys: ${_clientsData.keys}');
      debugPrint('  - servicesData keys: ${_servicesData.keys}');
    } catch (e, stack) {
      debugPrint("ReportsProvider ERROR cargando reportes: $e");
      debugPrint("Stack: $stack");
      _financialData = {};
      _clientsData = {};
      _servicesData = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
