
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Reemplaza localhost con la IP de tu computadora, o usa 10.0.2.2 si usas un emulador Android.
  static const String _baseUrl = 'http://192.168.100.148:1337/api';

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/auth/local');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // Imprimir detalles del error para depuración
        print('Failed to login. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to login');
      }
    } catch (e) {
      // Captura errores de conexión (ej. no se puede conectar al host)
      print('Error connecting to the server: $e');
      throw Exception('Cannot connect to the server');
    }
  }
}
