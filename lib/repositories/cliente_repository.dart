import 'package:supabase_flutter/supabase_flutter.dart';

class ClienteRepository {
  // Implementación directa usando Supabase SDK en lugar de ApiService

  Future<List<dynamic>> searchClientes({String? query, int? sucursalId}) async {
    try {
      var qb = Supabase.instance.client.from('cliente').select('*');
      if (sucursalId != null) qb = qb.eq('sucursal_id', sucursalId);
      if (query != null && query.trim().isNotEmpty) {
        final pattern = '%${query.trim()}%';
        qb = qb.or('nombrecliente.ilike.$pattern,apellidocliente.ilike.$pattern,telefono.ilike.$pattern');
      }

      final data = await qb;
      return (data as List<dynamic>).map((e) {
        if (e is Map<String, dynamic>) return {
          'id': e['id'],
          'nombreCliente': e['nombrecliente'] ?? e['nombreCliente'] ?? '',
          'apellidoCliente': e['apellidocliente'] ?? e['apellidoCliente'] ?? '',
          'telefono': e['telefono'],
          'estadoCliente': e['estadocliente'] ?? e['estadoCliente'] ?? true,
          'sucursal_id': e['sucursal_id'] ?? e['sucursal'] ?? null,
          'created_at': e['created_at'],
        };
        return e;
      }).toList();
    } catch (e) {
      // fallback vacío en caso de error
      return [];
    }
  }

  Future<Map<String, dynamic>?> getClienteById(String id) async {
    try {
      final dynamic idValue = int.tryParse(id) ?? id;
      final resp = await Supabase.instance.client.from('cliente').select('*').eq('id', idValue).single();
      return Map<String, dynamic>.from(resp);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> crearCliente(Map<String, dynamic> cliente) async {
    try {
      final payload = <String, dynamic>{};
      payload['nombrecliente'] = cliente['nombreCliente'] ?? cliente['nombrecliente'] ?? '';
      payload['apellidocliente'] = cliente['apellidoCliente'] ?? cliente['apellidocliente'] ?? '';
      payload['telefono'] = cliente['telefono']?.toString() ?? '';
      payload['estadocliente'] = cliente['estadoCliente'] ?? cliente['estadocliente'] ?? true;
      payload['sucursal_id'] = cliente['sucursal_id'] ?? cliente['sucursal'] ?? cliente['sucursalId'];

      final res = await Supabase.instance.client.from('cliente').insert(payload).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteCliente(dynamic documentId) async {
    try {
      final idStr = documentId.toString();
      final idInt = int.tryParse(idStr);
      if (idInt == null) throw Exception('ID de cliente inválido: $documentId');
      await Supabase.instance.client.from('cliente').delete().eq('id', idInt);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCliente(String documentId, Map<String, dynamic> cliente) async {
    try {
      final idStr = documentId.toString();
      final idInt = int.tryParse(idStr);
      if (idInt == null) throw Exception('ID de cliente inválido: $documentId');

      final payload = <String, dynamic>{};
      if (cliente.containsKey('nombreCliente') || cliente.containsKey('nombrecliente')) payload['nombrecliente'] = cliente['nombreCliente'] ?? cliente['nombrecliente'];
      if (cliente.containsKey('apellidoCliente') || cliente.containsKey('apellidocliente')) payload['apellidocliente'] = cliente['apellidoCliente'] ?? cliente['apellidocliente'];
      if (cliente.containsKey('telefono')) payload['telefono'] = cliente['telefono']?.toString();
      if (cliente.containsKey('estadoCliente') || cliente.containsKey('estadocliente')) payload['estadocliente'] = cliente['estadoCliente'] ?? cliente['estadocliente'];
      if (cliente.containsKey('sucursal_id') || cliente.containsKey('sucursal')) payload['sucursal_id'] = cliente['sucursal_id'] ?? cliente['sucursal'];

      if (payload.isEmpty) throw Exception('No hay campos para actualizar');

      final res = await Supabase.instance.client.from('cliente').update(payload).eq('id', idInt).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      rethrow;
    }
  }

  // NUEVO MÉTODO: obtenerHistorialClientes
  Future<List<dynamic>> obtenerHistorialClientes({int? sucursalId}) async {
    try {
      var query = Supabase.instance.client
          .from('vista_historial_clientes')
          .select()
          .gt('total_pagado', 0);

      if (sucursalId != null) {
        query = query.eq('sucursal_id', sucursalId);
      }

      final response = await query.order('total_pagado', ascending: false);
      return response as List<dynamic>;
    } catch (e) {
      // En caso de error devolvemos lista vacía
      return [];
    }
  }
}
