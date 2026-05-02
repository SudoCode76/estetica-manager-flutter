import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinanceRepository {
  final SupabaseClient _client;

  FinanceRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<Map<String, dynamic>> getDashboard({
    required DateTime start,
    required DateTime end,
    int recentLimit = 12,
  }) async {
    try {
      final resp = await _client.rpc(
        'admin_finanzas_dashboard',
        params: {
          'p_start': start.toIso8601String(),
          'p_end': end.toIso8601String(),
          'p_limit': recentLimit,
        },
      );

      if (resp is! Map) {
        return _emptyDashboard();
      }

      final data = Map<String, dynamic>.from(resp);
      final ingresosPorSucursal = _normalizeBranchTotals(
        data['ingresos_por_sucursal'],
      );
      final egresosPorSucursal = _normalizeBranchTotals(
        data['egresos_por_sucursal'],
      );
      final movimientosRecientes = _normalizeRecentMovements(
        data['movimientos_recientes'],
      );

      final totalIngresos = _toDouble(data['total_ingresos']);
      final totalEgresos = _toDouble(data['total_egresos']);

      return {
        'total_ingresos': totalIngresos,
        'total_egresos': totalEgresos,
        'ingresos_por_sucursal': ingresosPorSucursal,
        'egresos_por_sucursal': egresosPorSucursal,
        'movimientos_recientes': movimientosRecientes,
      };
    } catch (e, stack) {
      debugPrint('FinanceRepository.getDashboard ERROR: $e');
      debugPrint('$stack');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchExpenseCategories(
    String query, {
    int limit = 8,
  }) async {
    try {
      final resp = await _client.rpc(
        'buscar_categorias_egreso',
        params: {'p_query': query, 'p_limit': limit},
      );

      if (resp is! List) {
        return <Map<String, dynamic>>[];
      }

      return resp.map<Map<String, dynamic>>((item) {
        final map = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map);
        return {'id': map['id'], 'nombre': map['nombre']?.toString() ?? ''};
      }).toList();
    } catch (e, stack) {
      debugPrint('FinanceRepository.searchExpenseCategories ERROR: $e');
      debugPrint('$stack');
      rethrow;
    }
  }

  Future<void> registerExpense({
    required double amount,
    required String description,
    required int sucursalId,
    required String categoryName,
    required DateTime expenseDate,
  }) async {
    try {
      final resp = await _client.rpc(
        'registrar_egreso',
        params: {
          'p_monto': amount,
          'p_descripcion': description,
          'p_sucursal_id': sucursalId,
          'p_categoria_nombre': categoryName,
          'p_fecha_egreso': expenseDate.toIso8601String(),
        },
      );

      if (resp is Map) {
        final data = Map<String, dynamic>.from(resp);
        final success = data['success'] == true;
        if (!success) {
          throw Exception(
            data['error']?.toString() ?? 'No se pudo registrar el egreso',
          );
        }
        return;
      }

      throw Exception('Respuesta inválida al registrar egreso');
    } catch (e, stack) {
      debugPrint('FinanceRepository.registerExpense ERROR: $e');
      debugPrint('$stack');
      rethrow;
    }
  }

  Map<String, dynamic> _emptyDashboard() {
    return {
      'total_ingresos': 0.0,
      'total_egresos': 0.0,
      'ingresos_por_sucursal': <Map<String, dynamic>>[],
      'egresos_por_sucursal': <Map<String, dynamic>>[],
      'movimientos_recientes': <Map<String, dynamic>>[],
    };
  }

  List<Map<String, dynamic>> _normalizeBranchTotals(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];

    return raw.map<Map<String, dynamic>>((item) {
      final map = item is Map<String, dynamic>
          ? item
          : Map<String, dynamic>.from(item as Map);

      return {
        'sucursal_id': map['sucursal_id'],
        'sucursal_nombre': map['sucursal_nombre']?.toString() ?? 'Sin sucursal',
        'total': _toDouble(map['total']),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _normalizeRecentMovements(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];

    return raw.map<Map<String, dynamic>>((item) {
      final map = item is Map<String, dynamic>
          ? item
          : Map<String, dynamic>.from(item as Map);

      return {
        'tipo': map['tipo']?.toString() ?? '',
        'fecha': map['fecha']?.toString(),
        'monto': _toDouble(map['monto']),
        'sucursal_id': map['sucursal_id'],
        'sucursal_nombre': map['sucursal_nombre']?.toString() ?? 'Sin sucursal',
        'descripcion': map['descripcion']?.toString() ?? '',
        'metodo_pago': map['metodo_pago']?.toString(),
        'referencia_id': map['referencia_id']?.toString(),
      };
    }).toList();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }
}
