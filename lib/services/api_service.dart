import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_estetica/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static String? debugBaseUrl;

  static const String _productionUrl = 'https://fantastic-agreement-b2f3f76198.strapiapp.com/api';

  String get _baseUrl {
    // Si se ha establecido una URL de debug manualmente, usarla (para testing)
    if (debugBaseUrl != null && debugBaseUrl!.isNotEmpty) return debugBaseUrl!;

    // Usar URL de producción para todas las plataformas
    return _productionUrl;

    // Para desarrollo local, descomentar las siguientes líneas y comentar el return de arriba:
    /*
    if (kIsWeb) return _localUrl;
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:1337/api';
      if (Platform.isIOS || Platform.isMacOS) return _localUrl;
      return _localUrl;
    } catch (_) {
      return _localUrl;
    }
    */
  }

  Future<Map<String, String>> _getHeaders() async {
    // Unifica headers usados en llamadas a Supabase REST.
    // Incluye siempre la apikey (anon/public) y, si existe, Authorization con access token.
    String jwt = '';
    try {
      final session = Supabase.instance.client.auth.currentSession;
      jwt = session?.accessToken ?? '';
    } catch (_) {}

    if (jwt.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      jwt = prefs.getString('jwt') ?? '';
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'apikey': SupabaseConfig.supabaseAnonKey,
    };
    final hasJwt = jwt.isNotEmpty;
    // Siempre enviar Authorization: si hay JWT usarlo, si no enviar el anon key como Bearer
    headers['Authorization'] = hasJwt ? 'Bearer $jwt' : 'Bearer ${SupabaseConfig.supabaseAnonKey}';

    // Log minimal para debugging: indicar si Authorization está presente (no imprimir token)
    print('_getHeaders: apikey present=${SupabaseConfig.supabaseAnonKey.isNotEmpty}, authorization=${hasJwt ? "present (jwt)" : "present (anon)"}');
    return headers;
  }

  /// Lanza si no hay JWT disponible para llamadas autenticadas.
  Future<void> _ensureJwtExists() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      String jwt = session?.accessToken ?? '';
      if (jwt.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        jwt = prefs.getString('jwt') ?? '';
      }
      if (jwt.isEmpty) throw Exception('No hay token JWT: inicia sesión para realizar esta operación.');
    } catch (e) {
      rethrow;
    }
  }

  // PATCH helper (Supabase REST usa PATCH para updates parciales)
  Future<http.Response> _patchWithTimeout(Uri uri, Map<String, String> headers, Object? body, {int seconds = 8}) async {
    try {
      final resp = await http.patch(uri, headers: headers, body: body).timeout(Duration(seconds: seconds));
      return resp;
    } catch (e) {
      print('PATCH request timeout/error for $uri: $e');
      rethrow;
    }
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

  // ------------------ Helpers / Normalización ------------------
  List<dynamic> _normalizeItems(List<dynamic> items) {
    return items.map((item) {
      if (item is Map && item.containsKey('attributes')) {
        final attrs = Map<String, dynamic>.from(item['attributes']);
        attrs['id'] = item['id'];
        // copy top-level keys
        item.forEach((k, v) {
          if (k != 'attributes' && k != 'id' && !attrs.containsKey(k)) attrs[k] = v;
        });
        // normalize relations that come as { data: {...} }
        attrs.forEach((key, value) {
          if (value is Map && value.containsKey('data')) {
            final relationData = value['data'];
            if (relationData == null) attrs[key] = null;
            else if (relationData is Map) attrs[key] = _normalizeItems([relationData]).first;
            else if (relationData is List) attrs[key] = _normalizeItems(relationData);
          }
        });
        return attrs;
      }
      return item;
    }).toList();
  }

  // ------------------ Auth / Users ------------------
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/auth/local');
    try {
      final response = await _postWithTimeout(url, {'Content-Type': 'application/json'}, jsonEncode({
        'identifier': email,
        'password': password,
      }));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Try to normalize if needed
        try {
          if (data['user'] != null && data['user']['id'] != null) {
            final userId = data['user']['id'];
            final userUrl = Uri.parse('$_baseUrl/users/$userId?populate=*');
            final headers = {'Content-Type': 'application/json'};
            if (data['jwt'] != null) headers['Authorization'] = 'Bearer ${data['jwt']}';
            final userResponse = await _getWithTimeout(userUrl, headers, seconds: 10);
            if (userResponse.statusCode == 200) {
              final decodedUser = jsonDecode(userResponse.body);
              try {
                if (decodedUser is Map && decodedUser.containsKey('data')) {
                  final list = _normalizeItems([decodedUser['data']]);
                  data['user'] = list.first;
                } else if (decodedUser is Map && decodedUser.containsKey('attributes')) {
                  final list = _normalizeItems([decodedUser]);
                  data['user'] = list.first;
                } else if (decodedUser is Map) {
                  data['user'] = decodedUser;
                }
              } catch (e) {
                print('login: error normalizando user: $e');
              }
            }
          }
        } catch (_) {}
        return Map<String, dynamic>.from(data);
      }
      throw Exception('Failed to login: ${response.statusCode} ${response.body}');
    } catch (e) {
      print('login error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getSucursales() async {
    try {
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/sucursales?select=*');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 10);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        // normalize minimal fields
        return data.map((e) {
          if (e is Map<String, dynamic>) return {'id': e['id'], 'nombreSucursal': e['nombreSucursal'] ?? e['nombre_sucursal'] ?? e['name']};
          return e;
        }).toList();
      }
      throw Exception('Error obteniendo sucursales: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('getSucursales error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getUsuarios({int? sucursalId, String? query}) async {
    try {
      final headers = await _getHeaders();
      final params = <String>[];
      if (sucursalId != null) params.add('sucursal_id=eq.$sucursalId');
      if (query != null && query.isNotEmpty) params.add('username=ilike.*${Uri.encodeComponent(query)}*');
      // Construir query correctamente asegurando select=*
      String queryString;
      if (params.isEmpty) queryString = '?select=*';
      else queryString = '?select=*&' + params.join('&');
      final endpoint = '${SupabaseConfig.supabaseUrl}/rest/v1/profiles$queryString';
      final url = Uri.parse(endpoint);
      print('getUsuarios: GET $endpoint (Authorization present=${headers.containsKey('Authorization')})');
      final resp = await _getWithTimeout(url, headers, seconds: 10);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        final normalized = data.map((e) {
          if (e is Map<String, dynamic>) {
            return {
              'id': e['id'],
              'documentId': e['id']?.toString(),
              'username': e['username'] ?? e['user_metadata']?['username'] ?? '',
              'email': e['email'] ?? e['user_metadata']?['email'] ?? '',
              'tipoUsuario': e['tipo_usuario'] ?? e['tipoUsuario'] ?? 'empleado',
              'sucursal': e['sucursal_id'] != null ? {'id': e['sucursal_id'], 'nombreSucursal': null} : null,
              'confirmed': e['confirmed'] ?? true,
              'blocked': e['blocked'] ?? false,
              'createdAt': e['created_at'] ?? e['createdAt'],
            };
          }
          return e;
        }).toList();

        // Enriquecer con nombres de sucursal si es posible
        try {
          final sucList = await getSucursales();
          final mapSuc = {for (var s in sucList) s['id']: s['nombreSucursal']};
          for (final u in normalized) {
            final sid = u['sucursal']?['id'];
            if (sid != null && mapSuc.containsKey(sid)) u['sucursal'] = {'id': sid, 'nombreSucursal': mapSuc[sid]};
          }
        } catch (_) {}

        return normalized;
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al obtener usuarios');
      throw Exception('Error al obtener usuarios: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('getUsuarios error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createUser({
    required String username,
    required String email,
    required String password,
    String tipoUsuario = 'empleado',
    int? sucursalId,
    bool? confirmed,
    bool? blocked,
  }) async {
    final url = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/signup');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'apikey': SupabaseConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
    };
    final userData = {'username': username, 'tipo_usuario': tipoUsuario, 'sucursal_id': sucursalId};
    if (confirmed != null) userData['confirmed'] = confirmed;
    if (blocked != null) userData['blocked'] = blocked;
    final body = jsonEncode({
      'email': email,
      'password': password,
      'data': userData,
    });
    try {
      final resp = await _postWithTimeout(url, headers, body, seconds: 12);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final parsed = jsonDecode(resp.body);
        // try to fetch profile inserted by trigger
        try {
          final userId = parsed['user'] != null ? parsed['user']['id'] : parsed['id'];
          if (userId != null) {
            final profileUrl = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/profiles?id=eq.$userId&select=*');
            final headersGet = await _getHeaders();
            for (int attempt = 0; attempt < 6; attempt++) {
              final pResp = await _getWithTimeout(profileUrl, headersGet, seconds: 6);
              if (pResp.statusCode == 200) {
                final pData = jsonDecode(pResp.body);
                if (pData is List && pData.isNotEmpty) {
                  parsed['profile'] = pData.first;
                  break;
                }
              }
              await Future.delayed(const Duration(milliseconds: 300));
            }
          }
        } catch (_) {}
        return Map<String, dynamic>.from(parsed);
      }
      throw Exception('Error al crear usuario: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('createUser error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUser(String documentId, {String? username, String? email, bool? confirmed, bool? blocked}) async {
    try {
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';
      final id = documentId.toString();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/profiles?id=eq.$id');
      final payload = <String, dynamic>{};
      if (username != null) payload['username'] = username;
      if (email != null) payload['email'] = email;
      if (confirmed != null) payload['confirmed'] = confirmed;
      if (blocked != null) payload['blocked'] = blocked;
      if (payload.isEmpty) throw Exception('No hay campos para actualizar');
      final resp = await _patchWithTimeout(url, headers, jsonEncode(payload), seconds: 10);
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        if (resp.body.trim().isEmpty) return payload;
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
        return payload;
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al actualizar perfil');
      throw Exception('Error al actualizar perfil: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('updateUser error: $e');
      rethrow;
    }
  }

  // Variante que acepta confirmed/blocked directamente (la UI las pasa al actualizar empleados)
  Future<Map<String, dynamic>> updateUserWithFlags2(String documentId, {String? username, String? email, bool? confirmed, bool? blocked}) async {
    try {
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';
      final id = documentId.toString();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/profiles?id=eq.$id');
      final payload = <String, dynamic>{};
      if (username != null) payload['username'] = username;
      if (email != null) payload['email'] = email;
      if (confirmed != null) payload['confirmed'] = confirmed;
      if (blocked != null) payload['blocked'] = blocked;
      if (payload.isEmpty) throw Exception('No hay campos para actualizar');
      final resp = await _patchWithTimeout(url, headers, jsonEncode(payload), seconds: 10);
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        if (resp.body.trim().isEmpty) return payload;
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
        return payload;
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al actualizar perfil');
      throw Exception('Error al actualizar perfil: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('updateUserWithFlags2 error: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String documentId) async {
    try {
      final headers = await _getHeaders();
      final id = documentId.toString();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/profiles?id=eq.$id');
      final resp = await http.delete(url, headers: headers).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200 && resp.statusCode != 204) throw Exception('Error al eliminar perfil: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('deleteUser error: $e');
      rethrow;
    }
  }

  // ------------------ Categorias / Tratamientos ------------------
  Future<List<dynamic>> getCategorias() async {
    try {
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/categoriaTratamiento?select=*');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 10);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        return data.map((e) {
          if (e is Map<String, dynamic>) return {'id': e['id'], 'nombreCategoria': e['nombreCategoria'] ?? e['nombre_categoria'] ?? e['name'], 'estadoCategoria': e['estadoCategoria'] ?? e['estado'] ?? true, 'created_at': e['created_at']};
          return e;
        }).toList();
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al obtener categorias');
      throw Exception('Error obteniendo categorias: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('getCategorias error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getTratamientos({int? categoriaId}) async {
    try {
      final supabaseUrl = categoriaId == null
          ? '${SupabaseConfig.supabaseUrl}/rest/v1/tratamiento?select=*'
          : '${SupabaseConfig.supabaseUrl}/rest/v1/tratamiento?select=*&categoria_id=eq.$categoriaId';
      final url = Uri.parse(supabaseUrl);
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 12);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        return data.map((e) {
          if (e is Map<String, dynamic>) return {'id': e['id'], 'nombreTratamiento': e['nombreTratamiento'] ?? e['nombretratamiento'] ?? e['name'], 'precio': e['precio'], 'estadoTratamiento': e['estadoTratamiento'] ?? e['estadotratamiento'] ?? true, 'categoria_tratamiento': e['categoria_id'] ?? e['categoria_tratamiento'] ?? null, 'created_at': e['created_at']};
          return e;
        }).toList();
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al obtener tratamientos');
      throw Exception('Error al obtener tratamientos: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('getTratamientos error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> crearCategoria(Map<String, dynamic> categoria) async {
    try {
      await _ensureJwtExists();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/categoriaTratamiento');
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';
      final resp = await _postWithTimeout(url, headers, jsonEncode(categoria), seconds: 10);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al crear categoria');
      throw Exception('Error al crear categoria: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('crearCategoria error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> crearTratamiento(Map<String, dynamic> tratamiento) async {
    try {
      await _ensureJwtExists();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/tratamiento');
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';
      final payload = <String, dynamic>{};
      if (tratamiento.containsKey('nombreTratamiento')) payload['nombretratamiento'] = tratamiento['nombreTratamiento'];
      if (tratamiento.containsKey('precio')) payload['precio'] = tratamiento['precio'];
      if (tratamiento.containsKey('estadoTratamiento')) payload['estadotratamiento'] = tratamiento['estadoTratamiento'];
      if (tratamiento.containsKey('categoria_tratamiento')) {
        final cat = tratamiento['categoria_tratamiento'];
        if (cat is Map && cat.containsKey('id')) payload['categoria_id'] = cat['id'];
        else if (cat is int) payload['categoria_id'] = cat;
      }
      final resp = await _postWithTimeout(url, headers, jsonEncode(payload), seconds: 10);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al crear tratamiento');
      throw Exception('Error al crear tratamiento: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('crearTratamiento error: $e');
      rethrow;
    }
  }

  // Crear cliente (método público usado por UI)
  Future<Map<String, dynamic>> crearCliente(Map<String, dynamic> cliente) async {
    try {
      await _ensureJwtExists();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/clientes');
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';
      final resp = await _postWithTimeout(url, headers, jsonEncode(cliente), seconds: 10);
      print('ApiService.crearCliente -> status=${resp.statusCode} body=${resp.body}');
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al crear cliente');
      throw Exception('Error al crear cliente: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('crearCliente error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCategoria(String documentId, Map<String, dynamic> categoria) async {
    try {
      await _ensureJwtExists();
      final id = int.tryParse(documentId.toString())?.toString();
      if (id == null) throw Exception('ID de categoría inválido: $documentId');
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/categoriaTratamiento?id=eq.$id');
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';
      final payload = <String, dynamic>{};
      if (categoria.containsKey('nombreCategoria')) payload['nombreCategoria'] = categoria['nombreCategoria'];
      if (categoria.containsKey('estadoCategoria')) payload['estadoCategoria'] = categoria['estadoCategoria'];
      final resp = await _patchWithTimeout(url, headers, jsonEncode(payload), seconds: 10);
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        if (resp.body.trim().isEmpty) return {'id': id, ...categoria};
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al actualizar categoria');
      throw Exception('Error al actualizar categoria: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('updateCategoria error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTratamiento(String documentId, Map<String, dynamic> tratamiento) async {
    try {
      await _ensureJwtExists();
      final id = int.tryParse(documentId.toString())?.toString();
      if (id == null) throw Exception('ID de tratamiento inválido: $documentId');
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/tratamiento?id=eq.$id');
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';
      final payload = <String, dynamic>{};
      if (tratamiento.containsKey('nombreTratamiento')) payload['nombretratamiento'] = tratamiento['nombreTratamiento'];
      if (tratamiento.containsKey('precio')) payload['precio'] = tratamiento['precio'];
      if (tratamiento.containsKey('estadoTratamiento')) payload['estadotratamiento'] = tratamiento['estadoTratamiento'];
      if (tratamiento.containsKey('categoria_tratamiento')) {
        final cat = tratamiento['categoria_tratamiento'];
        if (cat is Map && cat.containsKey('id')) payload['categoria_id'] = cat['id'];
        else if (cat is int) payload['categoria_id'] = cat;
      }
      final resp = await _patchWithTimeout(url, headers, jsonEncode(payload), seconds: 10);
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        if (resp.body.trim().isEmpty) return {'id': id, ...tratamiento};
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al actualizar tratamiento');
      throw Exception('Error al actualizar tratamiento: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('updateTratamiento error: $e');
      rethrow;
    }
  }

  Future<bool> toggleTratamientoActivo(int id, bool activo) async {
    try {
      await _ensureJwtExists();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/tratamiento?id=eq.$id');
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';
      final resp = await _patchWithTimeout(url, headers, jsonEncode({'estadotratamiento': activo}), seconds: 8);
      if (resp.statusCode == 200 || resp.statusCode == 204) return true;
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al desactivar tratamiento');
      return false;
    } catch (e) {
      print('toggleTratamientoActivo error: $e');
      rethrow;
    }
  }

  // ------------------ Tickets / Clientes / Pagos ------------------
  Future<List<dynamic>> getTickets({int? sucursalId, bool? estadoTicket}) async {
    try {
      final params = <String>[];
      if (sucursalId != null) params.add('sucursal=eq.$sucursalId');
      if (estadoTicket != null) params.add('estadoTicket=eq.${estadoTicket ? 'true' : 'false'}');
      final q = params.isNotEmpty ? '?select=*&${params.join('&')}' : '?select=*';
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/tickets$q');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 12);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        return data;
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al obtener tickets');
      throw Exception('Error al obtener tickets: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('getTickets error: $e');
      rethrow;
    }
  }

  Future<bool> actualizarEstadoTicket(dynamic documentId, bool atendido) async {
    try {
      await _ensureJwtExists();
      final id = documentId.toString();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/tickets?documentId=eq.$id');
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';
      final resp = await _patchWithTimeout(url, headers, jsonEncode({'estado': atendido}), seconds: 8);
      if (resp.statusCode == 200 || resp.statusCode == 204) return true;
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al actualizar ticket');
      return false;
    } catch (e) {
      print('actualizarEstadoTicket error: $e');
      rethrow;
    }
  }

  Future<bool> eliminarTicket(dynamic documentId) async {
    try {
      await _ensureJwtExists();
      final id = documentId.toString();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/tickets?documentId=eq.$id');
      final headers = await _getHeaders();
      final resp = await http.delete(url, headers: headers).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 || resp.statusCode == 204) return true;
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al eliminar ticket');
      return false;
    } catch (e) {
      print('eliminarTicket error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getClientes({int? sucursalId, String? query}) async {
    try {
      final params = <String>[];
      if (sucursalId != null) params.add('sucursal=eq.$sucursalId');
      if (query != null && query.isNotEmpty) params.add('nombreCliente=ilike.*${Uri.encodeComponent(query)}*');
      final q = params.isNotEmpty ? '?select=*&${params.join('&')}' : '?select=*';
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/clientes$q');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 10);
      if (resp.statusCode == 200) return jsonDecode(resp.body) as List<dynamic>;
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al obtener clientes');
      throw Exception('Error al obtener clientes: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('getClientes error: $e');
      rethrow;
    }
  }

  Future<bool> deleteCliente(dynamic documentId) async {
    try {
      await _ensureJwtExists();
      final id = documentId.toString();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/clientes?id=eq.$id');
      final headers = await _getHeaders();
      final resp = await http.delete(url, headers: headers).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 || resp.statusCode == 204) return true;
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al eliminar cliente');
      return false;
    } catch (e) {
      print('deleteCliente error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCliente(String documentId, Map<String, dynamic> cliente) async {
    try {
      await _ensureJwtExists();
      final id = documentId.toString();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/clientes?id=eq.$id');
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';
      final resp = await _patchWithTimeout(url, headers, jsonEncode(cliente), seconds: 10);
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        if (resp.body.trim().isEmpty) return cliente;
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al actualizar cliente');
      throw Exception('Error al actualizar cliente: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('updateCliente error: $e');
      rethrow;
    }
  }

  Future<bool> crearTicket(Map<String, dynamic> ticket) async {
    try {
      await _ensureJwtExists();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/tickets');
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';
      final resp = await _postWithTimeout(url, headers, jsonEncode(ticket), seconds: 12);
      if (resp.statusCode == 200 || resp.statusCode == 201) return true;
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al crear ticket');
      throw Exception('Error al crear ticket: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('crearTicket error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> crearPago(Map<String, dynamic> pago) async {
    try {
      await _ensureJwtExists();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/pagos');
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';
      final resp = await _postWithTimeout(url, headers, jsonEncode(pago), seconds: 12);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al crear pago');
      throw Exception('Error al crear pago: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('crearPago error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getPagos({int? sucursalId}) async {
    try {
      final q = sucursalId != null ? '?select=*&sucursal=eq.$sucursalId' : '?select=*';
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/pagos$q');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 12);
      if (resp.statusCode == 200) return jsonDecode(resp.body) as List<dynamic>;
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al obtener pagos');
      throw Exception('Error al obtener pagos: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('getPagos error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getTicketByDocumentId(String documentId) async {
    try {
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/tickets?documentId=eq.${Uri.encodeComponent(documentId)}&select=*');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 8);
      if (resp.statusCode == 200) {
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        return null;
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al obtener ticket');
      throw Exception('Error al obtener ticket: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('getTicketByDocumentId error: $e');
      rethrow;
    }
  }

  // Reportes (stubs mínimos, la UI espera listas/objetos)
  Future<Map<String, dynamic>> getDailyReport({String? start, String? end, int? sucursalId}) async {
    try {
      // Ideal: crear una RPC en Supabase para reportes. Como stub, intentamos llamar a una vista REST y devolver un mapa.
      final params = <String>[];
      if (start != null) params.add('start=${Uri.encodeComponent(start)}');
      if (end != null) params.add('end=${Uri.encodeComponent(end)}');
      if (sucursalId != null) params.add('sucursal=eq.$sucursalId');
      final q = params.isNotEmpty ? '?${params.join('&')}' : '';
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/reportes_diarios$q');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 12);
      if (resp.statusCode == 200) {
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
        return {};
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al obtener reporte diario');
      return {};
    } catch (e) {
      print('getDailyReport error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getClientReport(int clientId) async {
    try {
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/reportes_clientes?id=eq.$clientId&select=*');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 10);
      if (resp.statusCode == 200) {
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      }
      return null;
    } catch (e) {
      print('getClientReport error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPagosPaginated({String? start, String? end, int? sucursalId, int page = 1, int pageSize = 50}) async {
    try {
      final offset = (page - 1) * pageSize;
      final params = <String>['select=*', 'limit=$pageSize', 'offset=$offset'];
      if (sucursalId != null) params.add('sucursal=eq.$sucursalId');
      if (start != null) params.add('start=${Uri.encodeComponent(start)}');
      if (end != null) params.add('end=${Uri.encodeComponent(end)}');
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/pagos?${params.join('&')}');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 12);
      if (resp.statusCode == 200) {
        final items = jsonDecode(resp.body) as List<dynamic>;
        // Como no tenemos meta real, devolver meta simple
        return {'items': items, 'meta': {'pagination': {'page': page, 'pageCount': items.length >= pageSize ? page + 1 : page}}};
      }
      return {'items': [], 'meta': {}};
    } catch (e) {
      print('getPagosPaginated error: $e');
      rethrow;
    }
  }

  // Debug helpers
  Future<Map<String, dynamic>> debugGetSucursalesDetailed() async {
    final result = <String, dynamic>{'supabase_rest': null};
    try {
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/sucursales?select=*');
      final headers = await _getHeaders();
      final response = await _getWithTimeout(url, headers, seconds: 10);
      result['supabase_rest'] = {'status': response.statusCode, 'body': response.body, 'headers': headers};
    } catch (e) {
      result['supabase_rest'] = {'error': e.toString()};
    }
    return result;
  }

  Future<Map<String, dynamic>> debugAuthCheck() async {
    try {
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/user');
      final headers = await _getHeaders();
      final response = await _getWithTimeout(url, headers, seconds: 8);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'ok': true, 'data': data};
      } else {
        return {'ok': false, 'status': response.statusCode, 'body': response.body};
      }
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<List<dynamic>> getDebtReport({int? sucursalId}) async {
    try {
      final q = sucursalId != null ? '?select=*&sucursal=eq.$sucursalId' : '?select=*';
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/reportes_deuda$q');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 12);
      if (resp.statusCode == 200) return jsonDecode(resp.body) as List<dynamic>;
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al obtener reporte de deudas');
      return [];
    } catch (e) {
      print('getDebtReport error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> callFunction(String functionName, Map<String, dynamic> body, {int seconds = 12}) async {
    try {
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/$functionName');
      final headers = await _getHeaders();
      // Asegurar Content-Type
      headers['Content-Type'] = 'application/json';
      final resp = await _postWithTimeout(url, headers, jsonEncode(body), seconds: seconds);
      print('ApiService.callFunction $functionName -> status=${resp.statusCode} body=${resp.body}');
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (resp.body.trim().isEmpty) return {};
        final parsed = jsonDecode(resp.body);
        if (parsed is Map<String, dynamic>) return parsed;
        return {'result': parsed};
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado llamando function $functionName');
      throw Exception('Error al llamar function $functionName: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('callFunction error for $functionName: $e');
      rethrow;
    }
  }

  /// Wrapper: Crear usuario usando la Supabase Function 'crear-usuario' que definiste
  Future<Map<String, dynamic>> crearUsuarioFunction({
    required String email,
    required String password,
    required String nombre,
    required int sucursalId,
    required String tipoUsuario,
  }) async {
    try {
      // Intentar obtener JWT del session o prefs y añadirlo en el body como token_admin para compatibilidad
      String jwt = '';
      try {
        final session = Supabase.instance.client.auth.currentSession;
        jwt = session?.accessToken ?? '';
      } catch (_) {}
      if (jwt.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        jwt = prefs.getString('jwt') ?? '';
      }

      final body = {
        'email': email,
        'password': password,
        'nombre': nombre,
        'sucursal_id': sucursalId,
        'tipo_usuario': tipoUsuario,
        'token_admin': jwt,
      };
      final res = await callFunction('crear-usuario', body);
      return res;
    } catch (e) {
      print('crearUsuarioFunction error: $e');
      rethrow;
    }
  }

  /// Wrapper: Eliminar usuario usando la Supabase Function 'eliminar-usuario'
  Future<Map<String, dynamic>> eliminarUsuarioFunction(String idUsuario) async {
    try {
      String jwt = '';
      try {
        final session = Supabase.instance.client.auth.currentSession;
        jwt = session?.accessToken ?? '';
      } catch (_) {}
      if (jwt.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        jwt = prefs.getString('jwt') ?? '';
      }
      final body = {
        'id_a_borrar': idUsuario,
        'token_admin': jwt,
      };
      final res = await callFunction('eliminar-usuario', body);
      return res;
    } catch (e) {
      print('eliminarUsuarioFunction error: $e');
      rethrow;
    }
  }

  /// Wrapper: Editar password usando la Supabase Function 'editar-password'
  Future<Map<String, dynamic>> editarPasswordFunction(String idUsuario, String nuevaPassword) async {
    try {
      String jwt = '';
      try {
        final session = Supabase.instance.client.auth.currentSession;
        jwt = session?.accessToken ?? '';
      } catch (_) {}
      if (jwt.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        jwt = prefs.getString('jwt') ?? '';
      }
      final body = {
        'id_usuario': idUsuario,
        'nueva_password': nuevaPassword,
        'token_admin': jwt,
      };
      final res = await callFunction('editar-password', body);
      return res;
    } catch (e) {
      print('editarPasswordFunction error: $e');
      rethrow;
    }
  }
}
