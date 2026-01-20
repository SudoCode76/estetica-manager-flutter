import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReportProvider extends ChangeNotifier {
  final ApiService api;

  ReportProvider({required this.api});

  bool isLoading = false;
  String? error;

  Map<String, dynamic>? dailyReport;
  List<dynamic>? debtList;

  // Nuevos campos para transacciones paginadas
  List<dynamic> transactions = [];
  int transactionsPage = 1;
  int transactionsPageSize = 30;
  bool transactionsHasMore = true;
  bool isLoadingMore = false;

  Future<void> fetchDaily({String? start, String? end, int? sucursalId}) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      dailyReport = await api.getDailyReport(start: start, end: end, sucursalId: sucursalId);
    } catch (e) {
      error = e.toString();
      dailyReport = null;
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchDebt({int? sucursalId}) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      debtList = await api.getDebtReport(sucursalId: sucursalId);
    } catch (e) {
      error = e.toString();
      debtList = null;
    }
    isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> fetchClientDetail(int clientId) async {
    try {
      final r = await api.getClientReport(clientId);
      return r;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Cargar página de transacciones (pagos). Si append=true, concatena a la lista actual.
  Future<void> fetchTransactionsPage({String? start, String? end, int? sucursalId, int page = 1, int pageSize = 30, bool append = false}) async {
    if (!append) {
      isLoading = true;
      error = null;
      notifyListeners();
    } else {
      isLoadingMore = true;
      notifyListeners();
    }

    try {
      final res = await api.getPagosPaginated(start: start, end: end, sucursalId: sucursalId, page: page, pageSize: pageSize);
      final items = List<dynamic>.from(res['items'] ?? []);
      final meta = res['meta'] ?? {};

      if (append) {
        transactions.addAll(items);
      } else {
        transactions = items;
      }

      // Determinar si hay más páginas
      try {
        final pagination = meta['pagination'] ?? {};
        final current = (pagination['page'] ?? pagination['currentPage'] ?? page) as int;
        final pageCount = (pagination['pageCount'] ?? pagination['totalPages'] ?? (current >= 1 ? current : page)) as int;
        transactionsPage = current;
        transactionsHasMore = current < pageCount;
      } catch (_) {
        // Si no hay meta, suponer que no hay más si items < pageSize
        transactionsPage = page;
        transactionsHasMore = items.length >= pageSize;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refreshTransactions({String? start, String? end, int? sucursalId}) async {
    transactionsPage = 1;
    transactionsHasMore = true;
    await fetchTransactionsPage(start: start, end: end, sucursalId: sucursalId, page: transactionsPage, pageSize: transactionsPageSize, append: false);
  }

  /// Cargar siguiente página si existe
  Future<void> loadMoreTransactions({String? start, String? end, int? sucursalId}) async {
    if (!transactionsHasMore || isLoadingMore) return;
    final next = transactionsPage + 1;
    await fetchTransactionsPage(start: start, end: end, sucursalId: sucursalId, page: next, pageSize: transactionsPageSize, append: true);
  }
}
