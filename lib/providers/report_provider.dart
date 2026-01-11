import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReportProvider extends ChangeNotifier {
  final ApiService api;

  ReportProvider({required this.api});

  bool isLoading = false;
  String? error;

  Map<String, dynamic>? dailyReport;
  List<dynamic>? debtList;

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
}

