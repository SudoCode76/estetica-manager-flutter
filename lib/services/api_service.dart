import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Para depuración: si quieres forzar temporalmente la base URL (por ejemplo usar la IP de tu PC), setea esta variable.
  // Ejemplo: ApiService.debugBaseUrl = 'http://192.168.100.148:1337/api';
  static String? debugBaseUrl;

  // Base URL dependiente de la plataforma
  String get _baseUrl {
    if (debugBaseUrl != null && debugBaseUrl!.isNotEmpty) return debugBaseUrl!;
    // En web y iOS simulador podemos usar localhost si el backend corre en la misma máquina
    if (kIsWeb) return 'http://localhost:1337/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:1337/api';
      // iOS simulator or macOS
      if (Platform.isIOS || Platform.isMacOS) return 'http://localhost:1337/api';
      // Fallback
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

  Future<List<dynamic>> getClientes({int? sucursalId, String? query}) async {
    final headers = await _getHeaders();
    try {
      // Si se pide filtrar por sucursal, preferimos pedir populate[sucursal]=true combinado con el filtro
      if (sucursalId != null) {
        final endpoint = '$_baseUrl/clientes?filters[sucursal][id]=$sucursalId&populate[sucursal]=true${query != null && query.isNotEmpty ? '&filters[nombreCliente][contains]=$query' : ''}';
        print('ApiService.getClientes: calling filter+populate endpoint: $endpoint');
        final response = await _getWithTimeout(Uri.parse(endpoint), headers);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final raw = data['data'] ?? [];
          final normalized = _normalizeItems(List<dynamic>.from(raw));
          print('ApiService.getClientes: filter+populate returned ${normalized.length} items');
          return normalized;
        } else {
          print('getClientes failed (filter+populate). Status: ${response.statusCode}');
          print('Body: ${response.body}');
        }
      }
      String endpoint = '$_baseUrl/clientes';
      List<String> params = [];
      if (sucursalId != null) params.add('filters[sucursal][id]=$sucursalId');
      if (query != null && query.isNotEmpty) params.add('filters[nombreCliente][contains]=$query');
      if (params.isNotEmpty) endpoint += '?${params.join('&')}';
      final url = Uri.parse(endpoint);
      print('ApiService.getClientes: calling direct endpoint: $endpoint');
      final response = await _getWithTimeout(url, headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['data'] ?? [];
        final normalized = _normalizeItems(List<dynamic>.from(raw));
        print('ApiService.getClientes: direct returned ${normalized.length} items');
        if (sucursalId != null) {
          if (normalized.isNotEmpty) {
            print('ApiService.getClientes: direct returned items for filter sucursal $sucursalId, returning ${normalized.length} items (trusting server filter)');
            return normalized;
          }
          // si no devolvió resultados, intentamos con populate
        } else {
          return normalized;
        }
      } else {
        print('getClientes failed (direct). Status: ${response.statusCode}');
        print('Body: ${response.body}');
      }
    } catch (e) {
      print('Exception en getClientes (direct/filter+populate): $e');
    }

    try {
      String popEndpoint = '$_baseUrl/clientes?populate[sucursal]=true';
      if (query != null && query.isNotEmpty) popEndpoint += '&filters[nombreCliente][contains]=$query';
      print('ApiService.getClientes: calling populate endpoint: $popEndpoint');
      final respPop = await _getWithTimeout(Uri.parse(popEndpoint), headers);
      if (respPop.statusCode == 200) {
        final dataPop = jsonDecode(respPop.body);
        final rawPop = dataPop['data'] ?? [];
        final normalizedPop = _normalizeItems(List<dynamic>.from(rawPop));
        print('ApiService.getClientes: populate returned ${normalizedPop.length} items');
        if (sucursalId != null) {
          final filtered = normalizedPop.where((c) => _clientMatchesSucursal(c, sucursalId)).toList();
          print('ApiService.getClientes: populate filtered to ${filtered.length} items by sucursal $sucursalId');
          return filtered;
        }
        return normalizedPop;
      } else {
        print('getClientes populate failed: ${respPop.statusCode}');
        print('Body: ${respPop.body}');
      }
    } catch (e) {
      print('Exception en getClientes (populate): $e');
    }

    try {
      final urlAll = Uri.parse('$_baseUrl/clientes');
      final responseAll = await _getWithTimeout(urlAll, headers);
      if (responseAll.statusCode == 200) {
        final dataAll = jsonDecode(responseAll.body);
        final rawAll = dataAll['data'] ?? [];
        final normalized = _normalizeItems(List<dynamic>.from(rawAll));
        print('ApiService.getClientes: fallback returned ${normalized.length} items');
        List<dynamic> items = normalized;
        if (query != null && query.isNotEmpty) {
          final q = query.toLowerCase();
          items = items.where((c) {
            try {
              final nombre = (c['nombreCliente'] ?? '').toString().toLowerCase();
              final apellido = (c['apellidoCliente'] ?? '').toString().toLowerCase();
              final tel = (c['telefono'] ?? '').toString().toLowerCase();
              return nombre.contains(q) || apellido.contains(q) || tel.contains(q);
            } catch (_) {
              return false;
            }
          }).toList();
        }
        if (sucursalId != null) {
          items = items.where((c) => _clientMatchesSucursal(c, sucursalId)).toList();
        }
        return items;
      } else {
        throw Exception('Error al obtener clientes (all) - ${responseAll.statusCode}');
      }
    } catch (e) {
      print('Exception en getClientes (all): $e');
      throw Exception('Error al obtener clientes: $e');
    }
  }

  bool _clientHasSucursalInfo(dynamic c) {
    try {
      if (c is Map) {
        if (c.containsKey('sucursal')) return true;
        if (c.containsKey('attributes') && c['attributes'] is Map && (c['attributes'] as Map).containsKey('sucursal')) return true;
      }
    } catch (_) {}
    return false;
  }

  bool _clientMatchesSucursal(dynamic c, int sucursalId) {
    try {
      if (c == null) return false;
      // formatos posibles después de _normalizeItems: c is Map with keys, maybe 'sucursal' present as Map or int
      if (c is Map) {
        final s = c['sucursal'];
        if (s == null) return false;
        if (s is int) return s == sucursalId;
        if (s is Map) {
          if (s.containsKey('id') && s['id'] == sucursalId) return true;
          if (s.containsKey('data') && s['data'] is Map && s['data']['id'] == sucursalId) return true;
        }
        // también revisar si existe 'sucursalId' directamente
        if (c.containsKey('sucursalId') && c['sucursalId'] == sucursalId) return true;
      }
    } catch (_) {}
    return false;
  }

  // Crear cliente
  Future<Map<String, dynamic>> crearCliente(Map<String, dynamic> cliente) async {
    final url = Uri.parse('$_baseUrl/clientes');
    final headers = await _getHeaders();
    final response = await _postWithTimeout(url, headers, jsonEncode({'data': cliente}));
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      print('Error al crear cliente: ${response.body}');
      throw Exception('Error al crear cliente');
    }
  }

  // Actualizar cliente
  Future<Map<String, dynamic>> updateCliente(int id, Map<String, dynamic> cliente) async {
    final url = Uri.parse('$_baseUrl/clientes/$id');
    final headers = await _getHeaders();
    final response = await _putWithTimeout(url, headers, jsonEncode({'data': cliente}));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      print('Error al actualizar cliente: ${response.body}');
      throw Exception('Error al actualizar cliente');
    }
  }

  // Eliminar cliente
  Future<bool> deleteCliente(int id) async {
    final url = Uri.parse('$_baseUrl/clientes/$id');
    final headers = await _getHeaders();
    try {
      final response = await http.delete(url, headers: headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        print('Error al eliminar cliente: ${response.body}');
        throw Exception('Error al eliminar cliente');
      }
    } catch (e) {
      print('Exception al eliminar cliente: $e');
      throw Exception('Error al eliminar cliente: $e');
    }
  }

  // Obtener todos los tratamientos
  Future<List<dynamic>> getTratamientos({int? categoriaId}) async {
    final headers = await _getHeaders();
    // Si no se pide filtrar, devolver todos directamente (rápido)
    if (categoriaId == null) {
      try {
        final urlAll = Uri.parse('$_baseUrl/tratamientos');
        final responseAll = await _getWithTimeout(urlAll, headers);
        if (responseAll.statusCode == 200) {
          final dataAll = jsonDecode(responseAll.body);
          final rawAll = dataAll['data'] ?? [];
          return _normalizeItems(rawAll);
        }
      } catch (_) {}
    }
    // 1) Intentar petición directa con filtro (asume relación 'categoria')
    if (categoriaId != null) {
      final candidateKeys = ['categoria', 'categoria_tratamiento', 'categoriaTratamiento', 'categoria_tratamientos', 'categoria-tratamientos', 'categoriaTratamientos'];
      for (final key in candidateKeys) {
        try {
          final endpoint = '$_baseUrl/tratamientos?filters[$key][id]=$categoriaId';
          final url = Uri.parse(endpoint);
          final response = await _getWithTimeout(url, headers);
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final raw = data['data'] ?? [];
            final normalized = _normalizeItems(raw);
            return normalized;
          } else {
            // 400 posible -> seguir con siguiente clave
            print('getTratamientos filter by $key failed: ${response.statusCode}');
          }
        } catch (e) {
          print('Exception testing filter key $key: $e');
        }
      }
      // 2) Intentar obtener tratamientos con populate=* para ver si la relación de categoría está presente
      try {
        final urlPop = Uri.parse('$_baseUrl/tratamientos?populate=*');
        final respPop = await http.get(urlPop, headers: headers);
        if (respPop.statusCode == 200) {
          final dataPop = jsonDecode(respPop.body);
          final rawPop = dataPop['data'] ?? [];
          final normalizedPop = _normalizeItems(rawPop);
          final filtered = normalizedPop.where((item) {
            final catId = _extractCategoryId(item);
            return catId != null && catId == categoriaId;
          }).toList();
          return filtered;
        } else {
          print('populate=* failed: ${respPop.statusCode}');
          print('Body: ${respPop.body}');
        }
      } catch (e) {
        print('Exception getting tratamientos populate: $e');
      }

      // 3) Intentar obtener la categoria con populate de tratamientos (si la relación está en el otro sentido)
      try {
        final urlCat = Uri.parse('$_baseUrl/categoria-tratamientos/$categoriaId?populate=tratamientos');
        final respCat = await http.get(urlCat, headers: headers);
        if (respCat.statusCode == 200) {
          final dataCat = jsonDecode(respCat.body);
          final d = dataCat['data'];
          if (d != null) {
            // intentar extraer tratamientos desde diferentes estructuras
            final attrs = d['attributes'] ?? d;
            dynamic list = attrs['tratamientos'] ?? attrs['tratamientos'];
            if (list == null && attrs is Map && attrs.containsKey('data')) {
              list = attrs['data'];
            }
            if (list is List && list.isNotEmpty) {
              return _normalizeItems(list);
            }
            // Si viene en formato data.attributes
            if (d is Map && d.containsKey('attributes') && d['attributes'] is Map) {
              final possible = d['attributes']['tratamientos'];
              if (possible is List) return _normalizeItems(possible);
            }
          }
        } else {
          print('categoria populate failed: ${respCat.statusCode}');
        }
      } catch (e) {
        print('Exception getting category populate: $e');
      }
      // 4) último recurso: devolver todos los tratamientos
      try {
        final urlAll = Uri.parse('$_baseUrl/tratamientos');
        final responseAll = await _getWithTimeout(urlAll, headers);
        if (responseAll.statusCode == 200) {
          final dataAll = jsonDecode(responseAll.body);
          final rawAll = dataAll['data'] ?? [];
          return _normalizeItems(rawAll);
        }
      } catch (e) {
        print('Exception final getTratamientos: $e');
      }
      // Si todo falla, devolver lista vacía para evitar excepciones en UI
      return [];
    }

    // 2) Fallback: pedir todos los tratamientos sin populate y devolverlos (no siempre habrá relación categoría en el backend)
    try {
      final urlAll = Uri.parse('$_baseUrl/tratamientos');
      final responseAll = await _getWithTimeout(urlAll, headers);
      if (responseAll.statusCode == 200) {
        final dataAll = jsonDecode(responseAll.body);
        final rawAll = dataAll['data'] ?? [];
        final normalized = _normalizeItems(rawAll);
        // Si pedían filtrar por categoria pero no fue posible, devolvemos todos (UI mostrará aviso)
        return normalized;
      } else {
        print('getTratamientos failed (all) Status: ${responseAll.statusCode}');
        print('Body: ${responseAll.body}');
        throw Exception('Error al obtener tratamientos (all) - ${responseAll.statusCode}');
      }
    } catch (e) {
      print('Exception en getTratamientos (all): $e');
      throw Exception('Error al obtener tratamientos: $e');
    }
  }

  // Obtener categorias de tratamientos
  Future<List<dynamic>> getCategorias() async {
    final url = Uri.parse('$_baseUrl/categoria-tratamientos');
    final headers = await _getHeaders();
    final response = await _getWithTimeout(url, headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Error al obtener categorias de tratamientos');
    }
  }

  // Obtener usuarios (opcionalmente filtrados por sucursal)
  Future<List<dynamic>> getUsuarios({int? sucursalId, String? query}) async {
    final headers = await _getHeaders();

    // 1) Intento con filtro+populate si hay sucursalId
    if (sucursalId != null) {
      try {
        String endpoint = '$_baseUrl/users?filters[sucursal][id]=$sucursalId&populate[sucursal]=true';
        if (query != null && query.isNotEmpty) {
          endpoint += '&filters[username][\$containsi]=$query';
        }
        print('ApiService.getUsuarios: calling filter+populate endpoint: $endpoint');
        final resp = await _getWithTimeout(Uri.parse(endpoint), headers);
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final list = List<dynamic>.from((data is List) ? data : (data['data'] ?? data));
          print('ApiService.getUsuarios: filter+populate returned ${list.length} items');
          return list;
        } else {
          print('getUsuarios failed (filter+populate) ${resp.statusCode}: ${resp.body}');
        }
      } catch (e) {
        print('Exception en getUsuarios (filter+populate): $e');
      }
    }

    // 2) Directo sin filtros
    try {
      final resp = await _getWithTimeout(Uri.parse('$_baseUrl/users'), headers);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = List<dynamic>.from((data is List) ? data : (data['data'] ?? []));

        // Filtrar client-side si hay sucursalId
        if (sucursalId != null) {
          final filtered = list.where((u) {
            try {
              final s = (u['sucursal'] ?? u['attributes']?['sucursal']);
              if (s == null) return false;
              if (s is int) return s == sucursalId;
              if (s is Map) {
                if (s.containsKey('id')) return s['id'] == sucursalId;
                if (s.containsKey('data') && s['data'] is Map) return s['data']['id'] == sucursalId;
              }
              return false;
            } catch (_) { return false; }
          }).toList();
          print('ApiService.getUsuarios: direct filtered to ${filtered.length} items');
          return filtered;
        }
        return list;
      } else {
        print('getUsuarios failed (direct) ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      print('Exception en getUsuarios (direct): $e');
    }

    // 3) populate sin filtro y filtrar client-side
    try {
      final resp = await _getWithTimeout(Uri.parse('$_baseUrl/users?populate[sucursal]=true'), headers);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = List<dynamic>.from((data is List) ? data : (data['data'] ?? []));

        if (sucursalId != null) {
          final filtered = list.where((u) {
            try {
              final s = (u['sucursal'] ?? u['attributes']?['sucursal']);
              if (s == null) return false;
              if (s is int) return s == sucursalId;
              if (s is Map) {
                if (s.containsKey('id')) return s['id'] == sucursalId;
                if (s.containsKey('data') && s['data'] is Map) return s['data']['id'] == sucursalId;
              }
              return false;
            } catch (_) { return false; }
          }).toList();
          print('ApiService.getUsuarios: populate filtered to ${filtered.length} items');
          return filtered;
        }
        return list;
      } else {
        print('getUsuarios failed (populate) ${resp.statusCode}: ${resp.body}');
        throw Exception('Error al obtener usuarios');
      }
    } catch (e) {
      print('Exception en getUsuarios (populate): $e');
      throw Exception('Error al obtener usuarios');
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
    final response = await _getWithTimeout(url, headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Error al obtener sucursales');
    }
  }

  // Obtener tickets filtrados por sucursal (estructura directa o por cliente)
  Future<List<dynamic>> getTickets({int? sucursalId, bool? estadoTicket}) async {
    // 1. Intentar con relación directa - ahora usando tratamientos (plural) ya que un ticket puede tener múltiples tratamientos
    String url = '$_baseUrl/tickets?populate[cliente]=true&populate[tratamientos]=true&populate[sucursal]=true&populate[users_permissions_user]=true';
    if (sucursalId != null) {
      url += '&filters[sucursal][id]=$sucursalId';
    }
    if (estadoTicket != null) {
      url += '&filters[estadoTicket]=$estadoTicket';
    }
    final headers = await _getHeaders();
    final response = await _getWithTimeout(Uri.parse(url), headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Si hay resultados o no se filtró por sucursal, devolverlos
      if ((data['data'] != null && (data['data'] as List).isNotEmpty) || sucursalId == null) {
        return data['data'] ?? [];
      }
    }
    // 2. Si no hay resultados y se filtró por sucursal, intentar por cliente.sucursal
    if (sucursalId != null) {
      String urlCliente = '$_baseUrl/tickets?populate[cliente][populate][sucursal]=true&populate[tratamientos]=true&populate[users_permissions_user]=true';
      urlCliente += '&filters[cliente][sucursal][id]=$sucursalId';
      if (estadoTicket != null) {
        urlCliente += '&filters[estadoTicket]=$estadoTicket';
      }
      final responseCliente = await _getWithTimeout(Uri.parse(urlCliente), headers);
      if (responseCliente.statusCode == 200) {
        final dataCliente = jsonDecode(responseCliente.body);
        return dataCliente['data'] ?? [];
      }
    }
    return [];
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

  // Helper: normaliza items que pueden venir como {id, attributes: {...}} o directamente como map plano
  List<dynamic> _normalizeItems(List<dynamic> raw) {
    List<dynamic> result = [];
    for (final item in raw) {
      if (item == null) continue;
      if (item is Map && item.containsKey('attributes') && item.containsKey('id')) {
        final attrs = Map<String, dynamic>.from(item['attributes'] ?? {});
        attrs['id'] = item['id'];
        // intentar normalizar category si viene poblada
        if (attrs.containsKey('categoria')) {
          attrs['categoria'] = item['attributes']['categoria'];
        }
        result.add(attrs);
      } else {
        result.add(item);
      }
    }
    return result;
  }

  // Helper: extrae posible category id de un item normalizado (int) o nulo
  int? _extractCategoryId(dynamic item) {
    if (item == null) return null;
    try {
      if (item is Map) {
        // varios formatos posibles
        if (item.containsKey('categoria')) {
          final cat = item['categoria'];
          if (cat == null) return null;
          if (cat is int) return cat;
          if (cat is Map && cat.containsKey('id')) return cat['id'] as int?;
          if (cat is Map && cat.containsKey('data')) {
            final d = cat['data'];
            if (d is Map && d.containsKey('id')) return d['id'] as int?;
          }
        }
        // intentar buscar dentro de atributos anidados
        if (item.containsKey('categoriaId')) return item['categoriaId'] as int?;
      }
    } catch (_) {}
    return null;
  }
}
