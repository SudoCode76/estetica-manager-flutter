import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Usa 10.0.2.2 para emulador Android, o la IP de tu PC para dispositivo físico
  static const String _baseUrl = 'http://10.0.2.2:1337/api';

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

  // Obtener todos los clientes
  Future<List<dynamic>> getClientes() async {
    final url = Uri.parse('$_baseUrl/clientes');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Error al obtener clientes');
    }
  }

  // Obtener todos los tratamientos
  Future<List<dynamic>> getTratamientos() async {
    final url = Uri.parse('$_baseUrl/tratamientos');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Error al obtener tratamientos');
    }
  }

  // Obtener todos los usuarios
  Future<List<dynamic>> getUsuarios() async {
    final url = Uri.parse('$_baseUrl/users');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener usuarios');
    }
  }

  // Crear un nuevo ticket
  Future<bool> crearTicket(Map<String, dynamic> ticket) async {
    final url = Uri.parse('$_baseUrl/tickets');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': ticket}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      print('Error al crear ticket: ${response.body}');
      return false;
    }
  }

  // Obtener todas las sucursales
  Future<List<dynamic>> getSucursales() async {
    final url = Uri.parse('$_baseUrl/sucursals');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Error al obtener sucursales');
    }
  }

  // Obtener tickets filtrados por sucursal (estructura directa o por cliente)
  Future<List<dynamic>> getTickets({int? sucursalId}) async {
    // 1. Intentar con relación directa
    String url = '$_baseUrl/tickets?populate[cliente][populate][sucursal]=true&populate[tratamiento]=true&populate[sucursal]=true';
    if (sucursalId != null) {
      url += '&filters[sucursal][id]=$sucursalId';
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Si hay resultados o no se filtró por sucursal, devolverlos
      if ((data['data'] != null && (data['data'] as List).isNotEmpty) || sucursalId == null) {
        return data['data'] ?? [];
      }
    }
    // 2. Si no hay resultados y se filtró por sucursal, intentar por cliente.sucursal
    if (sucursalId != null) {
      String urlCliente = '$_baseUrl/tickets?populate[cliente][populate][sucursal]=true&populate[tratamiento]=true';
      urlCliente += '&filters[cliente][sucursal][id]=$sucursalId';
      final responseCliente = await http.get(Uri.parse(urlCliente));
      if (responseCliente.statusCode == 200) {
        final dataCliente = jsonDecode(responseCliente.body);
        return dataCliente['data'] ?? [];
      }
    }
    return [];
  }
}
