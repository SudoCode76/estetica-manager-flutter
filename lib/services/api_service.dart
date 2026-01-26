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

      if (jwt.isEmpty) {
        // Intentar refrescar la sesión usando el cliente de Supabase (si hay refresh token disponible)
        try {
          print('_ensureJwtExists: no jwt found, attempting Supabase.client.auth.refreshSession()');
          final resp = await Supabase.instance.client.auth.refreshSession();
          final newSession = resp.session;
          if (newSession != null) {
            final newAccess = newSession.accessToken;
            final newRefresh = newSession.refreshToken;
            if (newAccess.isNotEmpty) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('jwt', newAccess);
              if (newRefresh != null && newRefresh.isNotEmpty) {
                await prefs.setString('refreshToken', newRefresh);
              }
              print('_ensureJwtExists: session refreshed and saved to prefs (jwt len=${newAccess.length})');
              return;
            }
          }
        } catch (e) {
          print('_ensureJwtExists: refreshSession failed: $e');
        }

        // Como último recurso, intentar refrescar admin token si existe refresh token admin
        final refreshedAdmin = await _tryRefreshAdminToken();
        if (refreshedAdmin) return;

        throw Exception('No hay token JWT: inicia sesión para realizar esta operación.');
      }
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
      // Usar el SDK de supabase_flutter
      final data = await Supabase.instance.client
          .from('sucursales')
          .select('*');

      return (data as List<dynamic>).map((e) {
        if (e is Map<String, dynamic>) {
          return {
            'id': e['id'],
            'nombreSucursal': e['nombreSucursal'] ?? e['nombre_sucursal'] ?? e['name']
          };
        }
        return e;
      }).toList();
    } catch (e) {
      print('getSucursales error: $e');
      rethrow;
    }
  }

    Future<List<dynamic>> getUsuarios({int? sucursalId, String? query}) async {
    try {
      // Usar el SDK de supabase_flutter para consultar la tabla profiles
      var queryBuilder = Supabase.instance.client
          .from('profiles')
          .select('*, email');

      if (sucursalId != null) {
        queryBuilder = queryBuilder.eq('sucursal_id', sucursalId);
      }

      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('username', '%$query%');
      }

      print('getUsuarios: fetching profiles for sucursal=$sucursalId');
      final data = await queryBuilder;

      final normalized = (data as List<dynamic>).map((e) {
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
    } catch (e) {
      print('getUsuarios error: $e');
      rethrow;
    }
    }

    /// Devuelve un solo usuario (perfil) por id, incluyendo email cuando esté disponible.
    Future<Map<String, dynamic>?> getUsuarioById(String id) async {
    try {
      final headers = await _getHeaders();
      final endpoint = '${SupabaseConfig.supabaseUrl}/rest/v1/profiles?id=eq.${Uri.encodeComponent(id)}&select=*,email';
      final url = Uri.parse(endpoint);
      final resp = await _getWithTimeout(url, headers, seconds: 10);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List && data.isNotEmpty) {
          final e = data.first as Map<String, dynamic>;
          return {
            'id': e['id'],
            'documentId': e['id']?.toString(),
            'username': e['username'] ?? e['user_metadata']?['username'] ?? '',
            'email': e['email'] ?? e['user_metadata']?['email'] ?? '',
            'tipoUsuario': e['tipo_usuario'] ?? e['user_metadata']?['tipo_usuario'] ?? 'empleado',
            'sucursal': e['sucursal_id'] != null ? {'id': e['sucursal_id'], 'nombreSucursal': null} : null,
            'confirmed': e['confirmed'] ?? true,
            'blocked': e['blocked'] ?? false,
            'createdAt': e['created_at'] ?? e['createdAt'],
          };
        }
        return null;
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al obtener usuario');
      throw Exception('Error al obtener usuario: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('getUsuarioById error: $e');
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

  Future<Map<String, dynamic>> updateUser(String documentId,
      {String? username, String? email, String? tipoUsuario, int? sucursalId, bool? confirmed, bool? blocked}) async {
    try {
      final payload = <String, dynamic>{};
      if (username != null) payload['username'] = username;
      // NO actualizar email aquí - ese campo no existe en profiles, solo viene de auth.users
      if (tipoUsuario != null) payload['tipo_usuario'] = tipoUsuario;
      if (sucursalId != null) payload['sucursal_id'] = sucursalId;

      if (payload.isEmpty) {
        throw Exception('No hay campos válidos para actualizar en profiles');
      }

      // Usar el SDK de supabase_flutter
      final data = await Supabase.instance.client
          .from('profiles')
          .update(payload)
          .eq('id', documentId)
          .select()
          .single();

      print('updateUser: updated profile for id=$documentId');
      return Map<String, dynamic>.from(data);
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
      // Usar el SDK de supabase_flutter en lugar de REST manual
      final data = await Supabase.instance.client.from('categoriaTratamiento').select('*');
      return (data as List<dynamic>).map((e) {
        if (e is Map<String, dynamic>) return {
          'id': e['id'],
          'nombreCategoria': e['nombreCategoria'] ?? e['nombre_categoria'] ?? e['name'],
          'estadoCategoria': e['estadoCategoria'] ?? e['estado'] ?? true,
          'created_at': e['created_at']
        };
        return e;
      }).toList();
    } catch (e) {
      print('getCategorias error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getTratamientos({int? categoriaId}) async {
    try {
      var qb = Supabase.instance.client.from('tratamiento').select('*');
      if (categoriaId != null) qb = qb.eq('categoria_id', categoriaId);
      final data = await qb;
      return (data as List<dynamic>).map((e) {
        if (e is Map<String, dynamic>) return {
          'id': e['id'],
          'nombreTratamiento': e['nombreTratamiento'] ?? e['nombretratamiento'] ?? e['name'],
          'precio': e['precio'],
          'estadoTratamiento': e['estadoTratamiento'] ?? e['estadotratamiento'] ?? true,
          'categoria_tratamiento': e['categoria_id'] ?? e['categoria_tratamiento'] ?? null,
          'created_at': e['created_at']
        };
        return e;
      }).toList();
    } catch (e) {
      print('getTratamientos error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> crearCategoria(Map<String, dynamic> categoria) async {
    try {
      await _ensureJwtExists();
      final payload = <String, dynamic>{};
      if (categoria.containsKey('nombreCategoria')) payload['nombreCategoria'] = categoria['nombreCategoria'];
      if (categoria.containsKey('estadoCategoria')) payload['estadoCategoria'] = categoria['estadoCategoria'];

      final res = await Supabase.instance.client.from('categoriaTratamiento').insert(payload).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('crearCategoria error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> crearTratamiento(Map<String, dynamic> tratamiento) async {
    try {
      await _ensureJwtExists();
      final payload = <String, dynamic>{};
      if (tratamiento.containsKey('nombreTratamiento')) payload['nombretratamiento'] = tratamiento['nombreTratamiento'];
      if (tratamiento.containsKey('precio')) payload['precio'] = tratamiento['precio'];
      if (tratamiento.containsKey('estadoTratamiento')) payload['estadotratamiento'] = tratamiento['estadoTratamiento'];
      if (tratamiento.containsKey('categoria_tratamiento')) {
        final cat = tratamiento['categoria_tratamiento'];
        if (cat is Map && cat.containsKey('id')) payload['categoria_id'] = cat['id'];
        else if (cat is int) payload['categoria_id'] = cat;
      }

      final res = await Supabase.instance.client.from('tratamiento').insert(payload).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('crearTratamiento error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCategoria(String documentId, Map<String, dynamic> categoria) async {
    try {
      await _ensureJwtExists();
      final idInt = int.tryParse(documentId.toString());
      if (idInt == null) throw Exception('ID de categoría inválido: $documentId');
      final payload = <String, dynamic>{};
      if (categoria.containsKey('nombreCategoria')) payload['nombreCategoria'] = categoria['nombreCategoria'];
      if (categoria.containsKey('estadoCategoria')) payload['estadoCategoria'] = categoria['estadoCategoria'];

      final res = await Supabase.instance.client.from('categoriaTratamiento').update(payload).eq('id', idInt).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('updateCategoria error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTratamiento(String documentId, Map<String, dynamic> tratamiento) async {
    try {
      await _ensureJwtExists();
      final idInt = int.tryParse(documentId.toString());
      if (idInt == null) throw Exception('ID de tratamiento inválido: $documentId');
      final payload = <String, dynamic>{};
      if (tratamiento.containsKey('nombreTratamiento')) payload['nombretratamiento'] = tratamiento['nombreTratamiento'];
      if (tratamiento.containsKey('precio')) payload['precio'] = tratamiento['precio'];
      if (tratamiento.containsKey('estadoTratamiento')) payload['estadotratamiento'] = tratamiento['estadoTratamiento'];
      if (tratamiento.containsKey('categoria_tratamiento')) {
        final cat = tratamiento['categoria_tratamiento'];
        if (cat is Map && cat.containsKey('id')) payload['categoria_id'] = cat['id'];
        else if (cat is int) payload['categoria_id'] = cat;
      }

      final res = await Supabase.instance.client.from('tratamiento').update(payload).eq('id', idInt).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('updateTratamiento error: $e');
      rethrow;
    }
  }

  /// Crear cliente usando REST /rest/v1/clientes (Prefer: return=representation)
  Future<Map<String, dynamic>> crearCliente(Map<String, dynamic> cliente) async {
    try {
      await _ensureJwtExists();

      // Mapear keys de UI a las columnas de la tabla 'cliente'
      final payload = <String, dynamic>{};
      payload['nombrecliente'] = cliente['nombreCliente'] ?? cliente['nombrecliente'] ?? '';
      payload['apellidocliente'] = cliente['apellidoCliente'] ?? cliente['apellidocliente'] ?? '';
      // Guardar telefono como string (la tabla acepta varchar)
      payload['telefono'] = cliente['telefono']?.toString() ?? '';
      payload['estadocliente'] = cliente['estadoCliente'] ?? cliente['estadocliente'] ?? true;
      payload['sucursal_id'] = cliente['sucursal_id'] ?? cliente['sucursal'] ?? cliente['sucursalId'];

      final res = await Supabase.instance.client.from('cliente').insert(payload).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('crearCliente error: $e');
      rethrow;
    }
  }

  Future<bool> deleteCategoria(dynamic documentId) async {
    try {
      await _ensureJwtExists();
      final idInt = int.tryParse(documentId.toString());
      if (idInt == null) throw Exception('ID de categoría inválido: $documentId');
      await Supabase.instance.client.from('categoriaTratamiento').delete().eq('id', idInt);
      return true;
    } catch (e) {
      print('deleteCategoria error: $e');
      rethrow;
    }
  }

  Future<bool> deleteTratamiento(dynamic documentId) async {
    try {
      await _ensureJwtExists();
      final idInt = int.tryParse(documentId.toString());
      if (idInt == null) throw Exception('ID de tratamiento inválido: $documentId');
      await Supabase.instance.client.from('tratamiento').delete().eq('id', idInt);
      return true;
    } catch (e) {
      print('deleteTratamiento error: $e');
      rethrow;
    }
  }

  Future<bool> toggleTratamientoActivo(int id, bool activo) async {
    try {
      await _ensureJwtExists();
      await Supabase.instance.client.from('tratamiento').update({'estadotratamiento': activo}).eq('id', id);
      return true;
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
      // Usar SDK de Supabase
      var qb = Supabase.instance.client.from('cliente').select('*');
      if (sucursalId != null) qb = qb.eq('sucursal_id', sucursalId);
      if (query != null && query.isNotEmpty) {
        // Buscar por nombre, apellido o teléfono usando OR + ilike
        final pattern = '%$query%';
        qb = qb.or('nombrecliente.ilike.$pattern,apellidocliente.ilike.$pattern,telefono.ilike.$pattern');
      }

      final data = await qb;
      return (data as List<dynamic>).map((e) {
        if (e is Map<String, dynamic>) return {
          'id': e['id'],
          'nombreCliente': e['nombrecliente'] ?? e['nombreCliente'] ?? '',
          'apellidoCliente': e['apellidocliente'] ?? e['apellidoCliente'] ?? '',
          'telefono': e['telefono'],
          'estadoCliente': e['estadocliente'] ?? e['estadoCliente'] ?? true,
          'sucursal_id': e['sucursal_id'] ?? e['sucursal'] ?? null,
          'created_at': e['created_at'],
        };
        return e;
      }).toList();
    } catch (e) {
      print('getClientes error: $e');
      rethrow;
    }
  }

  Future<bool> deleteCliente(dynamic documentId) async {
    try {
      await _ensureJwtExists();
      final idStr = documentId.toString();
      final idInt = int.tryParse(idStr);
      if (idInt == null) throw Exception('ID de cliente inválido: $documentId');
      await Supabase.instance.client.from('cliente').delete().eq('id', idInt);
      return true;
    } catch (e) {
      print('deleteCliente error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCliente(String documentId, Map<String, dynamic> cliente) async {
    try {
      await _ensureJwtExists();
      final idStr = documentId.toString();
      final idInt = int.tryParse(idStr);
      if (idInt == null) throw Exception('ID de cliente inválido: $documentId');

      final payload = <String, dynamic>{};
      if (cliente.containsKey('nombreCliente') || cliente.containsKey('nombrecliente')) payload['nombrecliente'] = cliente['nombreCliente'] ?? cliente['nombrecliente'];
      if (cliente.containsKey('apellidoCliente') || cliente.containsKey('apellidocliente')) payload['apellidocliente'] = cliente['apellidoCliente'] ?? cliente['apellidocliente'];
      if (cliente.containsKey('telefono')) payload['telefono'] = cliente['telefono']?.toString();
      if (cliente.containsKey('estadoCliente') || cliente.containsKey('estadocliente')) payload['estadocliente'] = cliente['estadoCliente'] ?? cliente['estadocliente'];
      if (cliente.containsKey('sucursal_id') || cliente.containsKey('sucursal')) payload['sucursal_id'] = cliente['sucursal_id'] ?? cliente['sucursal'];

      if (payload.isEmpty) throw Exception('No hay campos para actualizar');

      final res = await Supabase.instance.client.from('cliente').update(payload).eq('id', idInt).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('updateCliente error: $e');
      rethrow;
    }
  }

  // ------------------ Reporte de Deuda ------------------
  Future<List<dynamic>> getReporteDeuda({int? sucursalId}) async {
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

  /// Reportes: obtiene reporte diario/mensual desde el endpoint REST 'reportes_ventas'
  Future<Map<String, dynamic>> getDailyReport({String? start, String? end, int? sucursalId}) async {
    try {
      final params = <String>[];
      if (start != null) params.add('start=eq.${Uri.encodeComponent(start)}');
      if (end != null) params.add('end=eq.${Uri.encodeComponent(end)}');
      if (sucursalId != null) params.add('sucursal=eq.$sucursalId');
      final q = params.isNotEmpty ? '?${params.join('&')}' : '';
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/reportes_ventas$q');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 12);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List && data.isNotEmpty) return Map<String, dynamic>.from(data.first);
        if (data is Map<String, dynamic>) return data;
        return {};
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al obtener reporte de ventas');
      throw Exception('Error al obtener reporte de ventas: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('getDailyReport error: $e');
      rethrow;
    }
  }

  /// Wrapper en inglés para compatibilidad: llama a getReporteDeuda
  Future<List<dynamic>> getDebtReport({int? sucursalId}) async {
    return await getReporteDeuda(sucursalId: sucursalId);
  }

  /// Obtener detalle de cliente (wrapper defensivo)
  Future<Map<String, dynamic>> getClientReport(int clientId) async {
    try {
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/reportes_cliente?id=eq.$clientId');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 10);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List && data.isNotEmpty) return Map<String, dynamic>.from(data.first);
        if (data is Map<String, dynamic>) return data;
        return {};
      }
      return {};
    } catch (e) {
      print('getClientReport error: $e');
      rethrow;
    }
  }

  /// Pagos paginados (wrapper defensivo). Retorna map: { items: List, meta: { pagination: { page, pageCount, total } } }
  Future<Map<String, dynamic>> getPagosPaginated({String? start, String? end, int? sucursalId, int page = 1, int pageSize = 30}) async {
    try {
      final params = <String>[];
      if (start != null) params.add('start=eq.${Uri.encodeComponent(start)}');
      if (end != null) params.add('end=eq.${Uri.encodeComponent(end)}');
      if (sucursalId != null) params.add('sucursal=eq.$sucursalId');
      params.add('limit=$pageSize');
      params.add('offset=${(page - 1) * pageSize}');
      final q = params.isNotEmpty ? '?${params.join('&')}' : '';
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/pagos$q');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 12);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        // sin metadata real, devolvemos una meta mínima
        return {
          'items': data,
          'meta': {
            'pagination': {
              'page': page,
              'pageCount': 1,
              'total': data.length,
            }
          }
        };
      }
      throw Exception('Error al obtener pagos: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('getPagosPaginated error: $e');
      rethrow;
    }
  }

  // ------------------ Funciones RPC / Edge Functions ------------------
  Future<Map<String, dynamic>> callFunction(String functionName, Map<String, dynamic> body, {int seconds = 12, bool preferFunctionsToken = false}) async {
    final url = Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/$functionName');
    try {
      // Preparar headers: usar Anon Key en Authorization (como en Postman) y Content-Type
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
      };

      // Si el caller pidió explícitamente preferFunctionsToken y hay uno configurado, usarlo.
      if (preferFunctionsToken) {
        final runtimeToken = await _getRuntimeFunctionsAuthToken();
        if (runtimeToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $runtimeToken';
          print('callFunction: using functionsAuthToken (runtime) for Authorization header (len=${runtimeToken.length})');
        } else {
          print('callFunction: preferFunctionsToken requested but no functionsAuthToken found at compile-time or runtime');
        }
      }

      // Log básico (no imprimir tokens completos)
      try {
        if (body.containsKey('token_admin')) {
          final t = body['token_admin']?.toString() ?? '';
          final mask = t.isEmpty ? '<empty>' : '${t.substring(0, 8)}... (len=${t.length})';
          print('callFunction: body.token_admin=$mask');
        }
      } catch (_) {}

      final resp = await _postWithTimeout(url, headers, jsonEncode(body), seconds: seconds);
      print('ApiService.callFunction $functionName -> status=${resp.statusCode} body=${resp.body}');

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (resp.body.trim().isEmpty) return {};
        final parsed = jsonDecode(resp.body);
        if (parsed is Map<String, dynamic>) return parsed;
        return {'result': parsed};
      }

      // Errores comunes
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        final bodyText = resp.body;
        if (bodyText.contains('Invalid JWT')) {
          // Intentar reintentar con functionsAuthToken en header si está disponible y aún no se usó
          if (SupabaseConfig.functionsAuthToken.isNotEmpty && !(preferFunctionsToken)) {
            try {
              print('callFunction: Invalid JWT detected. Retrying with functionsAuthToken in Authorization header...');
              final altHeaders = Map<String, String>.from(headers);
              altHeaders['Authorization'] = 'Bearer ${SupabaseConfig.functionsAuthToken}';
              final retryResp = await _postWithTimeout(url, altHeaders, jsonEncode(body), seconds: seconds);
              print('callFunction retry with functionsAuthToken -> status=${retryResp.statusCode} body=${retryResp.body}');
              if (retryResp.statusCode == 200 || retryResp.statusCode == 201) {
                if (retryResp.body.trim().isEmpty) return {};
                final parsed = jsonDecode(retryResp.body);
                if (parsed is Map<String, dynamic>) return parsed;
                return {'result': parsed};
              }
            } catch (e) {
              print('callFunction retry with functionsAuthToken failed: $e');
            }
          }

          // Intentar refrescar admin token si tenemos refresh token guardado y reintentar una vez (mantener compatibilidad con body token_admin)
          print('callFunction: detected Invalid JWT for function $functionName. Attempting to refresh admin token...');
          final refreshed = await _tryRefreshAdminToken();
          if (refreshed) {
            final prefs = await SharedPreferences.getInstance();
            final newAdmin = prefs.getString('adminToken') ?? '';
            if (newAdmin.isNotEmpty) {
              try {
                final retryBody = Map<String, dynamic>.from(body);
                retryBody['token_admin'] = newAdmin;
                final retryResp = await _postWithTimeout(url, headers, jsonEncode(retryBody), seconds: seconds);
                print('callFunction retry after refresh -> status=${retryResp.statusCode} body=${retryResp.body}');
                if (retryResp.statusCode == 200 || retryResp.statusCode == 201) {
                  if (retryResp.body.trim().isEmpty) return {};
                  final parsed = jsonDecode(retryResp.body);
                  if (parsed is Map<String, dynamic>) return parsed;
                  return {'result': parsed};
                }
              } catch (e) {
                print('callFunction retry after refresh failed: $e');
              }
            }
          }
          throw Exception('No autorizado llamando function $functionName (status: ${resp.statusCode}, body: ${resp.body}). La Edge Function devolvió Invalid JWT. Asegúrate de enviar token_admin correcto en el body o configura SUPABASE_FUNCTIONS_AUTH_TOKEN.');
        }
        throw Exception('No autorizado llamando function $functionName (status: ${resp.statusCode}, body: ${resp.body}).');
      }

      throw Exception('Error llamando function $functionName: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      // Distinción para errores de red (web CORS, fetch fail)
      final msg = e.toString();
      if (msg.contains('Failed to fetch') || msg.contains('Network request failed') || msg.contains('XMLHttpRequest') || msg.contains('CORS')) {
        final more = 'Error llamando function "${functionName}": "Failed to fetch" — probable error de CORS/preflight cuando la app corre en web. Asegúrate de que la Edge Function devuelva las cabeceras CORS y responda a OPTIONS.';
        print('callFunction error for $functionName (likely CORS): $e');
        throw Exception(more);
      }
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
      // OBTENER TOKEN FRESCO del SDK justo antes de la llamada
      final session = Supabase.instance.client.auth.currentSession;

      // Validación de seguridad por si la sesión murió
      if (session == null || session.isExpired) {
        throw Exception('La sesión ha caducado. Vuelve a iniciar sesión');
      }

      final String tokenFrescoAdmin = session.accessToken;

      final body = {
        'email': email,
        'password': password,
        'nombre': nombre,
        'sucursal_id': sucursalId,
        'tipo_usuario': tipoUsuario,
        'token_admin': tokenFrescoAdmin, // Token fresco del SDK
      };

      try {
        final mask = tokenFrescoAdmin.isEmpty ? '<empty>' : '${tokenFrescoAdmin.substring(0, 8)}... (len=${tokenFrescoAdmin.length})';
        print('crearUsuarioFunction: calling crear-usuario with FRESH token_admin=$mask and email=$email');
      } catch (_) {}

      // Usar el SDK de supabase_flutter en vez de http manual
      final response = await Supabase.instance.client.functions.invoke(
        'crear-usuario',
        body: body,
      );

      print('crearUsuarioFunction: status=${response.status} data=${response.data}');

      if (response.status == 200 || response.status == 201) {
        if (response.data == null) return {};
        if (response.data is Map<String, dynamic>) return response.data as Map<String, dynamic>;
        return {'result': response.data};
      }

      throw Exception('Error creando usuario: status=${response.status} data=${response.data}');
    } catch (e) {
      print('crearUsuarioFunction error: $e');
      rethrow;
    }
  }

  /// Wrapper: Eliminar usuario usando la Supabase Function 'eliminar-usuario'
  Future<Map<String, dynamic>> eliminarUsuarioFunction(String idUsuario) async {
    try {
      // OBTENER TOKEN FRESCO del SDK justo antes de la llamada
      final session = Supabase.instance.client.auth.currentSession;

      // Validación de seguridad por si la sesión murió
      if (session == null || session.isExpired) {
        throw Exception('La sesión ha caducado. Vuelve a iniciar sesión');
      }

      final String tokenFrescoAdmin = session.accessToken;

      final body = {
        'id_a_borrar': idUsuario,
        'token_admin': tokenFrescoAdmin, // Token fresco del SDK
      };

      // Log masking token_admin for diagnostics (do not print full token)
      try {
        final mask = tokenFrescoAdmin.isEmpty ? '<empty>' : '${tokenFrescoAdmin.substring(0, 8)}... (len=${tokenFrescoAdmin.length})';
        print('eliminarUsuarioFunction: calling eliminar-usuario with FRESH token_admin=$mask and id=$idUsuario');
      } catch (_) {}

      // Usar el SDK de supabase_flutter en vez de http manual
      final response = await Supabase.instance.client.functions.invoke(
        'eliminar-usuario',
        body: body,
      );

      print('eliminarUsuarioFunction: status=${response.status} data=${response.data}');

      if (response.status == 200 || response.status == 201) {
        if (response.data == null) return {};
        if (response.data is Map<String, dynamic>) return response.data as Map<String, dynamic>;
        return {'result': response.data};
      }

      throw Exception('Error eliminando usuario: status=${response.status} data=${response.data}');
    } catch (e) {
      print('eliminarUsuarioFunction error: $e');
      rethrow;
    }
  }

  /// Wrapper: Editar password usando la Supabase Function 'editar-password'
  Future<Map<String, dynamic>> editarPasswordFunction(String idUsuario, String nuevaPassword) async {
    try {
      // OBTENER TOKEN FRESCO del SDK justo antes de la llamada
      final session = Supabase.instance.client.auth.currentSession;

      // Validación de seguridad por si la sesión murió
      if (session == null || session.isExpired) {
        throw Exception('La sesión ha caducado. Vuelve a iniciar sesión');
      }

      final String tokenFrescoAdmin = session.accessToken;

      final body = {
        'id_usuario': idUsuario,
        'nueva_password': nuevaPassword,
        'token_admin': tokenFrescoAdmin, // Token fresco del SDK
      };

      try {
        final mask = tokenFrescoAdmin.isEmpty ? '<empty>' : '${tokenFrescoAdmin.substring(0, 8)}... (len=${tokenFrescoAdmin.length})';
        print('editarPasswordFunction: calling editar-password with FRESH token_admin=$mask and id=$idUsuario');
      } catch (_) {}

      // Usar el SDK de supabase_flutter en vez de http manual
      final response = await Supabase.instance.client.functions.invoke(
        'editar-password',
        body: body,
      );

      print('editarPasswordFunction: status=${response.status} data=${response.data}');

      if (response.status == 200 || response.status == 201) {
        if (response.data == null) return {};
        if (response.data is Map<String, dynamic>) return response.data as Map<String, dynamic>;
        return {'result': response.data};
      }

      throw Exception('Error editando password: status=${response.status} data=${response.data}');
    } catch (e) {
      print('editarPasswordFunction error: $e');
      rethrow;
    }
  }

  /// Guarda el admin token en SharedPreferences para reintentos en Edge Functions.
  Future<void> saveAdminToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('adminToken', token);
      // también actualizamos jwt por compatibilidad
      if (token.isNotEmpty) await prefs.setString('jwt', token);
      print('saveAdminToken: adminToken saved (len=${token.length})');
    } catch (e) {
      print('saveAdminToken error: $e');
    }
  }


  /// Si en el futuro necesitas elegir dinámicamente un token admin, puedes
  /// usar `_getRuntimeFunctionsAuthToken()` (para el legacy functions token)
  /// o `saveAdminToken()` + `_tryRefreshAdminToken()` para manejar un admin token en prefs.
  // Future<String> _chooseTokenAdmin() async {
  //   try {
  //     if (SupabaseConfig.functionsAuthToken.isNotEmpty) return SupabaseConfig.functionsAuthToken;
  //     final prefs = await SharedPreferences.getInstance();
  //     final storedAdmin = prefs.getString('adminToken') ?? '';
  //     if (storedAdmin.isNotEmpty) return storedAdmin;
  //     // fallback a jwt en prefs o sesión
  //     try {
  //       final session = Supabase.instance.client.auth.currentSession;
  //       final jwt = session?.accessToken;
  //       if (jwt != null && jwt.isNotEmpty) return jwt;
  //     } catch (_) {}
  //     final jwtPrefs = prefs.getString('jwt') ?? '';
  //     return jwtPrefs;
  //   } catch (e) {
  //     print('_chooseTokenAdmin error: $e');
  //     return '';
  //   }
  // }

  /// Intenta refrescar el admin token usando el refresh token guardado en SharedPreferences.
  /// Retorna true si se obtuvo y guardó un adminToken nuevo.
  Future<bool> _tryRefreshAdminToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refresh = prefs.getString('adminRefreshToken') ?? prefs.getString('refreshToken') ?? '';
      if (refresh.isEmpty) {
        print('_tryRefreshAdminToken: no refresh token found in prefs');
        return false;
      }

      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/token?grant_type=refresh_token');
      final headers = <String, String>{
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        'Content-Type': 'application/x-www-form-urlencoded',
      };
      final body = 'refresh_token=${Uri.encodeComponent(refresh)}';
      final resp = await _postWithTimeout(url, headers, body, seconds: 8);
      print('_tryRefreshAdminToken -> status=${resp.statusCode} body=${resp.body}');
      if (resp.statusCode == 200) {
        final parsed = jsonDecode(resp.body) as Map<String, dynamic>;
        final newAccess = parsed['access_token']?.toString() ?? '';
        final newRefresh = parsed['refresh_token']?.toString() ?? '';
        if (newAccess.isNotEmpty) {
          await prefs.setString('adminToken', newAccess);
          await prefs.setString('jwt', newAccess);
          if (newRefresh.isNotEmpty) await prefs.setString('adminRefreshToken', newRefresh);
          print('_tryRefreshAdminToken: refreshed adminToken saved (len=${newAccess.length})');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('_tryRefreshAdminToken error: $e');
      return false;
    }
  }

  /// Lee el token de funciones óptimo: primero la constante compile-time, luego SharedPreferences.
  Future<String> _getRuntimeFunctionsAuthToken() async {
    try {
      if (SupabaseConfig.functionsAuthToken.isNotEmpty) return SupabaseConfig.functionsAuthToken;
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString('functionsAuthToken') ?? '';
      return t;
    } catch (e) {
      print('_getRuntimeFunctionsAuthToken error: $e');
      return '';
    }
  }

  /// Guarda temporalmente el token de funciones en SharedPreferences (solo para desarrollo/depuración).
  /// No recomendado para producción.
  Future<void> saveFunctionsAuthToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('functionsAuthToken', token);
      print('saveFunctionsAuthToken: token saved (len=${token.length})');
    } catch (e) {
      print('saveFunctionsAuthToken error: $e');
    }
  }

  Future<Map<String, dynamic>> debugAuthCheck() async {
    try {
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/user');
      final headers = await _getHeaders();
      final resp = await _getWithTimeout(url, headers, seconds: 8);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return {'ok': true, 'data': data};
      }
      return {'ok': false, 'status': resp.statusCode, 'body': resp.body};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

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

  // ------------------ NUEVA ARQUITECTURA DE TICKETS/SESIONES/PAGOS ------------------

  /// Helper para obtener inicio y fin del día
  (String, String) _getRangoDia(DateTime fecha) {
    final start = DateTime(fecha.year, fecha.month, fecha.day).toIso8601String();
    final end = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59).toIso8601String();
    return (start, end);
  }

  /// 1. Obtener agenda diaria (vista de sesiones programadas)
  Future<List<dynamic>> obtenerAgenda(DateTime fecha, {int? sucursalId, String? estadoSesion}) async {
    try {
      // Si no hay sucursal seleccionada, retornar lista vacía
      if (sucursalId == null) {
        print('obtenerAgenda: sucursalId is null, returning empty list');
        return [];
      }

      final (inicioDia, finDia) = _getRangoDia(fecha);

      // Construir query con filtros
      var query = Supabase.instance.client
          .from('vista_agenda_diaria')
          .select()
          .eq('sucursal_id', sucursalId)
          .gte('fecha_hora_inicio', inicioDia)
          .lte('fecha_hora_inicio', finDia);

      // Filtrar por estado si se especifica
      if (estadoSesion != null) {
        query = query.eq('estado_sesion', estadoSesion);
      }

      // Aplicar orden y ejecutar
      final response = await query.order('fecha_hora_inicio', ascending: true);

      print('obtenerAgenda: fetched ${(response as List).length} sesiones for sucursal $sucursalId, estado=$estadoSesion');
      return response as List<dynamic>;
    } catch (e) {
      print('obtenerAgenda error: $e');
      rethrow;
    }
  }

  /// 1B. Obtener tickets del día actual (para pantalla de tickets)
  Future<List<dynamic>> getTicketsDelDia({
    required DateTime fecha,
    required int sucursalId,
  }) async {
    try {
      final (inicioDia, finDia) = _getRangoDia(fecha);

      final response = await Supabase.instance.client
          .from('ticket')
          .select('''
            *, 
            cliente:cliente_id(nombrecliente, apellidocliente),
            sesiones:sesion(
              id,
              numero_sesion,
              fecha_hora_inicio,
              estado_sesion,
              tratamiento:tratamiento_id(id, nombretratamiento, precio)
            )
          ''')
          .eq('sucursal_id', sucursalId)
          .gte('created_at', inicioDia)
          .lte('created_at', finDia)
          .order('created_at', ascending: false);

      return response as List<dynamic>;
    } catch (e) {
      print('getTicketsDelDia error: $e');
      rethrow;
    }
  }

  /// 1C. Obtener TODOS los tickets de una sucursal (sin filtro de fecha)
  Future<List<dynamic>> getAllTickets({
    required int sucursalId,
  }) async {
    try {
      final response = await Supabase.instance.client
          .from('ticket')
          .select('''
            *, 
            cliente:cliente_id(nombrecliente, apellidocliente, telefono),
            sesiones:sesion(
              id,
              numero_sesion,
              fecha_hora_inicio,
              estado_sesion,
              tratamiento:tratamiento_id(id, nombretratamiento, precio)
            )
          ''')
          .eq('sucursal_id', sucursalId)
          .order('created_at', ascending: false);

      print('getAllTickets: fetched ${(response as List).length} tickets for sucursal $sucursalId');
      return response as List<dynamic>;
    } catch (e) {
      print('getAllTickets error: $e');
      rethrow;
    }
  }

  /// 2. Crear venta completa (usa RPC para transacción atómica)
  Future<void> registrarVenta({
    required int clienteId,
    required int sucursalId, // Ahora obligatorio
    required double totalVenta,
    required double pagoInicial,
    required List<Map<String, dynamic>> itemsCarrito, // "Carrito"
  }) async {
    try {
      // 1. Obtener ID del empleado actual
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      // 2. Transformar el Carrito en Sesiones Individuales
      // Ahora usamos el cronograma_sesiones que trae las fechas elegidas por el usuario
      List<Map<String, dynamic>> sesionesParaEnviar = [];

      for (var item in itemsCarrito) {
        int idTratamiento = item['id'];
        double precioTratamiento = (item['precio'] is num)
            ? (item['precio'] as num).toDouble()
            : 0.0;

        // Obtenemos la lista de fechas que eligió el usuario en la UI
        List<dynamic> cronogramaRaw = item['cronograma_sesiones'] ?? [];

        if (cronogramaRaw.isEmpty) {
          throw Exception('El tratamiento ${item['nombreTratamiento'] ?? item['id']} no tiene fechas programadas');
        }

        // Convertir a DateTime si es necesario
        List<DateTime> fechas = cronogramaRaw.map((f) {
          if (f is DateTime) return f;
          if (f is String) return DateTime.parse(f);
          throw Exception('Formato de fecha inválido');
        }).toList();

        int cantidadSesiones = fechas.length;

        // Iteramos por CADA FECHA elegida
        for (int i = 0; i < fechas.length; i++) {
          sesionesParaEnviar.add({
            'tratamiento_id': idTratamiento,
            'numero_sesion': i + 1, // 1, 2, 3...
            'precio_sesion': precioTratamiento / cantidadSesiones,
            'fecha_inicio': fechas[i].toIso8601String() // ← La fecha exacta de esa sesión
          });
        }
      }

      print('registrarVenta: Creating ticket with ${sesionesParaEnviar.length} sesiones');
      print('registrarVenta: Sesiones: ${sesionesParaEnviar.map((s) => "Sesión ${s['numero_sesion']}: ${s['fecha_inicio']}").join(", ")}');

      // 3. Llamada Atómica al Backend
      final response = await Supabase.instance.client.rpc(
        'crear_venta_completa',
        params: {
          'p_cliente_id': clienteId,
          'p_empleado_id': userId,
          'p_sucursal_id': sucursalId,
          'p_monto_total': totalVenta,
          'p_monto_pagado_inicial': pagoInicial,
          'p_sesiones': sesionesParaEnviar // Supabase serializa esto automágicamente
        }
      );

      // 4. Validar respuesta
      if (response != null && response is Map) {
        if (response['success'] == false) {
          throw Exception('Error del backend: ${response['message'] ?? response['error']}');
        }
      }

      print('registrarVenta: Venta creada exitosamente');
    } catch (e) {
      print('registrarVenta error: $e');
      rethrow;
    }
  }

  /// 3. Ver tickets pendientes de pago
  Future<List<dynamic>> obtenerTicketsPendientes({int? sucursalId}) async {
    try {
      var query = Supabase.instance.client
          .from('ticket')
          .select('*, cliente:cliente_id(*)')
          .or('estado_pago.eq.pendiente,estado_pago.eq.parcial');

      // Aplicar filtro de sucursal si existe
      if (sucursalId != null) {
        query = query.eq('sucursal_id', sucursalId);
      }

      // Aplicar orden y ejecutar (sin reasignar a query)
      final response = await query.order('created_at', ascending: true);
      return response as List<dynamic>;
    } catch (e) {
      print('obtenerTicketsPendientes error: $e');
      rethrow;
    }
  }

  /// 4. Obtener detalle completo de un ticket (con sesiones y pagos)
  Future<Map<String, dynamic>?> obtenerTicketDetalle(String ticketId) async {
    try {
      final response = await Supabase.instance.client
          .from('ticket')
          .select('''
            *,
            cliente:cliente_id(*),
            empleado:empleado_id(*),
            sesiones:sesion(*, tratamiento:tratamiento_id(*)),
            pagos:pago(*)
          ''')
          .eq('id', ticketId)
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('obtenerTicketDetalle error: $e');
      rethrow;
    }
  }

  /// 5. Registrar abono (pago parcial o total) - El trigger actualiza automáticamente el ticket
  Future<Map<String, dynamic>> registrarAbono({
    required String ticketId,
    required double montoAbono,
    String metodoPago = 'efectivo',
  }) async {
    try {
      await _ensureJwtExists();

      final response = await Supabase.instance.client.from('pago').insert({
        'ticket_id': ticketId,
        'monto': montoAbono,
        'fecha_pago': DateTime.now().toIso8601String(),
        'metodo_pago': metodoPago,
      }).select().single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('registrarAbono error: $e');
      rethrow;
    }
  }

  /// 6. Marcar sesión como atendida/realizada
  Future<bool> marcarSesionAtendida(String sesionId) async {
    try {
      await Supabase.instance.client
          .from('sesion')
          .update({
            'estado_sesion': 'realizada',
            //'fecha_atencion': DateTime.now().toIso8601String(),
          })
          .eq('id', sesionId);

      return true;
    } catch (e) {
      print('marcarSesionAtendida error: $e');
      rethrow;
    }
  }

  /// 7. Reprogramar sesión (cambiar fecha)
  Future<bool> reprogramarSesion(String sesionId, DateTime nuevaFecha) async {
    try {
      await _ensureJwtExists();

      await Supabase.instance.client
          .from('sesion')
          .update({'fecha_hora_inicio': nuevaFecha.toIso8601String()})
          .eq('id', sesionId);

      return true;
    } catch (e) {
      print('reprogramarSesion error: $e');
      rethrow;
    }
  }

  /// 8. Obtener historial de pagos de un ticket
  Future<List<dynamic>> obtenerPagosTicket(String ticketId) async {
    try {
      final response = await Supabase.instance.client
          .from('pago')
          .select('*')
          .eq('ticket_id', ticketId)
          .order('fecha_pago', ascending: false);

      return response as List<dynamic>;
    } catch (e) {
      print('obtenerPagosTicket error: $e');
      rethrow;
    }
  }

  /// 9. Obtener sesiones de un ticket
  Future<List<dynamic>> obtenerSesionesTicket(String ticketId) async {
    try {
      final response = await Supabase.instance.client
          .from('sesion')
          .select('*, tratamiento:tratamiento_id(*)')
          .eq('ticket_id', ticketId)
          .order('numero_sesion', ascending: true);

      return response as List<dynamic>;
    } catch (e) {
      print('obtenerSesionesTicket error: $e');
      rethrow;
    }
  }

  /// 10. Método de compatibilidad: crear ticket (wrapper sobre registrarVenta)
  Future<bool> crearTicket(Map<String, dynamic> ticket) async {
    try {
      // Extraer datos del formato antiguo y mapear al nuevo
      final clienteId = ticket['cliente'] is int ? ticket['cliente'] : null;
      if (clienteId == null) throw Exception('Cliente no especificado');

      final tratamientos = ticket['tratamientos'];
      if (tratamientos == null || (tratamientos is! List) || tratamientos.isEmpty) {
        throw Exception('Debe seleccionar al menos un tratamiento');
      }

      // Obtener información completa de tratamientos
      List<Map<String, dynamic>> itemsCarrito = [];
      for (var tratId in tratamientos) {
        final trat = await Supabase.instance.client
            .from('tratamiento')
            .select('*')
            .eq('id', tratId)
            .single();
        itemsCarrito.add(Map<String, dynamic>.from(trat));
      }

      final totalVenta = itemsCarrito.fold<double>(
        0,
        (sum, t) => sum + ((t['precio'] is num) ? (t['precio'] as num).toDouble() : 0.0),
      );

      final pagoInicial = ticket['cuota'] is num ? (ticket['cuota'] as num).toDouble() : 0.0;
      final sucursalId = ticket['sucursal'] is int ? ticket['sucursal'] : null;

      await registrarVenta(
        clienteId: clienteId,
        totalVenta: totalVenta,
        pagoInicial: pagoInicial,
        itemsCarrito: itemsCarrito,
        sucursalId: sucursalId,
      );

      return true;
    } catch (e) {
      print('crearTicket (compat) error: $e');
      return false;
    }
  }

  // ------------------ FIN NUEVA ARQUITECTURA ------------------
}
