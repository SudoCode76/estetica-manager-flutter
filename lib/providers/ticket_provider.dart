import 'package:flutter/material.dart';
import 'package:app_estetica/services/api_service.dart';

class TicketProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _tickets = [];
  List<dynamic> _agenda = []; // Nueva: sesiones del día
  bool _isLoading = false;
  bool _isLoadingAgenda = false;
  String? _error;

  List<dynamic> get tickets => _tickets;
  List<dynamic> get agenda => _agenda;
  bool get isLoading => _isLoading;
  bool get isLoadingAgenda => _isLoadingAgenda;
  String? get error => _error;

  // Evitar fetches paralelos
  bool _fetchInProgress = false;

  // Últimos filtros usados por fetchTickets
  int? _lastSucursalId;
  bool? _lastEstadoTicket;
  DateTime? _lastFechaAgenda;
  DateTime? _lastRangeStart;
  DateTime? _lastRangeEnd;

  /// Fuerza el reset del estado de loading para recuperarse de errores
  void resetLoadingState() {
    _fetchInProgress = false;
    _isLoading = false;
    notifyListeners();
  }

  Future<List<dynamic>> fetchTickets({int? sucursalId, bool? estadoTicket, bool forceRefresh = false}) async {
    // Si forceRefresh es true, resetear el estado primero
    if (forceRefresh) {
      _fetchInProgress = false;
    }

    // Si ya hay un fetch en progreso, esperar un poco y reintentar una vez
    if (_fetchInProgress) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_fetchInProgress) {
        // Si aún está en progreso después de esperar, resetear para evitar bloqueo permanente
        print('TicketProvider: Fetch stuck, resetting state');
        _fetchInProgress = false;
      }
    }

    // Guardar los filtros utilizados para permitir un "refresh" igual al botón
    _lastSucursalId = sucursalId;
    _lastEstadoTicket = estadoTicket;

    _fetchInProgress = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validar que hay sucursal seleccionada
      if (sucursalId == null) {
        _error = 'Debe seleccionar una sucursal primero';
        _tickets = [];
        print('TicketProvider: Cannot fetch tickets - sucursalId is null');
        return _tickets;
      }

      print('TicketProvider: Fetching tickets del día for sucursalId=$sucursalId');

      // Usar getTicketsDelDia para obtener tickets creados hoy
      final data = await _api.getTicketsDelDia(
        fecha: DateTime.now(),
        sucursalId: sucursalId,
      );

      _tickets = data;
      _error = null;
      print('TicketProvider: Fetched ${_tickets.length} tickets del día');
      return _tickets;
    } catch (e) {
      _error = e.toString();
      print('TicketProvider: Error fetching tickets: $e');
      return _tickets;
    } finally {
      _isLoading = false;
      _fetchInProgress = false;
      notifyListeners();
    }
  }

  /// Re-ejecuta el último fetch con los filtros guardados.
  Future<List<dynamic>> fetchCurrent({bool forceRefresh = false}) async {
    return fetchTickets(
      sucursalId: _lastSucursalId,
      estadoTicket: _lastEstadoTicket,
      forceRefresh: forceRefresh,
    );
  }

  // Añadir ticket localmente evitando duplicados por id
  void addTicketLocal(Map<String, dynamic> ticket) {
    final id = ticket['id'] ?? ticket['documentId'];
    if (id == null) return;
    final exists = _tickets.any((t) => (t['id'] ?? t['documentId']) == id);
    if (!exists) {
      _tickets.insert(0, ticket);
      notifyListeners();
    }
  }

  // Reemplazar lista manualmente
  void replaceTickets(List<dynamic> newTickets) {
    _tickets = newTickets;
    notifyListeners();
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ------------------ NUEVA ARQUITECTURA ------------------

  /// Obtener agenda diaria (sesiones programadas para una fecha)
  Future<List<dynamic>> fetchAgenda(DateTime fecha, {int? sucursalId, String? estadoSesion}) async {
    _lastFechaAgenda = fecha;
    _isLoadingAgenda = true;
    _error = null;
    notifyListeners();

    try {
      // Validar que hay sucursal seleccionada
      if (sucursalId == null) {
        _error = 'Debe seleccionar una sucursal primero';
        _agenda = [];
        print('TicketProvider: Cannot fetch agenda - sucursalId is null');
        return _agenda;
      }

      print('TicketProvider: Fetching agenda for fecha=$fecha, sucursalId=$sucursalId, estado=$estadoSesion');
      final data = await _api.obtenerAgenda(fecha, sucursalId: sucursalId, estadoSesion: estadoSesion);
      _agenda = data;
      _error = null;
      print('TicketProvider: Fetched ${_agenda.length} agenda items');
      return _agenda;
    } catch (e) {
      _error = e.toString();
      print('TicketProvider: Error fetching agenda: $e');
      return _agenda;
    } finally {
      _isLoadingAgenda = false;
      notifyListeners();
    }
  }

  /// Refrescar agenda con la última fecha consultada
  Future<List<dynamic>> refreshAgenda({int? sucursalId}) async {
    if (_lastFechaAgenda == null) return _agenda;
    return fetchAgenda(_lastFechaAgenda!, sucursalId: sucursalId);
  }

  /// Obtener tickets pendientes de pago
  Future<List<dynamic>> fetchTicketsPendientes({int? sucursalId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.obtenerTicketsPendientes(sucursalId: sucursalId);
      _tickets = data;
      _error = null;
      return _tickets;
    } catch (e) {
      _error = e.toString();
      print('TicketProvider: Error fetching tickets pendientes: $e');
      return _tickets;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtener detalle completo de un ticket
  Future<Map<String, dynamic>?> fetchTicketDetalle(String ticketId) async {
    try {
      return await _api.obtenerTicketDetalle(ticketId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      print('TicketProvider: Error fetching ticket detalle: $e');
      return null;
    }
  }

  /// Registrar abono (pago parcial/total)
  Future<bool> registrarAbono({
    required String ticketId,
    required double montoAbono,
    String metodoPago = 'efectivo',
  }) async {
    try {
      await _api.registrarAbono(
        ticketId: ticketId,
        montoAbono: montoAbono,
        metodoPago: metodoPago,
      );

      // Refrescar lista de tickets pendientes después de registrar abono
      await fetchTicketsPendientes(sucursalId: _lastSucursalId);

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      print('TicketProvider: Error registrando abono: $e');
      return false;
    }
  }

  /// Marcar sesión como atendida
  Future<bool> marcarSesionAtendida(String sesionId) async {
    try {
      await _api.marcarSesionAtendida(sesionId);
      // No refrescamos aquí. La UI debe llamar a fetchAgenda/_loadAgenda para recargar con el rango correcto.
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      print('TicketProvider: Error marcando sesión atendida: $e');
      return false;
    }
  }

  /// Reprogramar sesión
  Future<bool> reprogramarSesion(String sesionId, DateTime nuevaFecha) async {
    try {
      await _api.reprogramarSesion(sesionId, nuevaFecha);
      // No refrescamos aquí. La UI debe volver a pedir la agenda con el rango actual.
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      print('TicketProvider: Error reprogramando sesión: $e');
      return false;
    }
  }

  /// Obtener tickets por rango de fechas (historial)
  Future<List<dynamic>> fetchTicketsByRange({
    required DateTime start,
    required DateTime end,
    required int sucursalId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _lastSucursalId = sucursalId;
      _lastEstadoTicket = null; // no aplica
      _lastRangeStart = start;
      _lastRangeEnd = end;

      final data = await _api.getTicketsByRange(start: start, end: end, sucursalId: sucursalId);
      _tickets = data;
      _error = null;
      return _tickets;
    } catch (e) {
      _error = e.toString();
      print('TicketProvider: Error fetching tickets by range: $e');
      return _tickets;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Re-ejecuta el último fetch de historial si existe
  Future<List<dynamic>> refreshLastRange() async {
    if (_lastRangeStart == null || _lastRangeEnd == null || _lastSucursalId == null) return _tickets;
    return fetchTicketsByRange(start: _lastRangeStart!, end: _lastRangeEnd!, sucursalId: _lastSucursalId!);
  }

  /// Obtener agenda por rango de fechas
  Future<List<dynamic>> fetchAgendaRango({
    required DateTime start,
    required DateTime end,
    required int sucursalId,
    String? estadoSesion,
  }) async {
    _lastRangeStart = start;
    _lastRangeEnd = end;
    _isLoadingAgenda = true;
    _error = null;
    notifyListeners();

    try {
      print('TicketProvider: Fetching agenda por rango $start - $end for sucursal $sucursalId, estado=$estadoSesion');
      final data = await _api.obtenerAgendaPorRango(
        fechaInicio: start,
        fechaFin: end,
        sucursalId: sucursalId,
        estadoSesion: estadoSesion,
      );
      _agenda = data;
      _error = null;
      print('TicketProvider: Fetched ${_agenda.length} agenda items (rango)');
      return _agenda;
    } catch (e) {
      _error = e.toString();
      _agenda = [];
      print('TicketProvider: Error fetching agenda por rango: $e');
      return _agenda;
    } finally {
      _isLoadingAgenda = false;
      notifyListeners();
    }
  }
}
