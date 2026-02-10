import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsRepository {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>> getFinancialReport({
    required int sucursalId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('ReportsRepository.getFinancialReport: sucursalId=$sucursalId, start=$start, end=$end');
      }

      final resp = await _client.rpc('reporte_financiero', params: {
        'p_sucursal_id': sucursalId,
        'p_start': start.toIso8601String(),
        'p_end': end.toIso8601String(),
      });

      if (kDebugMode) {
        debugPrint('ReportsRepository.getFinancialReport: Response type=${resp.runtimeType}, data=$resp');
      }

      if (resp is Map) return Map<String, dynamic>.from(resp);
      return {};
    } catch (e, stack) {
      debugPrint('ReportsRepository.getFinancialReport ERROR: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getClientsReport({
    required int sucursalId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('ReportsRepository.getClientsReport: sucursalId=$sucursalId, start=$start, end=$end');
      }

      final resp = await _client.rpc('reporte_clientes', params: {
        'p_sucursal_id': sucursalId,
        'p_start': start.toIso8601String(),
        'p_end': end.toIso8601String(),
      });

      if (kDebugMode) {
        debugPrint('ReportsRepository.getClientsReport: Response type=${resp.runtimeType}, data=$resp');
      }

      if (resp is Map) return Map<String, dynamic>.from(resp);
      return {};
    } catch (e, stack) {
      debugPrint('ReportsRepository.getClientsReport ERROR: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getServicesReport({
    required int sucursalId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('ReportsRepository.getServicesReport: sucursalId=$sucursalId, start=$start, end=$end');
      }

      final resp = await _client.rpc('reporte_servicios', params: {
        'p_sucursal_id': sucursalId,
        'p_start': start.toIso8601String(),
        'p_end': end.toIso8601String(),
      });

      if (kDebugMode) {
        debugPrint('ReportsRepository.getServicesReport: Response type=${resp.runtimeType}, data=$resp');
      }

      if (resp is Map) return Map<String, dynamic>.from(resp);
      return {};
    } catch (e, stack) {
      debugPrint('ReportsRepository.getServicesReport ERROR: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }
}
