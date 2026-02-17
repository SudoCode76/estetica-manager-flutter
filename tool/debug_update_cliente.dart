import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

Future<void> main() async {
  final base = 'http://localhost:1337/api';
  final documentId = 'zbjwkty367jiivyb6h1x2886';
  final url = Uri.parse('$base/clientes/$documentId');
  final body = jsonEncode({
    'data': {'nombreCliente': 'Nuevo Nombre de Prueba desde script'},
  });

  try {
    final resp = await http
        .put(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 8));
    if (kDebugMode) debugPrint('Status: ${resp.statusCode}');
    if (kDebugMode) debugPrint('Body: ${resp.body}');
  } catch (e) {
    if (kDebugMode) debugPrint('Error: $e');
  }
}
