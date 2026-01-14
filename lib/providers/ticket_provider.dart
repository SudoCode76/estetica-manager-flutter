import 'package:flutter/material.dart';
import 'package:app_estetica/services/api_service.dart';

class TicketProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _tickets = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get tickets => _tickets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Evitar fetches paralelos
  bool _fetchInProgress = false;

  // Últimos filtros usados por fetchTickets
  int? _lastSucursalId;
  bool? _lastEstadoTicket;

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
      final data = await _api.getTickets(sucursalId: sucursalId, estadoTicket: estadoTicket);
      _tickets = data;
      _error = null;
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
}
