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
        debugPrint(
          'ReportsRepository.getFinancialReport: sucursalId=$sucursalId, start=$start, end=$end',
        );
      }

      final resp = await _client.rpc(
        'reporte_financiero',
        params: {
          'p_sucursal_id': sucursalId,
          'p_start': start.toIso8601String(),
          'p_end': end.toIso8601String(),
        },
      );

      if (kDebugMode) {
        debugPrint(
          'ReportsRepository.getFinancialReport: Response type=${resp.runtimeType}, data=$resp',
        );
      }

      if (resp is Map) {
        // Normalizar campos esperados según la función SQL que proporcionaste
        final Map<String, dynamic> m = Map<String, dynamic>.from(resp);

        // ingresos -> double
        final ingresos = (m['ingresos'] is num)
            ? (m['ingresos'] as num).toDouble()
            : 0.0;

        // chart_data -> List<{label: String, value: double}>
        final rawChart = (m['chart_data'] is List)
            ? List.from(m['chart_data'] as List)
            : <dynamic>[];
        final chartData = rawChart.map<Map<String, dynamic>>((e) {
          final map = (e is Map) ? Map<String, dynamic>.from(e) : {};
          return {
            'label': map['label']?.toString() ?? '',
            'value': (map['value'] is num)
                ? (map['value'] as num).toDouble()
                : 0.0,
          };
        }).toList();

        // top_tratamientos -> List<{name, count, total_dinero}>
        final rawTop = (m['top_tratamientos'] is List)
            ? List.from(m['top_tratamientos'] as List)
            : <dynamic>[];
        final topTratamientos = rawTop.map<Map<String, dynamic>>((e) {
          final map = (e is Map) ? Map<String, dynamic>.from(e) : {};
          return {
            'name': map['name']?.toString() ?? '',
            'count': (map['count'] is num) ? (map['count'] as num).toInt() : 0,
            'total_dinero': (map['total_dinero'] is num)
                ? (map['total_dinero'] as num).toDouble()
                : 0.0,
          };
        }).toList();

        // pendientes_cobro -> List<{name, amount, date}>
        final rawPend = (m['pendientes_cobro'] is List)
            ? List.from(m['pendientes_cobro'] as List)
            : <dynamic>[];
        final pendientes = rawPend.map<Map<String, dynamic>>((e) {
          final map = (e is Map) ? Map<String, dynamic>.from(e) : {};
          return {
            'name': map['name']?.toString() ?? '',
            'amount': (map['amount'] is num)
                ? (map['amount'] as num).toDouble()
                : 0.0,
            'date': map['date']?.toString(),
          };
        }).toList();

        // También parsear totales por método si vienen desde la función SQL
        final totalQr = (m['total_qr'] is num)
            ? (m['total_qr'] as num).toDouble()
            : 0.0;
        final totalEfectivo = (m['total_efectivo'] is num)
            ? (m['total_efectivo'] as num).toDouble()
            : 0.0;

        return {
          'ingresos': ingresos,
          'chart_data': chartData,
          'top_tratamientos': topTratamientos,
          'pendientes_cobro': pendientes,
          'total_qr': totalQr,
          'total_efectivo': totalEfectivo,
        };
      }

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
        debugPrint(
          'ReportsRepository.getClientsReport: sucursalId=$sucursalId, start=$start, end=$end',
        );
      }

      final resp = await _client.rpc(
        'reporte_clientes',
        params: {
          'p_sucursal_id': sucursalId,
          'p_start': start.toIso8601String(),
          'p_end': end.toIso8601String(),
        },
      );

      if (kDebugMode) {
        debugPrint(
          'ReportsRepository.getClientsReport: Response type=${resp.runtimeType}, data=$resp',
        );
      }

      if (resp is Map) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(resp);
        final int atendidos = (m['atendidos'] is num)
            ? (m['atendidos'] as num).toInt()
            : 0;
        final int nuevos = (m['nuevos'] is num)
            ? (m['nuevos'] as num).toInt()
            : 0;

        final rawChart = (m['chart_data'] is List)
            ? List.from(m['chart_data'] as List)
            : <dynamic>[];
        final chartData = rawChart.map<Map<String, dynamic>>((e) {
          final map = (e is Map) ? Map<String, dynamic>.from(e) : {};
          return {
            'label': map['label']?.toString() ?? '',
            'value': (map['value'] is num)
                ? (map['value'] as num).toDouble()
                : 0.0,
          };
        }).toList();

        final rawTop = (m['top_clientes'] is List)
            ? List.from(m['top_clientes'] as List)
            : <dynamic>[];
        final topClients = rawTop.map<Map<String, dynamic>>((e) {
          final map = (e is Map) ? Map<String, dynamic>.from(e) : {};
          return {
            'name': map['name']?.toString() ?? '',
            'amount': (map['amount'] is num)
                ? (map['amount'] as num).toDouble()
                : 0.0,
          };
        }).toList();

        return {
          'atendidos': atendidos,
          'nuevos': nuevos,
          'chart_data': chartData,
          'top_clientes': topClients,
        };
      }

      return {};
    } catch (e, stack) {
      debugPrint('ReportsRepository.getClientsReport ERROR: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  // getServicesReport removed because the backend function was dropped.
}
