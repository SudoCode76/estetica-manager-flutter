import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final base = 'http://localhost:1337/api';
  final documentId = 'zbjwkty367jiivyb6h1x2886';
  final url = Uri.parse('$base/clientes/$documentId');
  final body = jsonEncode({
    'data': {
      'nombreCliente': 'Nuevo Nombre de Prueba desde script'
    }
  });

  try {
    final resp = await http.put(url, headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 8));
    print('Status: \\${resp.statusCode}');
    print('Body: \\${resp.body}');
  } catch (e) {
    print('Error: $e');
  }
}

