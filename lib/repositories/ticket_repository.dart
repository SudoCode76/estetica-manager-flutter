import 'package:flutter/foundation.dart';
import 'package:app_estetica/services/api_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositorio responsable de todas las operaciones relacionadas con Tickets y Sesiones.
class TicketRepository {
  final ApiClient _client = ApiClient();

  // Helper para rango de día
  (String, String) _getRangoDia(DateTime fecha) {
    final start = DateTime(fecha.year, fecha.month, fecha.day).toIso8601String();
    final end = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59).toIso8601String();
    return (start, end);
  }

  Future<List<dynamic>> obtenerAgenda(DateTime fecha, {int? sucursalId, String? estadoSesion}) async {
    try {
      if (sucursalId == null) return [];
      final (inicioDia, finDia) = _getRangoDia(fecha);

      var query = Supabase.instance.client
          .from('vista_agenda_diaria')
          .select()
          .eq('sucursal_id', sucursalId)
          .gte('fecha_hora_inicio', inicioDia)
          .lte('fecha_hora_inicio', finDia);

      if (estadoSesion != null) {
        query = query.eq('estado_sesion', estadoSesion);
      }

      final response = await query.order('fecha_hora_inicio', ascending: true);
      return _client.normalizarDatosVista(response as List<dynamic>);
    } catch (e) {
      debugPrint('TicketRepository.obtenerAgenda error: ${e.toString()}');
      rethrow;
    }
  }

  Future<List<dynamic>> obtenerAgendaPorRango({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required int sucursalId,
    String? estadoSesion,
  }) async {
    try {
      final start = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day, 0, 0, 0).toIso8601String();
      final end = DateTime(fechaFin.year, fechaFin.month, fechaFin.day, 23, 59, 59, 999).toIso8601String();

      var query = Supabase.instance.client
          .from('vista_agenda_diaria')
          .select()
          .eq('sucursal_id', sucursalId)
          .gte('fecha_hora_inicio', start)
          .lte('fecha_hora_inicio', end);

      if (estadoSesion != null) query = query.eq('estado_sesion', estadoSesion);

      final response = await query.order('fecha_hora_inicio', ascending: true);
      return _client.normalizarDatosVista(response as List<dynamic>);
    } catch (e) {
      debugPrint('TicketRepository.obtenerAgendaPorRango error: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> searchSessions({
    required String query,
    required int sucursalId,
    int page = 1,
    int pageSize = 20,
    String? estadoSesion,
  }) async {
    try {
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) return {'items': [], 'meta': {'total': 0}};
      final pattern = '%$cleanQuery%';

      final clientesResp = await Supabase.instance.client
          .from('cliente')
          .select('id')
          .or('nombrecliente.ilike.$pattern,apellidocliente.ilike.$pattern');

      final List<int> clienteIds = (clientesResp as List).map((e) => e['id'] as int).toList();
      if (clienteIds.isEmpty) return {'items': [], 'meta': {'total': 0}};

      var queryBuilder = Supabase.instance.client
          .from('vista_agenda_diaria')
          .select()
          .eq('sucursal_id', sucursalId)
          .filter('cliente_id', 'in', '(${clienteIds.join(',')})');

      if (estadoSesion != null && estadoSesion.isNotEmpty) queryBuilder = queryBuilder.eq('estado_sesion', estadoSesion);

      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;

      final response = await queryBuilder.order('fecha_hora_inicio', ascending: true).range(from, to).count(CountOption.exact);
      final adaptedData = _client.normalizarDatosVista(response.data as List<dynamic>);

      return {
        'items': adaptedData,
        'meta': {
          'page': page,
          'pageSize': pageSize,
          'returned': adaptedData.length,
          'total': response.count,
          'totalPages': (response.count / pageSize).ceil(),
        }
      };
    } catch (e) {
      debugPrint('TicketRepository.searchSessions error: ${e.toString()}');
      rethrow;
    }
  }

  Future<List<dynamic>> getTicketsDelDia({required DateTime fecha, required int sucursalId}) async {
    try {
      final (inicioDia, finDia) = _getRangoDia(fecha);

      final response = await Supabase.instance.client
          .from('ticket')
          .select('''
            *, 
            cliente:cliente_id(nombrecliente, apellidocliente, telefono),
            sesiones:sesion(
              id,
              numero_sesion,
              fecha_hora_inicio,
              estado_sesion,
              tratamiento:tratamiento_id(id, nombretratamiento, precio)
            )
          ''')
          .eq('sucursal_id', sucursalId)
          .gte('created_at', inicioDia)
          .lte('created_at', finDia)
          .order('created_at', ascending: false);

      return response as List<dynamic>;
    } catch (e) {
      debugPrint('TicketRepository.getTicketsDelDia error: ${e.toString()}');
      rethrow;
    }
  }

  Future<List<dynamic>> getAllTickets({required int sucursalId}) async {
    try {
      final response = await Supabase.instance.client
          .from('ticket')
          .select('''
            *, 
            cliente:cliente_id(nombrecliente, apellidocliente, telefono),
            sesiones:sesion(
              id,
              numero_sesion,
              fecha_hora_inicio,
              estado_sesion,
              tratamiento:tratamiento_id(id, nombretratamiento, precio)
            )
          ''')
          .eq('sucursal_id', sucursalId)
          .order('created_at', ascending: false);

      return response as List<dynamic>;
    } catch (e) {
      debugPrint('TicketRepository.getAllTickets error: ${e.toString()}');
      rethrow;
    }
  }

  Future<List<dynamic>> getTicketsByRange({required DateTime start, required DateTime end, required int sucursalId}) async {
    try {
      final startLocal = DateTime(start.year, start.month, start.day, 0, 0, 0);
      final endLocal = DateTime(end.year, end.month, end.day, 23, 59, 59);
      final startIso = startLocal.toUtc().toIso8601String();
      final endIso = endLocal.toUtc().toIso8601String();

      final response = await Supabase.instance.client
          .from('ticket')
          .select('''
            *, 
            cliente:cliente_id(nombrecliente, apellidocliente, telefono),
            sesiones:sesion(
              id,
              numero_sesion,
              fecha_hora_inicio,
              estado_sesion,
              tratamiento:tratamiento_id(id, nombretratamiento, precio)
            )
          ''')
          .eq('sucursal_id', sucursalId)
          .gte('created_at', startIso)
          .lte('created_at', endIso)
          .order('created_at', ascending: false);

      return response as List<dynamic>;
    } catch (e) {
      debugPrint('TicketRepository.getTicketsByRange error: ${e.toString()}');
      rethrow;
    }
  }

  Future<List<dynamic>> obtenerTicketsPendientes({int? sucursalId}) async {
    try {
      var query = Supabase.instance.client
          .from('ticket')
          .select('*, cliente:cliente_id(*)')
          .or('estado_pago.eq.pendiente,estado_pago.eq.parcial');

      if (sucursalId != null) query = query.eq('sucursal_id', sucursalId);

      final response = await query.order('created_at', ascending: true);
      return response as List<dynamic>;
    } catch (e) {
      debugPrint('TicketRepository.obtenerTicketsPendientes error: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> obtenerTicketDetalle(String ticketId) async {
    try {
      final response = await Supabase.instance.client
          .from('ticket')
          .select('''
            *,
            cliente:cliente_id(*),
            sesiones:sesion(*, tratamiento:tratamiento_id(*)),
            pagos:pago(*)
          ''')
          .eq('id', ticketId)
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('TicketRepository.obtenerTicketDetalle error: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> registrarAbono({required String ticketId, required double montoAbono, String metodoPago = 'efectivo'}) async {
    try {
      // Ensure jwt if necessary via ApiClient is not implemented; Supabase client handles auth
      final response = await Supabase.instance.client.from('pago').insert({
        'ticket_id': ticketId,
        'monto': montoAbono,
        'fecha_pago': DateTime.now().toIso8601String(),
        'metodo_pago': metodoPago,
      }).select().single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('TicketRepository.registrarAbono error: ${e.toString()}');
      rethrow;
    }
  }

  Future<bool> marcarSesionAtendida(String sesionId) async {
    try {
      await Supabase.instance.client.from('sesion').update({'estado_sesion': 'realizada'}).eq('id', sesionId);
      return true;
    } catch (e) {
      debugPrint('TicketRepository.marcarSesionAtendida error: ${e.toString()}');
      rethrow;
    }
  }

  Future<bool> reprogramarSesion(String sesionId, DateTime nuevaFecha) async {
    try {
      await Supabase.instance.client.from('sesion').update({'fecha_hora_inicio': nuevaFecha.toIso8601String()}).eq('id', sesionId);
      return true;
    } catch (e) {
      debugPrint('TicketRepository.reprogramarSesion error: ${e.toString()}');
      rethrow;
    }
  }

  /// Actualizar campo de estado del ticket (compatibilidad con UI)
  Future<bool> actualizarEstadoTicket(dynamic documentId, bool atendido) async {
    try {
      final id = documentId.toString();
      await Supabase.instance.client.from('ticket').update({'estado_ticket': atendido}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('TicketRepository.actualizarEstadoTicket error: ${e.toString()}');
      rethrow;
    }
  }

  Future<List<dynamic>> obtenerPagosTicket(String ticketId) async {
    try {
      final response = await Supabase.instance.client.from('pago').select('*').eq('ticket_id', ticketId).order('fecha_pago', ascending: false);
      return response as List<dynamic>;
    } catch (e) {
      debugPrint('TicketRepository.obtenerPagosTicket error: ${e.toString()}');
      rethrow;
    }
  }

  Future<List<dynamic>> obtenerSesionesTicket(String ticketId) async {
    try {
      final response = await Supabase.instance.client.from('sesion').select('*, tratamiento:tratamiento_id(*)').eq('ticket_id', ticketId).order('numero_sesion', ascending: true);
      return response as List<dynamic>;
    } catch (e) {
      debugPrint('TicketRepository.obtenerSesionesTicket error: ${e.toString()}');
      rethrow;
    }
  }

  Future<bool> crearTicket(Map<String, dynamic> ticket) async {
    try {
      final clienteId = ticket['cliente'] is int ? ticket['cliente'] : null;
      if (clienteId == null) throw Exception('Cliente no especificado');

      final tratamientos = ticket['tratamientos'];
      if (tratamientos == null || (tratamientos is! List) || tratamientos.isEmpty) {
        throw Exception('Debe seleccionar al menos un tratamiento');
      }

      List<Map<String, dynamic>> itemsCarrito = [];
      for (var tratId in tratamientos) {
        final trat = await Supabase.instance.client.from('tratamiento').select('*').eq('id', tratId).single();
        itemsCarrito.add(Map<String, dynamic>.from(trat));
      }

      final totalVenta = itemsCarrito.fold<double>(0, (sum, t) => sum + ((t['precio'] is num) ? (t['precio'] as num).toDouble() : 0.0));
      final pagoInicial = ticket['cuota'] is num ? (ticket['cuota'] as num).toDouble() : 0.0;
      final sucursalId = ticket['sucursal'] is int ? ticket['sucursal'] : null;

      await registrarVenta(clienteId: clienteId, totalVenta: totalVenta, pagoInicial: pagoInicial, itemsCarrito: itemsCarrito, sucursalId: sucursalId);
      return true;
    } catch (e) {
      debugPrint('TicketRepository.crearTicket error: ${e.toString()}');
      return false;
    }
  }

  Future<void> registrarVenta({
    required int clienteId,
    required double totalVenta,
    required double pagoInicial,
    required List<Map<String, dynamic>> itemsCarrito,
    required int? sucursalId,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');
      final fechaLocal = DateTime.now().toIso8601String();

      List<Map<String, dynamic>> sesionesParaEnviar = [];
      for (var item in itemsCarrito) {
        int idTratamiento = item['id'];
        double precioTratamiento = (item['precio'] is num) ? (item['precio'] as num).toDouble() : 0.0;
        List<dynamic> cronogramaRaw = item['cronograma_sesiones'] ?? [];
        if (cronogramaRaw.isEmpty) throw Exception('El tratamiento ${item['nombreTratamiento'] ?? item['id']} no tiene fechas programadas');
        List<DateTime> fechas = cronogramaRaw.map((f) {
          if (f is DateTime) return f;
          if (f is String) return DateTime.parse(f);
          if (f is Map && f.containsKey('year')) {
            return DateTime(f['year'], f['month'] ?? 1, f['day'] ?? 1, f['hour'] ?? 0, f['minute'] ?? 0);
          }
          throw Exception('Formato de fecha inválido');
        }).toList();
        for (int i = 0; i < fechas.length; i++) {
          sesionesParaEnviar.add({
            'tratamiento_id': idTratamiento,
            'numero_sesion': i + 1,
            'precio_sesion': precioTratamiento,
            'fecha_inicio': fechas[i].toIso8601String()
          });
        }
      }

      final response = await Supabase.instance.client.rpc('crear_venta_completa', params: {
        'p_cliente_id': clienteId,
        'p_empleado_id': userId,
        'p_sucursal_id': sucursalId,
        'p_monto_total': totalVenta,
        'p_monto_pagado_inicial': pagoInicial,
        'p_sesiones': sesionesParaEnviar,
        'p_fecha_creacion': fechaLocal,
      });

      if (response != null && response is Map) {
        if (response['success'] == false) {
          throw Exception('Error del backend: ${response['message'] ?? response['error']}');
        }
      }
    } catch (e) {
      debugPrint('TicketRepository.registrarVenta error: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> searchTickets({required String query, required int sucursalId, int page = 1, int pageSize = 30}) async {
    try {
      final q = query.trim();
      if (q.isEmpty) return {'items': [], 'meta': {'page': page, 'pageSize': pageSize, 'returned': 0, 'total': 0, 'totalPages': 0}};

      final pattern = '%$q%';
      final clientsResp = await Supabase.instance.client.from('cliente').select('id').eq('sucursal_id', sucursalId).or('nombrecliente.ilike.$pattern,apellidocliente.ilike.$pattern,telefono.ilike.$pattern');
      final clientIds = <dynamic>[];
      for (var c in clientsResp as List) { if (c is Map && c['id'] != null) clientIds.add(c['id']); }

      final tratResp = await Supabase.instance.client.from('tratamiento').select('id').ilike('nombretratamiento', pattern);
      final tratIds = <dynamic>[]; for (var t in tratResp as List) { if (t is Map && t['id'] != null) tratIds.add(t['id']); }

      final ticketIdsFromSesiones = <dynamic>[];
      if (tratIds.isNotEmpty) {
        final sesResp = await Supabase.instance.client.from('sesion').select('ticket_id').filter('tratamiento_id', 'in', '(${tratIds.map((e) => e.toString()).join(',')})');
        for (var s in sesResp as List) { if (s is Map && s['ticket_id'] != null) ticketIdsFromSesiones.add(s['ticket_id']); }
      }

      final orParts = <String>[];
      if (clientIds.isNotEmpty) orParts.add('cliente_id.in.(${clientIds.map((e) => e.toString()).join(',')})');
      if (ticketIdsFromSesiones.isNotEmpty) orParts.add('id.in.(${ticketIdsFromSesiones.map((e) => e.toString()).join(',')})');
      if (orParts.isEmpty) return {'items': [], 'meta': {'page': page, 'pageSize': pageSize, 'returned': 0, 'total': 0, 'totalPages': 0}};

      final orFilter = orParts.join(',');
      int total = 0;
      try {
        final countResp = await Supabase.instance.client.from('ticket').select('id').eq('sucursal_id', sucursalId).or(orFilter);
        total = (countResp as List).length;
      } catch (_) { total = 0; }
      final totalPages = (total / pageSize).ceil();

      final offset = (page - 1) * pageSize;
      var queryBuilder = Supabase.instance.client.from('ticket').select('''
            *,
            cliente:cliente_id(nombrecliente,apellidocliente,telefono),
            sesiones:sesion(id,numero_sesion,fecha_hora_inicio,estado_sesion,tratamiento:tratamiento_id(id,nombretratamiento,precio))
          ''').eq('sucursal_id', sucursalId).or(orFilter).order('created_at', ascending: false).limit(pageSize).range(offset, offset + pageSize - 1);

      final response = await queryBuilder;
      final items = List<dynamic>.from(response as List);
      return {
        'items': items,
        'meta': {
          'page': page,
          'pageSize': pageSize,
          'returned': items.length,
          'total': total,
          'totalPages': totalPages,
        }
      };
    } catch (e) {
      debugPrint('TicketRepository.searchTickets error: ${e.toString()}');
      rethrow;
    }
  }

  Future<bool> eliminarTicket(dynamic documentId) async {
    try {
      final id = documentId?.toString();
      if (id == null || id.isEmpty) throw Exception('ID inválido');

      // Eliminar pagos asociados
      try {
        await Supabase.instance.client.from('pago').delete().eq('ticket_id', id);
      } catch (e) {
        // No fatal: registrar y continuar
        debugPrint('TicketRepository.eliminarTicket: warning al eliminar pagos: ${e.toString()}');
      }

      // Eliminar sesiones asociadas
      try {
        await Supabase.instance.client.from('sesion').delete().eq('ticket_id', id);
      } catch (e) {
        debugPrint('TicketRepository.eliminarTicket: warning al eliminar sesiones: ${e.toString()}');
      }

      // Finalmente eliminar el ticket
      await Supabase.instance.client.from('ticket').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('TicketRepository.eliminarTicket error: ${e.toString()}');
      return false;
    }
  }

  /// Compatibilidad: obtener tickets con filtros opcionales (sucursal y estadoTicket)
  Future<List<dynamic>> getTickets({int? sucursalId, bool? estadoTicket}) async {
    try {
      var qb = Supabase.instance.client.from('ticket').select('''
            *,
            cliente:cliente_id(nombrecliente,apellidocliente,telefono),
            sesiones:sesion(id,numero_sesion,fecha_hora_inicio,estado_sesion,tratamiento:tratamiento_id(id,nombretratamiento,precio))
          ''');
      if (sucursalId != null) qb = qb.eq('sucursal_id', sucursalId);
      if (estadoTicket != null) qb = qb.eq('estado_ticket', estadoTicket);
      final resp = await qb.order('created_at', ascending: false);
      return resp as List<dynamic>;
    } catch (e) {
      debugPrint('TicketRepository.getTickets error: ${e.toString()}');
      rethrow;
    }
  }
}
