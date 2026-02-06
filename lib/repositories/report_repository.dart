import 'package:supabase_flutter/supabase_flutter.dart';

class ReportRepository {
  final SupabaseClient _client;

  ReportRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  Future<Map<String, dynamic>> getDailyReport({String? start, String? end, int? sucursalId}) async {
    try {
      var qb = _client.from('reportes_ventas').select('*');
      if (start != null) qb = qb.eq('start', start);
      if (end != null) qb = qb.eq('end', end);
      if (sucursalId != null) qb = qb.eq('sucursal', sucursalId);
      final dynamic resp = await qb;
      if (resp is List && resp.isNotEmpty) return Map<String, dynamic>.from(resp.first as Map);
      if (resp is Map<String, dynamic>) return resp;
      return <String, dynamic>{};
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getDebtReport({int? sucursalId}) async {
    try {
      var qb = _client.from('reportes_deuda').select('*');
      if (sucursalId != null) qb = qb.eq('sucursal', sucursalId);
      final resp = await qb;
      return resp as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getClientReport(int clientId) async {
    try {
      final resp = await _client.from('reportes_cliente').select('*').eq('id', clientId);
      return resp.isNotEmpty ? Map<String, dynamic>.from(resp.first) : {};
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPagosPaginated({String? start, String? end, int? sucursalId, int page = 1, int pageSize = 30}) async {
    try {
      var qb = _client.from('pagos').select('*');
      if (start != null) qb = qb.eq('start', start);
      if (end != null) qb = qb.eq('end', end);
      if (sucursalId != null) qb = qb.eq('sucursal', sucursalId);

      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      final resp = await qb.range(from, to);
      final items = resp as List<dynamic>;
      return {
        'items': items,
        'meta': {
          'pagination': {'page': page, 'pageCount': 1, 'total': items.length}
        }
      };
    } catch (e) {
      rethrow;
    }
  }
}
