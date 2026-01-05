import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {

  static String? debugBaseUrl;

  String get _baseUrl {
    if (debugBaseUrl != null && debugBaseUrl!.isNotEmpty) return debugBaseUrl!;
    if (kIsWeb) return 'http://localhost:1337/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:1337/api';
      if (Platform.isIOS || Platform.isMacOS) return 'http://localhost:1337/api';
      return 'http://localhost:1337/api';
    } catch (_) {
      return 'http://localhost:1337/api';
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt') ?? '';
    final headers = {'Content-Type': 'application/json'};
    if (jwt.isNotEmpty) {
      headers['Authorization'] = 'Bearer $jwt';
    }
    return headers;
  }

  // HTTP wrappers con timeout para evitar requests colgados
  Future<http.Response> _getWithTimeout(Uri uri, Map<String, String> headers, {int seconds = 8}) async {
    try {
      final resp = await http.get(uri, headers: headers).timeout(Duration(seconds: seconds));
      return resp;
    } catch (e) {
      print('GET request timeout/error for $uri: $e');
      rethrow;
    }
  }

  Future<http.Response> _postWithTimeout(Uri uri, Map<String, String> headers, Object? body, {int seconds = 8}) async {
    try {
      final resp = await http.post(uri, headers: headers, body: body).timeout(Duration(seconds: seconds));
      return resp;
    } catch (e) {
      print('POST request timeout/error for $uri: $e');
      rethrow;
    }
  }

  Future<http.Response> _putWithTimeout(Uri uri, Map<String, String> headers, Object? body, {int seconds = 8}) async {
    try {
      final resp = await http.put(uri, headers: headers, body: body).timeout(Duration(seconds: seconds));
      return resp;
    } catch (e) {
      print('PUT request timeout/error for $uri: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/auth/local');
    try {
      final response = await _postWithTimeout(url, {'Content-Type': 'application/json'}, jsonEncode({
        'identifier': email,
        'password': password,
      }));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to login. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to login');
      }
    } catch (e) {
      print('Error connecting to the server: $e');
      throw Exception('Cannot connect to the server');
    }
  }

  Future<List<dynamic>> getClientes({int? sucursalId, String? query}) async {
    final headers = await _getHeaders();
    final baseUrl = '$_baseUrl/clientes';
    
    final List<String> params = [
      'populate[sucursal]=true'
    ];

    if (sucursalId != null) {
      params.add('filters[sucursal][id][\$eq]=$sucursalId');
    }

    if (query != null && query.isNotEmpty) {
      params.add('filters[\$or][0][nombreCliente][\$containsi]=$query');
      params.add('filters[\$or][1][apellidoCliente][\$containsi]=$query');
    }

    final endpoint = '$baseUrl?${params.join('&')}';
    print('ApiService.getClientes: calling endpoint: $endpoint');

    try {
      final response = await _getWithTimeout(Uri.parse(endpoint), headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['data'] ?? [];
        final normalized = _normalizeItems(List<dynamic>.from(raw));
        print('ApiService.getClientes: returned ${normalized.length} items');
        return normalized;
      } else {
        print('getClientes failed. Status: ${response.statusCode}');
        print('Body: ${response.body}');
        throw Exception('Error al obtener clientes: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception en getClientes: $e');
      throw Exception('Error al obtener clientes: $e');
    }
  }

  // Crear cliente
  Future<Map<String, dynamic>> crearCliente(Map<String, dynamic> cliente) async {
    final url = Uri.parse('$_baseUrl/clientes');
    final headers = await _getHeaders();
    final response = await _postWithTimeout(url, headers, jsonEncode({'data': cliente}));
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return _normalizeItems([data['data']]).first;
    } else {
      print('Error al crear cliente: ${response.body}');
      throw Exception('Error al crear cliente');
    }
  }

  // Actualizar cliente (robusto ante respuestas sin body y diferentes shapes)
  Future<Map<String, dynamic>> updateCliente(String documentId, Map<String, dynamic> cliente) async {
    final url = Uri.parse('$_baseUrl/clientes/$documentId');
    final headers = await _getHeaders();
    try {
      final response = await _putWithTimeout(url, headers, jsonEncode({'data': cliente}));

      print('updateCliente: status=${response.statusCode} body=${response.body}');

      // Aceptar 200/201/204 como éxito
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        // Si no hay body (204 o body vacío), devolver una representación usando los datos enviados
        if (response.body.trim().isEmpty) {
          // Construir objeto consistente: incluir documentId si lo tenemos
          final result = Map<String, dynamic>.from(cliente);
          result['documentId'] = documentId;
          // Si el cliente no tiene un id numérico, intentaremos conservar el campo 'id' si existe
          return result;
        }

        // Intentar parsear body JSON seguro
        try {
          final data = jsonDecode(response.body);

          // El backend puede devolver { data: {...} } o directamente el objeto de datos
          dynamic payload = data;
          if (data is Map && data.containsKey('data')) {
            payload = data['data'];
          }

          // Si payload es un Map y ya contiene 'attributes' lo normalizamos
          if (payload is Map) {
            final normalizedList = _normalizeItems([payload]);
            if (normalizedList.isNotEmpty) return normalizedList.first as Map<String, dynamic>;
          }

          // Si no es el formato esperado, devolver payload si es Map
          if (payload is Map<String, dynamic>) return payload;

          // Fallback: devolver una mezcla del cliente enviado y algunos campos del response si es posible
          return Map<String, dynamic>.from(cliente);
        } catch (e) {
          print('updateCliente: error parsing response body: ${response.body}  error: $e');
          // No fallamos duro; devolvemos una representación basada en lo enviado
          final fallback = Map<String, dynamic>.from(cliente);
          fallback['documentId'] = documentId;
          return fallback;
        }
      } else {
        print('Error al actualizar cliente. Status: ${response.statusCode}');
        print('Body: ${response.body}');
        throw Exception('Error al actualizar cliente: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Exception en updateCliente: $e');
      throw Exception('Error al actualizar cliente: $e');
    }
  }

  // Eliminar cliente
  Future<bool> deleteCliente(String documentId) async {
    final url = Uri.parse('$_baseUrl/clientes/$documentId');
    final headers = await _getHeaders();
    try {
      final response = await http.delete(url, headers: headers).timeout(const Duration(seconds: 8));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Exception al eliminar cliente: $e');
      throw Exception('Error al eliminar cliente: $e');
    }
  }

  // Obtener todos los tratamientos
  Future<List<dynamic>> getTratamientos({int? categoriaId}) async {
    final headers = await _getHeaders();
    final List<String> params = ['populate=*'];

    if (categoriaId != null) {
      params.add('filters[categoria_tratamiento][id][\$eq]=$categoriaId');
    }

    final endpoint = '$_baseUrl/tratamientos?${params.join('&')}';
    print('getTratamientos: llamando a $endpoint');

    try {
      final response = await _getWithTimeout(Uri.parse(endpoint), headers, seconds: 10);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['data'] ?? [];
        return _normalizeItems(raw);
      } else {
        print('getTratamientos error ${response.statusCode}: ${response.body}');
        throw Exception('Failed to load tratamientos');
      }
    } catch (e) {
      print('Exception getTratamientos: $e');
      throw Exception('Failed to load tratamientos: $e');
    }
  }

  // Obtener categorias de tratamientos
  Future<List<dynamic>> getCategorias() async {
    final url = Uri.parse('$_baseUrl/categoria-tratamientos');
    final headers = await _getHeaders();
    try {
      final response = await _getWithTimeout(url, headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _normalizeItems(data['data'] ?? []);
      } else {
        throw Exception('Error al obtener categorias de tratamientos');
      }
    } catch (e) {
      throw Exception('Error al obtener categorias de tratamientos: $e');
    }
  }

  // Crear categoria de tratamiento
  Future<Map<String, dynamic>> crearCategoria(Map<String, dynamic> categoria) async {
    final url = Uri.parse('$_baseUrl/categoria-tratamientos');
    final headers = await _getHeaders();
    try {
      final response = await _postWithTimeout(url, headers, jsonEncode({'data': categoria}));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return _normalizeItems([data['data']]).first;
      } else {
        print('Error al crear categoria: ${response.statusCode} ${response.body}');
        throw Exception('Error al crear categoria');
      }
    } catch (e) {
      print('Exception crearCategoria: $e');
      throw Exception('Error al crear categoria: $e');
    }
  }

  // Crear tratamiento
  Future<Map<String, dynamic>> crearTratamiento(Map<String, dynamic> tratamiento) async {
    final url = Uri.parse('$_baseUrl/tratamientos');
    final headers = await _getHeaders();
    try {
      final response = await _postWithTimeout(url, headers, jsonEncode({'data': tratamiento}), seconds: 10);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return _normalizeItems([data['data']]).first;
      } else {
        print('Error al crear tratamiento: ${response.statusCode} ${response.body}');
        throw Exception('Error al crear tratamiento');
      }
    } catch (e) {
      print('Exception crearTratamiento: $e');
      throw Exception('Error al crear tratamiento: $e');
    }
  }

  // Actualizar categoria de tratamiento
  Future<Map<String, dynamic>> updateCategoria(String documentId, Map<String, dynamic> categoria) async {
    final url = Uri.parse('$_baseUrl/categoria-tratamientos/$documentId');
    final headers = await _getHeaders();
    try {
      final response = await _putWithTimeout(url, headers, jsonEncode({'data': categoria}));
      print('updateCategoria: status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        if (response.body.trim().isEmpty) {
          final result = Map<String, dynamic>.from(categoria);
          result['documentId'] = documentId;
          return result;
        }
        try {
          final data = jsonDecode(response.body);
          dynamic payload = data;
          if (data is Map && data.containsKey('data')) payload = data['data'];
          if (payload is Map) {
            final normalizedList = _normalizeItems([payload]);
            if (normalizedList.isNotEmpty) return normalizedList.first as Map<String, dynamic>;
          }
          if (payload is Map<String, dynamic>) return payload;
          return Map<String, dynamic>.from(categoria);
        } catch (e) {
          print('updateCategoria: error parsing response body: ${response.body} error: $e');
          final fallback = Map<String, dynamic>.from(categoria);
          fallback['documentId'] = documentId;
          return fallback;
        }
      } else {
        print('Error updateCategoria: ${response.statusCode} ${response.body}');
        throw Exception('Error al actualizar categoria: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Exception en updateCategoria: $e');
      throw Exception('Error al actualizar categoria: $e');
    }
  }

  // Actualizar tratamiento
  Future<Map<String, dynamic>> updateTratamiento(String documentId, Map<String, dynamic> tratamiento) async {
    final url = Uri.parse('$_baseUrl/tratamientos/$documentId');
    final headers = await _getHeaders();
    try {
      final response = await _putWithTimeout(url, headers, jsonEncode({'data': tratamiento}), seconds: 10);
      print('updateTratamiento: status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        if (response.body.trim().isEmpty) {
          final result = Map<String, dynamic>.from(tratamiento);
          result['documentId'] = documentId;
          return result;
        }
        try {
          final data = jsonDecode(response.body);
          dynamic payload = data;
          if (data is Map && data.containsKey('data')) payload = data['data'];
          if (payload is Map) {
            final normalizedList = _normalizeItems([payload]);
            if (normalizedList.isNotEmpty) return normalizedList.first as Map<String, dynamic>;
          }
          if (payload is Map<String, dynamic>) return payload;
          return Map<String, dynamic>.from(tratamiento);
        } catch (e) {
          print('updateTratamiento: error parsing response body: ${response.body} error: $e');
          final fallback = Map<String, dynamic>.from(tratamiento);
          fallback['documentId'] = documentId;
          return fallback;
        }
      } else {
        print('Error updateTratamiento: ${response.statusCode} ${response.body}');
        throw Exception('Error al actualizar tratamiento: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Exception en updateTratamiento: $e');
      throw Exception('Error al actualizar tratamiento: $e');
    }
  }

  // Obtener usuarios
  Future<List<dynamic>> getUsuarios({int? sucursalId, String? query}) async {
    final headers = await _getHeaders();
    final List<String> params = ['populate[sucursal]=true'];

    if (sucursalId != null) {
      params.add('filters[sucursal][id][\$eq]=$sucursalId');
    }
    if (query != null && query.isNotEmpty) {
      params.add('filters[username][\$containsi]=$query');
    }

    final endpoint = '$_baseUrl/users?${params.join('&')}';
    print('ApiService.getUsuarios: calling endpoint: $endpoint');

    try {
      final response = await _getWithTimeout(Uri.parse(endpoint), headers);
      if (response.statusCode == 200) {
        // Strapi /users endpoint returns a list directly
        final data = jsonDecode(response.body);
        return List<dynamic>.from(data);
      } else {
        print('getUsuarios failed ${response.statusCode}: ${response.body}');
        throw Exception('Error al obtener usuarios');
      }
    } catch (e) {
      print('Exception en getUsuarios: $e');
      throw Exception('Error al obtener usuarios: $e');
    }
  }

  // Crear un nuevo ticket
  Future<bool> crearTicket(Map<String, dynamic> ticket) async {
    final url = Uri.parse('$_baseUrl/tickets');
    final headers = await _getHeaders();
    final response = await _postWithTimeout(url, headers, jsonEncode({'data': ticket}));
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
    final headers = await _getHeaders();
    try {
      final response = await _getWithTimeout(url, headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _normalizeItems(data['data'] ?? []);
      } else {
        throw Exception('Error al obtener sucursales');
      }
    } catch(e) {
      throw Exception('Error al obtener sucursales: $e');
    }
  }

  // Obtener tickets
  Future<List<dynamic>> getTickets({int? sucursalId, bool? estadoTicket}) async {
    final headers = await _getHeaders();
    final List<String> params = [
      'populate[cliente][populate][sucursal]=true',
      'populate[tratamientos]=true',
      'populate[users_permissions_user]=true',
      'populate[sucursal]=true'
    ];

    if (sucursalId != null) {
      params.add('filters[sucursal][id][\$eq]=$sucursalId');
    }
    if (estadoTicket != null) {
      params.add('filters[estadoTicket][\$eq]=$estadoTicket');
    }

    final endpoint = '$_baseUrl/tickets?${params.join('&')}';
    print('ApiService.getTickets: calling endpoint: $endpoint');
    
    try {
        final response = await _getWithTimeout(Uri.parse(endpoint), headers);
        if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            return _normalizeItems(data['data'] ?? []);
        } else {
            print('getTickets failed. Status: ${response.statusCode}');
            print('Body: ${response.body}');
            throw Exception('Error al obtener tickets: ${response.statusCode}');
        }
    } catch (e) {
        print('Exception en getTickets: $e');
        throw Exception('Error al obtener tickets: $e');
    }
  }

  // Actualizar estado del ticket
  Future<bool> actualizarEstadoTicket(String documentId, bool estadoTicket) async {
    final url = Uri.parse('$_baseUrl/tickets/$documentId');
    final headers = await _getHeaders();
    final response = await _putWithTimeout(url, headers, jsonEncode({'data': {'estadoTicket': estadoTicket}}));
    if (response.statusCode == 200) {
      return true;
    } else {
      print('Error al actualizar estado del ticket: ${response.body}');
      return false;
    }
  }

  // Obtener pagos
  Future<List<dynamic>> getPagos() async {
    final url = Uri.parse('$_baseUrl/pagos');
    final headers = await _getHeaders();
    try {
      final response = await _getWithTimeout(url, headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _normalizeItems(data['data'] ?? []);
      } else {
        print('getPagos failed ${response.statusCode}: ${response.body}');
        throw Exception('Error al obtener pagos');
      }
    } catch (e) {
      print('Exception getPagos: $e');
      throw Exception('Error al obtener pagos: $e');
    }
  }

  // Crear pago
  Future<Map<String, dynamic>> crearPago(Map<String, dynamic> pago) async {
    final url = Uri.parse('$_baseUrl/pagos');
    final headers = await _getHeaders();
    try {
      final body = jsonEncode({'data': pago});
      print('crearPago: POST $url body=$body');
      final response = await _postWithTimeout(url, headers, body, seconds: 10);
      print('crearPago: status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data')) {
          return _normalizeItems([data['data']]).first;
        }
        // fallback
        if (data is Map) return data.cast<String, dynamic>();
        throw Exception('Respuesta inesperada al crear pago');
      } else {
        // Intentar parsear body para dar más contexto
        String msg = 'Error al crear pago: ${response.statusCode}';
        try {
          final parsed = jsonDecode(response.body);
          msg += ' - ${parsed.toString()}';
        } catch (_) {
          msg += ' - ${response.body}';
        }
        print(msg);
        throw Exception(msg);
      }
    } catch (e) {
      print('Exception crearPago: $e');
      rethrow;
    }
  }

  // Actualizar ticket (cuota, saldoPendiente, estadoPago)
  Future<Map<String, dynamic>> updateTicket(String documentId, Map<String, dynamic> ticket) async {
    final url = Uri.parse('$_baseUrl/tickets/$documentId');
    final headers = await _getHeaders();
    try {
      final response = await _putWithTimeout(url, headers, jsonEncode({'data': ticket}), seconds: 10);
      print('updateTicket: status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        if (response.body.trim().isEmpty) {
          final result = Map<String, dynamic>.from(ticket);
          result['documentId'] = documentId;
          return result;
        }
        try {
          final data = jsonDecode(response.body);
          dynamic payload = data;
          if (data is Map && data.containsKey('data')) payload = data['data'];
          if (payload is Map) {
            final normalizedList = _normalizeItems([payload]);
            if (normalizedList.isNotEmpty) return normalizedList.first as Map<String, dynamic>;
          }
          if (payload is Map<String, dynamic>) return payload;
          return Map<String, dynamic>.from(ticket);
        } catch (e) {
          print('updateTicket: error parsing response body: ${response.body} error: $e');
          final fallback = Map<String, dynamic>.from(ticket);
          fallback['documentId'] = documentId;
          return fallback;
        }
      } else {
        print('Error updateTicket: ${response.statusCode} ${response.body}');
        throw Exception('Error al actualizar ticket: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Exception en updateTicket: $e');
      throw Exception('Error al actualizar ticket: $e');
    }
  }

  List<dynamic> _normalizeItems(List<dynamic> items) {
    return items.map((item) {
      if (item is Map && item.containsKey('attributes')) {
        final attrs = Map<String, dynamic>.from(item['attributes']);
        attrs['id'] = item['id'];

        // Copiar campos de primer nivel (p. ej. documentId) si existen y no están en attributes
        item.forEach((key, value) {
          if (key != 'attributes' && key != 'id' && !attrs.containsKey(key)) {
            attrs[key] = value;
          }
        });

        // Deeply normalize relations like 'sucursal' or 'categoria'
        attrs.forEach((key, value) {
          if (value is Map && value.containsKey('data')) {
            final relationData = value['data'];
            if (relationData == null) {
               attrs[key] = null;
            } else if (relationData is Map) {
              attrs[key] = _normalizeItems([relationData]).first;
            } else if (relationData is List) {
              attrs[key] = _normalizeItems(relationData);
            }
          }
        });
        return attrs;
      }
      return item;
    }).toList();
  }
}
