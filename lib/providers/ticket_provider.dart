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

  Future<List<dynamic>> fetchTickets({int? sucursalId, bool? estadoTicket}) async {
    if (_fetchInProgress) return _tickets;
    _fetchInProgress = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.getTickets(sucursalId: sucursalId, estadoTicket: estadoTicket);
      _tickets = data;
      return _tickets;
    } catch (e) {
      _error = e.toString();
      return _tickets;
    } finally {
      _isLoading = false;
      _fetchInProgress = false;
      notifyListeners();
    }
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
}

