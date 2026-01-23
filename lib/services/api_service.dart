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
      if (session != null && session.accessToken != null) {
        jwt = session.accessToken!;
      }
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
    if (hasJwt) headers['Authorization'] = 'Bearer $jwt';

    // Log minimal para debugging: indicar si Authorization está presente (no imprimir token)
    print('_getHeaders: using apikey=${SupabaseConfig.supabaseAnonKey != null ? "yes" : "no"}, authorization=${hasJwt ? "present" : "absent"}');
    return headers;
  }

  /// Lanza si no hay JWT disponible para llamadas autenticadas.
  Future<void> _ensureJwtExists() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      String jwt = '';
      if (session != null && session.accessToken != null) jwt = session.accessToken!;
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
        final data = jsonDecode(response.body);

        // Obtener información completa del usuario con su sucursal
        if (data['user'] != null && data['user']['id'] != null) {
          try {
            final userId = data['user']['id'];
            final userUrl = Uri.parse('$_baseUrl/users/$userId?populate=*');
            final headers = {'Content-Type': 'application/json'};
            if (data['jwt'] != null) {
              headers['Authorization'] = 'Bearer ${data['jwt']}';
            }

            print('Obteniendo datos completos del usuario: $userUrl');
            final userResponse = await _getWithTimeout(userUrl, headers, seconds: 10);

            if (userResponse.statusCode == 200) {
              final decodedUser = jsonDecode(userResponse.body);
              print('Datos completos del usuario (raw): $decodedUser');

              // Normalizar la respuesta para que tenga la misma forma que _normalizeItems
              Map<String, dynamic> normalizedUser;
              try {
                if (decodedUser is Map && decodedUser.containsKey('data')) {
                  final list = _normalizeItems([decodedUser['data']]);
                  normalizedUser = Map<String, dynamic>.from(list.first as Map<String, dynamic>);
                } else if (decodedUser is Map && decodedUser.containsKey('attributes')) {
                  final list = _normalizeItems([decodedUser]);
                  normalizedUser = Map<String, dynamic>.from(list.first as Map<String, dynamic>);
                } else if (decodedUser is Map) {
                  // Ya es un map plano: intentar convertir directamente
                  normalizedUser = Map<String, dynamic>.from(decodedUser);
                } else {
                  // Fallback: usar el objeto tal cual dentro de un map
                  normalizedUser = {'data': decodedUser};
                }
              } catch (e) {
                print('Error normalizando user data: $e');
                normalizedUser = Map<String, dynamic>.from(decodedUser as Map<String, dynamic>);
              }

              print('Datos completos del usuario (normalized): $normalizedUser');
              data['user'] = normalizedUser; // Reemplazar con datos completos normalizados
             } else {
               print('Error al obtener datos del usuario: ${userResponse.statusCode}');
               print('Response: ${userResponse.body}');
             }
          } catch (e) {
            print('Error obteniendo datos completos del usuario: $e');
            // Continuar con datos básicos si falla
          }
        }

        return data;
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

          // El backend puede devolver { data: {...} o directamente el objeto de datos
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
    try {
      final supabaseUrl = categoriaId == null
          ? '${SupabaseConfig.supabaseUrl}/rest/v1/tratamiento?select=*'
          : '${SupabaseConfig.supabaseUrl}/rest/v1/tratamiento?select=*&categoria_id=eq.$categoriaId';
      final url = Uri.parse(supabaseUrl);
      final headers = await _getHeaders();

      print('ApiService.getTratamientos: llamando Supabase REST -> $url');
      final response = await _getWithTimeout(url, headers, seconds: 12);
      print('ApiService.getTratamientos: status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final normalized = data.map((e) {
          if (e is Map<String, dynamic>) {
            return {
              'id': e['id'],
              'nombreTratamiento': e['nombreTratamiento'] ?? e['nombretratamiento'] ?? e['nombre_tratamiento'] ?? e['name'],
              'precio': e['precio'],
              'estadoTratamiento': e['estadoTratamiento'] ?? e['estadotratamiento'] ?? true,
              'categoria_tratamiento': e['categoria_tratamiento'] ?? e['categoria_id'] ?? e['categoria'] ?? null,
              'created_at': e['created_at'],
            };
          }
          return e;
        }).toList();
        return normalized;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('No autorizado al obtener tratamientos (401/403). Verifica JWT y RLS.');
      } else {
        throw Exception('Error al obtener tratamientos: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('getTratamientos error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getCategorias() async {
    try {
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/categoriaTratamiento?select=*');
      final headers = await _getHeaders();
      final response = await _getWithTimeout(url, headers, seconds: 10);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        // Normalizar: {id, nombreCategoria, estadoCategoria}
        final normalized = data.map((e) {
          if (e is Map<String, dynamic>) {
            return {
              'id': e['id'],
              'nombreCategoria': e['nombreCategoria'] ?? e['nombre_categoria'] ?? e['name'],
              'estadoCategoria': e['estadoCategoria'] ?? e['estado'] ?? true,
              'created_at': e['created_at'],
            };
          }
          return e;
        }).toList();
        return normalized;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('No autorizado: verifica que el usuario esté autenticado y que envíes el JWT (status=${response.statusCode})');
      } else {
        throw Exception('Error obteniendo categorias: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('ApiService.getCategorias error: $e');
      rethrow;
    }
  }

  // Crear categoria de tratamiento
  Future<Map<String, dynamic>> crearCategoria(Map<String, dynamic> categoria) async {
    try {
      await _ensureJwtExists();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/categoriaTratamiento');
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';
      final body = jsonEncode(categoria);
      final resp = await _postWithTimeout(url, headers, body, seconds: 10);
      print('crearCategoria Supabase status=${resp.statusCode} body=${resp.body}');
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw Exception('No autorizado al crear categoría (401/403): verifica credenciales y RLS');
      }
      throw Exception('Error al crear categoria: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('crearCategoria error: $e');
      rethrow;
    }
  }

  // Crear tratamiento
  Future<Map<String, dynamic>> crearTratamiento(Map<String, dynamic> tratamiento) async {
    try {
      await _ensureJwtExists();
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/tratamiento');
      final headers = await _getHeaders();
      headers['Prefer'] = 'return=representation';

      // Mapear campos de la app a los nombres de columna de Supabase
      final payload = <String, dynamic>{};
      if (tratamiento.containsKey('nombreTratamiento')) payload['nombretratamiento'] = tratamiento['nombreTratamiento'];
      if (tratamiento.containsKey('precio')) payload['precio'] = tratamiento['precio'];
      if (tratamiento.containsKey('estadoTratamiento')) payload['estadotratamiento'] = tratamiento['estadoTratamiento'];
      if (tratamiento.containsKey('categoria_tratamiento')) {
        final cat = tratamiento['categoria_tratamiento'];
        if (cat is Map && cat.containsKey('id')) payload['categoria_id'] = cat['id'];
        else if (cat is int) payload['categoria_id'] = cat;
        else if (cat is String) {
          final parsed = int.tryParse(cat);
          if (parsed != null) payload['categoria_id'] = parsed;
        }
      }

      final resp = await _postWithTimeout(url, headers, jsonEncode(payload), seconds: 10);
      print('crearTratamiento Supabase status=${resp.statusCode} body=${resp.body}');
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw Exception('No autorizado al crear tratamiento (401/403): verifica credenciales y RLS');
      }
      throw Exception('Error al crear tratamiento: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('crearTratamiento error: $e');
      rethrow;
    }
  }

  // Actualizar categoria de tratamiento
  Future<Map<String, dynamic>> updateCategoria(String documentId, Map<String, dynamic> categoria) async {
     try {
       await _ensureJwtExists();
       // documentId expected to be numeric or numeric string
       final id = int.tryParse(documentId.toString())?.toString();
       if (id == null) throw Exception('ID de categoría inválido: $documentId');

       final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/categoriaTratamiento?id=eq.$id');
       final headers = await _getHeaders();
       headers['Prefer'] = 'return=representation';
       final payload = <String, dynamic>{};
       if (categoria.containsKey('nombreCategoria')) payload['nombreCategoria'] = categoria['nombreCategoria'];
       if (categoria.containsKey('estadoCategoria')) payload['estadoCategoria'] = categoria['estadoCategoria'];

       final resp = await _patchWithTimeout(url, headers, jsonEncode(payload), seconds: 10);
       print('updateCategoria Supabase status=${resp.statusCode} body=${resp.body}');
       if (resp.statusCode == 200 || resp.statusCode == 204) {
         if (resp.body.trim().isEmpty) {
           final result = Map<String, dynamic>.from(categoria);
           result['id'] = id;
           return result;
         }
         final parsed = jsonDecode(resp.body);
         if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
         if (parsed is Map) return Map<String, dynamic>.from(parsed);
       } else if (resp.statusCode == 401 || resp.statusCode == 403) {
         throw Exception('No autorizado al actualizar categoría (401/403): verifica credenciales y RLS');
       }
       throw Exception('Error al actualizar categoria: ${resp.statusCode} ${resp.body}');
     } catch (e) {
       print('updateCategoria error: $e');
       rethrow;
     }
   }

   // Actualizar tratamiento
   Future<Map<String, dynamic>> updateTratamiento(String documentId, Map<String, dynamic> tratamiento) async {
     try {
       await _ensureJwtExists();
       final id = int.tryParse(documentId.toString())?.toString();
       if (id == null) throw Exception('ID de tratamiento inválido: $documentId');

       final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/tratamiento?id=eq.$id');
       final headers = await _getHeaders();
       headers['Prefer'] = 'return=representation';

       // Mapear campos al schema de Supabase
       final payload = <String, dynamic>{};
       if (tratamiento.containsKey('nombreTratamiento')) payload['nombretratamiento'] = tratamiento['nombreTratamiento'];
       if (tratamiento.containsKey('precio')) payload['precio'] = tratamiento['precio'];
       if (tratamiento.containsKey('estadoTratamiento')) payload['estadotratamiento'] = tratamiento['estadoTratamiento'];
       if (tratamiento.containsKey('categoria_tratamiento')) {
         final cat = tratamiento['categoria_tratamiento'];
         if (cat is Map && cat.containsKey('id')) payload['categoria_id'] = cat['id'];
         else if (cat is int) payload['categoria_id'] = cat;
         else if (cat is String) {
           final parsed = int.tryParse(cat);
           if (parsed != null) payload['categoria_id'] = parsed;
         }
       }

       final resp = await _patchWithTimeout(url, headers, jsonEncode(payload), seconds: 10);
       print('updateTratamiento Supabase status=${resp.statusCode} body=${resp.body}');
       if (resp.statusCode == 200 || resp.statusCode == 204) {
         if (resp.body.trim().isEmpty) {
           final result = Map<String, dynamic>.from(tratamiento);
           result['id'] = id;
           return result;
         }
         final parsed = jsonDecode(resp.body);
         if (parsed is List && parsed.isNotEmpty) return Map<String, dynamic>.from(parsed.first);
         if (parsed is Map) return Map<String, dynamic>.from(parsed);
       } else if (resp.statusCode == 401 || resp.statusCode == 403) {
         throw Exception('No autorizado al actualizar tratamiento (401/403): verifica credenciales y RLS');
       }
       throw Exception('Error al actualizar tratamiento: ${resp.statusCode} ${resp.body}');
     } catch (e) {
       print('updateTratamiento error: $e');
       rethrow;
     }
   }

   /// Desactivar/activar tratamiento (solo toggle del campo estadotratamiento)
   Future<bool> toggleTratamientoActivo(int id, bool activo) async {
     try {
       await _ensureJwtExists();
       final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/tratamiento?id=eq.$id');
       final headers = await _getHeaders();
       headers['Prefer'] = 'return=representation';
       final body = jsonEncode({'estadotratamiento': activo});
       final resp = await _patchWithTimeout(url, headers, body, seconds: 8);
       print('toggleTratamientoActivo Supabase status=${resp.statusCode} body=${resp.body}');
       if (resp.statusCode == 200 || resp.statusCode == 204) return true;
       if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('No autorizado al desactivar tratamiento');
       return false;
     } catch (e) {
       print('toggleTratamientoActivo error: $e');
       rethrow;
     }
   }

  // Obtener todos los usuarios
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
        final decoded = jsonDecode(response.body);
        // Puede devolver una lista directamente o { data: [...] }
        if (decoded is List) {
          // Normalizar cualquier item que venga con attributes/data
          try {
            return _normalizeItems(decoded);
          } catch (_) {
            return List<dynamic>.from(decoded);
          }
        }
        if (decoded is Map && decoded.containsKey('data')) {
          final raw = List<dynamic>.from(decoded['data'] ?? []);
          return _normalizeItems(raw);
        }

        // Fallback: si es un Map plano, devolverlo como lista con un solo elemento
        if (decoded is Map) {
          try {
            final normalizedList = _normalizeItems([decoded]);
            return normalizedList;
          } catch (_) {
            return [decoded];
          }
        }

        // Si no entendemos el formato, devolver lista vacía
        return [];
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
  /// Si el ticket contiene un pago inicial (cuota > saldoPendiente), crea automáticamente el registro de pago
  Future<bool> crearTicket(Map<String, dynamic> ticket) async {
    final url = Uri.parse('$_baseUrl/tickets');
    final headers = await _getHeaders();
    final response = await _postWithTimeout(url, headers, jsonEncode({'data': ticket}));
    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        // Verificar si hay un pago inicial (cuota > saldoPendiente)
        final cuota = ticket['cuota'];
        final saldoPendiente = ticket['saldoPendiente'];
        if (cuota != null && saldoPendiente != null) {
          final cuotaNum = double.tryParse(cuota.toString()) ?? 0;
          final saldoNum = double.tryParse(saldoPendiente.toString()) ?? 0;
          final pagoInicial = cuotaNum - saldoNum;

          if (pagoInicial > 0) {
            // Extraer el ID del ticket creado
            final data = jsonDecode(response.body);
            final createdTicket = _normalizeItems([data['data']]).first as Map<String, dynamic>;
            final ticketId = createdTicket['id'];

            if (ticketId != null) {
              // Crear registro de pago
              print('crearTicket: creando pago inicial de $pagoInicial para ticket $ticketId');
              try {
                await crearPago({
                  'montoPagado': pagoInicial,
                  'fechaPago': DateTime.now().toIso8601String(),
                  'ticket': ticketId,
                });
                print('crearTicket: pago inicial creado exitosamente');
              } catch (e) {
                print('crearTicket: Error al crear pago inicial: $e');
                // No fallar la creación del ticket si falla el pago
              }
            }
          }
        }
      } catch (e) {
        print('crearTicket: Error al procesar pago inicial: $e');
        // No fallar la creación del ticket si hay error en el pago
      }
      return true;
    } else {
      print('Error al crear ticket: ${response.body}');
      return false;
    }
  }

  // Obtener todas las sucursales
  Future<List<dynamic>> getSucursales() async {
    try {
      final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/sucursales?select=*');
      final headers = await _getHeaders();
      print('ApiService.getSucursales: llamando -> $url (Authorization present: ${headers.containsKey('Authorization')})');
      final response = await _getWithTimeout(url, headers, seconds: 10);
      print('ApiService.getSucursales: status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final normalized = data.map((e) {
          if (e is Map<String, dynamic>) {
            return {
              'id': e['id'],
              'nombreSucursal': e['nombreSucursal'] ?? e['nombre'] ?? e['nombre_sucursal']
            };
          }
          return e;
        }).toList();
        return normalized;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('No autorizado al obtener sucursales (401/403): verifica JWT y RLS');
      } else {
        throw Exception('Error al obtener sucursales: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('getSucursales error: $e');
      rethrow;
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

  // Eliminar ticket
  Future<bool> eliminarTicket(String documentId) async {
    try {
      final url = Uri.parse('$_baseUrl/tickets/$documentId');
      final headers = await _getHeaders();
      final response = await http.delete(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('Ticket eliminado exitosamente: $documentId');
        return true;
      } else {
        print('Error al eliminar ticket: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception al eliminar ticket: $e');
      return false;
    }
  }

    // Obtener pagos
    Future<List<dynamic>> getPagos({int? sucursalId}) async {
    final headers = await _getHeaders();
    // Pedimos la relación ticket->sucursal para poder filtrar localmente
    final params = ['populate[ticket][populate]=sucursal', 'pagination[pageSize]=1000'];
    final endpoint = '$_baseUrl/pagos?${params.join('&')}';
    try {
      final response = await _getWithTimeout(Uri.parse(endpoint), headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = List<dynamic>.from(data['data'] ?? []);
        final normalized = _normalizeItems(raw);
        if (sucursalId != null) {
          // Filtrar localmente por la sucursal del ticket
          return normalized.where((p) {
            final pt = p['ticket'];
            if (pt == null) return false;
            if (pt is Map) {
              final suc = pt['sucursal'];
              if (suc == null) return false;
              final sid = suc['id'] ?? suc['documentId'];
              return sid == sucursalId || (sid is String && sid == sucursalId.toString());
            }
            return false;
          }).toList();
        }
        return normalized;
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
      // Si pago.ticket es un documentId (string), intentar resolver a id numérico antes de crear
      final payload = Map<String, dynamic>.from(pago);
      if (payload.containsKey('ticket') && payload['ticket'] is String) {
        final resolved = await getTicketByDocumentId(payload['ticket']);
        if (resolved != null) {
          payload['ticket'] = resolved['id'];
        }
      }
      final body = jsonEncode({'data': payload});
      print('crearPago: POST $url body=$body');
      final response = await _postWithTimeout(url, headers, body, seconds: 10);
      print('crearPago: status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data')) {
          final created = _normalizeItems([data['data']]).first as Map<String, dynamic>;
          // Si enviamos 'ticket' en el payload pero la respuesta no contiene la relación, intentar update para enlazar
          if (payload.containsKey('ticket') && (created['ticket'] == null || created['ticket'] == 0)) {
            try {
              // Preferir el id numérico para la ruta PUT; si no existe, intentar documentId -> resolver numeric id
              String? recordId = created['id']?.toString();
              if (recordId == null && created['documentId'] != null) {
                // intentar resolver por documentId
                final maybe = await getPagoByDocumentId(created['documentId'].toString());
                if (maybe != null) recordId = maybe['id']?.toString();
              }
              if (recordId != null) {
                final ticketVal = payload['ticket'];
                // Intentar varios formatos para enlazar la relación
                final candidates = <Map<String, dynamic>>[];
                candidates.add({'ticket': ticketVal});
                // si ticketVal es numérico, candidates.add({'ticket': {'id': ticketVal}});
                // si teníamos documentId original en pago, intentar también con ese string
                if (pago.containsKey('ticket') && pago['ticket'] is String) candidates.add({'ticket': pago['ticket']});

                for (final upd in candidates) {
                  try {
                    await updatePago(recordId.toString(), upd);
                    // Si no lanza, asumimos éxito y refetch
                    final refreshed = await getPagos();
                    return refreshed.firstWhere((p) => p['documentId'] == recordId || p['id'].toString() == recordId, orElse: () => created) as Map<String, dynamic>;
                  } catch (e) {
                    print('crearPago: intento de enlace con payload $upd falló: $e');
                    // seguir al siguiente
                  }
                }
              }
            } catch (e) {
              print('crearPago: intento de enlazar ticket falló: $e');
            }
          }
          return created;
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

  // Actualizar pago (por si hay que enlazar relaciones después)
  Future<Map<String, dynamic>> updatePago(String documentId, Map<String, dynamic> pago) async {
    final url = Uri.parse('$_baseUrl/pagos/$documentId');
    final headers = await _getHeaders();
    try {
      final response = await _putWithTimeout(url, headers, jsonEncode({'data': pago}), seconds: 10);
      print('updatePago: status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        if (response.body.trim().isEmpty) {
          final result = Map<String, dynamic>.from(pago);
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
          return Map<String, dynamic>.from(pago);
        } catch (e) {
          print('updatePago: error parsing response body: ${response.body} error: $e');
          final fallback = Map<String, dynamic>.from(pago);
          fallback['documentId'] = documentId;
          return fallback;
        }
      } else {
        print('Error updatePago: ${response.statusCode} ${response.body}');
        throw Exception('Error al actualizar pago: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Exception en updatePago: $e');
      throw Exception('Error al actualizar pago: $e');
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

  // Obtener todos los pagos
  Future<List<dynamic>> getTodosLosPagos() async {
    final headers = await _getHeaders();
    final endpoint = '$_baseUrl/pagos';
    try {
      final response = await _getWithTimeout(Uri.parse(endpoint), headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['data'] ?? [];
        return _normalizeItems(raw);
      } else {
        print('getTodosLosPagos failed ${response.statusCode}: ${response.body}');
        throw Exception('Error al obtener pagos');
      }
    } catch (e) {
      print('Exception getTodosLosPagos: $e');
      throw Exception('Error al obtener pagos: $e');
    }
  }

  // Crear pago en bloque
  Future<List<dynamic>> crearPagosEnBloque(List<Map<String, dynamic>> pagos) async {
    final url = Uri.parse('$_baseUrl/pagos/bulk');
    final headers = await _getHeaders();
    try {
      final response = await _postWithTimeout(url, headers, jsonEncode({'data': pagos}), seconds: 10);
      print('crearPagosEnBloque: status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data')) {
          return _normalizeItems(data['data']);
        }
        // fallback
        if (data is List) return _normalizeItems(data);
        throw Exception('Respuesta inesperada al crear pagos en bloque');
      } else {
        // Intentar parsear body para dar más contexto
        String msg = 'Error al crear pagos en bloque: ${response.statusCode}';
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
      print('Exception crearPagosEnBloque: $e');
      rethrow;
    }
  }

  // Obtener ticket por documentId
  Future<Map<String, dynamic>?> getTicketByDocumentId(String documentId) async {
    final headers = await _getHeaders();
    final endpoint = '$_baseUrl/tickets?filters[documentId][\$eq]=$documentId&pagination[pageSize]=1';
    try {
      final response = await _getWithTimeout(Uri.parse(endpoint), headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = _normalizeItems(data['data'] ?? []);
        if (items.isNotEmpty) return items.first as Map<String, dynamic>;
        return null;
      } else {
        print('getTicketByDocumentId failed ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception getTicketByDocumentId: $e');
      return null;
    }
  }

  /// Obtiene pagos (transacciones) paginados. Retorna un Map con keys: 'items' (List) y 'meta' (map de pagination)
  Future<Map<String, dynamic>> getPagosPaginated({String? start, String? end, int? sucursalId, int page = 1, int pageSize = 30}) async {
    final headers = await _getHeaders();
    final baseUrl = '$_baseUrl/pagos';

    final List<String> params = [
      'populate[ticket][populate]=cliente,sucursal',
      'populate[metodo]=true',
      'pagination[page]=$page',
      'pagination[pageSize]=$pageSize',
    ];

    if (sucursalId != null) {
      params.add('filters[ticket][sucursal][id][\$eq]=$sucursalId');
    }

    if (start != null && end != null) {
      // Filtrar por createdAt entre start y end (formato YYYY-MM-DD)
      params.add('filters[createdAt][\$gte]=${start}T00:00:00.000Z');
      params.add('filters[createdAt][\$lte]=${end}T23:59:59.999Z');
    }

    final endpoint = '$baseUrl?${params.join('&')}';
    print('ApiService.getPagosPaginated: calling $endpoint');

    try {
      final response = await _getWithTimeout(Uri.parse(endpoint), headers, seconds: 12);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['data'] ?? [];
        final items = _normalizeItems(List<dynamic>.from(raw));
        final meta = data['meta'] ?? {};
        return {'items': items, 'meta': meta};
      } else {
        print('getPagosPaginated failed ${response.statusCode}: ${response.body}');
        throw Exception('Error obteniendo pagos: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception getPagosPaginated: $e');
      throw Exception('Error al obtener pagos: $e');
    }
  }

  // ------------------------------
  // Funciones de Reportes (cliente-side)
  // ------------------------------

  /// Obtiene un reporte diario/por rango calculando sobre pagos y tickets.
  /// Parámetros opcionales: start y end en formato YYYY-MM-DD, sucursalId para filtrar.
  /// NOTA: Filtra por createdAt (fecha de creación) en lugar de fechaPago/fecha
  Future<Map<String, dynamic>> getDailyReport({String? start, String? end, int? sucursalId}) async {
    final headers = await _getHeaders();

    // Construir filtros para pagos usando createdAt (fecha de creación del pago)
    final List<String> pagoParams = ['populate[ticket][populate]=sucursal','populate[ticket][populate]=cliente','pagination[pageSize]=1000'];
    if (start != null && end != null) {
      // Construir DateTimes en UTC desde las fechas YYYY-MM-DD
      try {
        final partsStart = start.split('-');
        final partsEnd = end.split('-');
        final startDt = DateTime.utc(int.parse(partsStart[0]), int.parse(partsStart[1]), int.parse(partsStart[2]));
        final endDt = DateTime.utc(int.parse(partsEnd[0]), int.parse(partsEnd[1]), int.parse(partsEnd[2]), 23, 59, 59, 999);
        final isoStart = startDt.toIso8601String();
        final isoEnd = endDt.toIso8601String();
        pagoParams.add('filters[createdAt][\$gte]=$isoStart');
        pagoParams.add('filters[createdAt][\$lte]=$isoEnd');
      } catch (e) {
        // fallback simple ISO without padding
        final isoStart = '${start}T00:00:00.000Z';
        final isoEnd = '${end}T23:59:59.999Z';
        pagoParams.add('filters[createdAt][\$gte]=$isoStart');
        pagoParams.add('filters[createdAt][\$lte]=$isoEnd');
      }
    }

    final pagosEndpoint = '$_baseUrl/pagos?${pagoParams.join('&')}';
    print('ApiService.getDailyReport: calling pagos $pagosEndpoint');

    // Construir filtros para tickets (TODOS los tickets de la sucursal para calcular deuda y contar tickets del día)
    final List<String> ticketParams = [
      'populate[cliente]=true',
      'populate[sucursal]=true',
      'pagination[pageSize]=1000',
    ];
    if (sucursalId != null) {
      ticketParams.add('filters[sucursal][id][\$eq]=$sucursalId');
    }
    final ticketsEndpoint = '$_baseUrl/tickets?${ticketParams.join('&')}';
    print('ApiService.getDailyReport: calling tickets $ticketsEndpoint');

    try {
      final pagosResp = await _getWithTimeout(Uri.parse(pagosEndpoint), headers, seconds: 12);
      final ticketsResp = await _getWithTimeout(Uri.parse(ticketsEndpoint), headers, seconds: 12);

      if (pagosResp.statusCode != 200) {
        throw Exception('Error al obtener pagos: ${pagosResp.statusCode}');
      }
      if (ticketsResp.statusCode != 200) {
        throw Exception('Error al obtener tickets: ${ticketsResp.statusCode}');
      }

      final pagosData = jsonDecode(pagosResp.body);
      final ticketsData = jsonDecode(ticketsResp.body);

      final pagosRaw = List<dynamic>.from(pagosData['data'] ?? []);
      final ticketsRaw = List<dynamic>.from(ticketsData['data'] ?? []);

      final pagosListAll = _normalizeItems(pagosRaw);
      final ticketsList = _normalizeItems(ticketsRaw);

      final int pagosAllCount = pagosListAll.length;
      final int ticketsCount = ticketsList.length;
      final int pagosUnlinkedCountAll = pagosListAll.where((p) => p['ticket'] == null).length;

      // Filtrar pagos en cliente según la sucursalId (si se pasó)
      final List<dynamic> pagosList;
      if (sucursalId != null) {
        pagosList = pagosListAll.where((p) {
          final pt = p['ticket'];
          if (pt == null) return false; // pago sin ticket -> no pertenece a ninguna sucursal
          if (pt is Map) {
            final suc = pt['sucursal'];
            if (suc == null) return false;
            final sid = suc['id'] ?? suc['documentId'];
            return sid == sucursalId || (sid is String && sid == sucursalId.toString());
          }
          // ticket puede venir como primitivo (id o documentId)
          return false;
        }).toList();
      } else {
        pagosList = pagosListAll;
      }

      // Calcular totales
      double totalPayments = 0.0;
      for (final p in pagosList) {
        try {
          totalPayments += (p['montoPagado'] is String) ? double.parse(p['montoPagado'].toString()) : (p['montoPagado'] ?? 0.0);
        } catch (_) {}
      }

      // Deuda pendiente: suma de TODOS los tickets con saldo > 0 (independiente de estadoTicket)
      double pendingDebt = 0.0;
      for (final t in ticketsList) {
        try {
          final saldo = (t['saldoPendiente'] is String) ? double.parse(t['saldoPendiente'].toString()) : (t['saldoPendiente'] ?? 0.0);
          if (saldo > 0) {
            pendingDebt += saldo;
          }
        } catch (_) {}
      }

      // Total de tickets del día: filtrar por fecha de creación (createdAt)
      int totalTicketsToday = 0;
      if (start != null && end != null) {
        try {
          final partsStart = start.split('-');
          final partsEnd = end.split('-');
          final startDt = DateTime.utc(int.parse(partsStart[0]), int.parse(partsStart[1]), int.parse(partsStart[2]));
          final endDt = DateTime.utc(int.parse(partsEnd[0]), int.parse(partsEnd[1]), int.parse(partsEnd[2]), 23, 59, 59, 999);

          for (final t in ticketsList) {
            final rawDate = t['createdAt']; // Usar createdAt en lugar de fecha
            if (rawDate == null) continue;
            try {
              final ticketDate = DateTime.parse(rawDate.toString());
              if (ticketDate.isAfter(startDt.subtract(const Duration(seconds: 1))) &&
                  ticketDate.isBefore(endDt.add(const Duration(seconds: 1)))) {
                totalTicketsToday++;
              }
            } catch (_) {}
          }
        } catch (_) {
          totalTicketsToday = ticketsList.length;
        }
      } else {
        totalTicketsToday = ticketsList.length;
      }

      print('getDailyReport: pagosAll=$pagosAllCount pagosUnlinkedAll=$pagosUnlinkedCountAll pagosFiltered=${pagosList.length} ticketsAll=$ticketsCount ticketsToday=$totalTicketsToday totalPayments=$totalPayments pendingDebt=$pendingDebt');

      // Agrupar por día (pagos usando createdAt)
      final Map<String, Map<String, dynamic>> byDayMap = {};
      for (final p in pagosList) {
        final rawDate = p['createdAt']; // Usar createdAt
        final dateKey = _toDateKey(rawDate);
        final value = (p['montoPagado'] is String) ? double.parse(p['montoPagado'].toString()) : (p['montoPagado'] ?? 0.0);
        byDayMap.putIfAbsent(dateKey, () => {'date': dateKey, 'payments': 0.0, 'tickets': 0, 'pendingDebt': 0.0});
        byDayMap[dateKey]!['payments'] = (byDayMap[dateKey]!['payments'] as double) + value;
      }

      // Para tickets agrupamos contando solo los del rango de fechas usando createdAt
      if (start != null && end != null) {
        try {
          final partsStart = start.split('-');
          final partsEnd = end.split('-');
          final startDt = DateTime.utc(int.parse(partsStart[0]), int.parse(partsStart[1]), int.parse(partsStart[2]));
          final endDt = DateTime.utc(int.parse(partsEnd[0]), int.parse(partsEnd[1]), int.parse(partsEnd[2]), 23, 59, 59, 999);

          for (final t in ticketsList) {
            final rawDate = t['createdAt']; // Usar createdAt
            if (rawDate == null) continue;
            try {
              final ticketDate = DateTime.parse(rawDate.toString());
              if (ticketDate.isAfter(startDt.subtract(const Duration(seconds: 1))) &&
                  ticketDate.isBefore(endDt.add(const Duration(seconds: 1)))) {
                final dateKey = _toDateKey(rawDate);
                final debt = (t['saldoPendiente'] is String) ? double.parse(t['saldoPendiente'].toString()) : (t['saldoPendiente'] ?? 0.0);
                byDayMap.putIfAbsent(dateKey, () => {'date': dateKey, 'payments': 0.0, 'tickets': 0, 'pendingDebt': 0.0});
                byDayMap[dateKey]!['pendingDebt'] = (byDayMap[dateKey]!['pendingDebt'] as double) + debt;
                byDayMap[dateKey]!['tickets'] = (byDayMap[dateKey]!['tickets'] as int) + 1;
              }
            } catch (_) {}
          }
        } catch (_) {}
      }

      final byDay = byDayMap.values.toList();
      byDay.sort((a, b) => a['date'].compareTo(b['date']));

      return {
        'totalPayments': totalPayments,
        'pendingDebt': pendingDebt,
        'totalTickets': totalTicketsToday,
        'byDay': byDay,
        'debug': {
          'pagosAll': pagosAllCount,
          'pagosUnlinkedAll': pagosUnlinkedCountAll,
          'pagosFiltered': pagosList.length,
          'ticketsAll': ticketsCount,
          'ticketsToday': totalTicketsToday,
        }
      };
    } catch (e) {
      print('getDailyReport exception: $e');
      throw Exception('Error al generar reporte diario: $e');
    }
  }

  /// Obtiene lista de clientes con deuda (suma de saldoPendiente en sus tickets)
  Future<List<dynamic>> getDebtReport({int? sucursalId}) async {
    final headers = await _getHeaders();
    final List<String> ticketParams = [
      'populate[cliente]=true',
      'populate[sucursal]=true',
      'pagination[pageSize]=1000',
    ];
    if (sucursalId != null) ticketParams.add('filters[sucursal][id][\$eq]=$sucursalId');
    final ticketsEndpoint = '$_baseUrl/tickets?${ticketParams.join('&')}';
    try {
      final ticketsResp = await _getWithTimeout(Uri.parse(ticketsEndpoint), headers, seconds: 12);
      if (ticketsResp.statusCode != 200) throw Exception('Error al obtener tickets: ${ticketsResp.statusCode}');
      final ticketsData = jsonDecode(ticketsResp.body);
      final ticketsList = _normalizeItems(List<dynamic>.from(ticketsData['data'] ?? []));

      final Map<int, Map<String, dynamic>> clients = {};
      for (final t in ticketsList) {
        final cliente = t['cliente'];
        if (cliente == null) continue;
        final cid = cliente['id'] ?? cliente['documentId']?.hashCode;
        final debt = (t['saldoPendiente'] is String) ? double.parse(t['saldoPendiente'].toString()) : (t['saldoPendiente'] ?? 0.0);
        if (debt <= 0) continue;
        clients.putIfAbsent(cid, () => {'client': cliente, 'deudaTotal': 0.0, 'tickets': <dynamic>[]});
        clients[cid]!['deudaTotal'] = (clients[cid]!['deudaTotal'] as double) + debt;
        clients[cid]!['tickets'].add(t);
      }

      final list = clients.values.toList();
      list.sort((a, b) => (b['deudaTotal'] as double).compareTo(a['deudaTotal'] as double));
      return list;
    } catch (e) {
      print('getDebtReport exception: $e');
      throw Exception('Error al generar reporte de deudas: $e');
    }
  }

  /// Detalle de cliente: tickets y pagos asociados (si se pueden resolver)
  Future<Map<String, dynamic>> getClientReport(int clientId) async {
    final headers = await _getHeaders();
    // Tickets del cliente
    final ticketsEndpoint = '$_baseUrl/tickets?filters[cliente][id][\$eq]=$clientId&populate=*';
    // Pagos que tengan ticket con cliente (populamos ticket->cliente)
    final pagosEndpoint = '$_baseUrl/pagos?populate[ticket][populate]=cliente&pagination[pageSize]=1000';

    try {
      final ticketsResp = await _getWithTimeout(Uri.parse(ticketsEndpoint), headers, seconds: 12);
      if (ticketsResp.statusCode != 200) throw Exception('Error al obtener tickets del cliente: ${ticketsResp.statusCode}');
      final ticketsData = jsonDecode(ticketsResp.body);
      final ticketsList = _normalizeItems(List<dynamic>.from(ticketsData['data'] ?? []));

      final pagosResp = await _getWithTimeout(Uri.parse(pagosEndpoint), headers, seconds: 12);
      if (pagosResp.statusCode != 200) throw Exception('Error al obtener pagos: ${pagosResp.statusCode}');
      final pagosData = jsonDecode(pagosResp.body);
      final pagosList = _normalizeItems(List<dynamic>.from(pagosData['data'] ?? []));

      // Filtrar pagos relacionados al cliente (vía pago.ticket.cliente)
      final List<dynamic> pagosCliente = [];
      for (final p in pagosList) {
        final ticket = p['ticket'];
        if (ticket != null) {
          final cliente = ticket['cliente'];
          if (cliente != null && (cliente['id'] == clientId || cliente['documentId'] == clientId)) {
            pagosCliente.add(p);
          }
        }
      }

      double deudaTotal = 0.0;
      for (final t in ticketsList) {
        deudaTotal += (t['saldoPendiente'] is String) ? double.parse(t['saldoPendiente'].toString()) : (t['saldoPendiente'] ?? 0.0);
      }

      return {
        'tickets': ticketsList,
        'pagos': pagosCliente,
        'deudaTotal': deudaTotal,
      };
    } catch (e) {
      print('getClientReport exception: $e');
      throw Exception('Error al obtener detalle del cliente: $e');
    }
  }

  // Helper para normalizar fecha a YYYY-MM-DD
  String _toDateKey(dynamic rawDate) {
    if (rawDate == null) return 'unknown';
    try {
      final d = DateTime.parse(rawDate.toString()).toUtc();
      return '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    } catch (_) {
      try {
        final d = DateTime.parse(rawDate.toString());
        return '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      } catch (e) {
        return rawDate.toString().split('T').first;
      }
    }
  }

  // Obtener pago por documentId
  Future<Map<String, dynamic>?> getPagoByDocumentId(String documentId) async {
    final headers = await _getHeaders();
    final endpoint = '$_baseUrl/pagos?filters[documentId][\$eq]=$documentId&pagination[pageSize]=1&populate=*';
    try {
      final response = await _getWithTimeout(Uri.parse(endpoint), headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = _normalizeItems(data['data'] ?? []);
        if (items.isNotEmpty) return items.first as Map<String, dynamic>;
        return null;
      } else {
        print('getPagoByDocumentId failed ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception getPagoByDocumentId: $e');
      return null;
    }
  }

  // Normalizar items de respuesta
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

  // ==================== GESTIÓN DE USUARIOS ====================

  /// Obtener roles disponibles
  Future<List<Map<String, dynamic>>> getUserRoles() async {
    final headers = await _getHeaders();
    final url = Uri.parse('$_baseUrl/users-permissions/roles');

    try {
      final response = await _getWithTimeout(url, headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> roles = data['roles'] ?? [];
        return roles.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception('Error al obtener roles: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getUserRoles: $e');
      rethrow;
    }
  }

  /// Obtener todos los usuarios
  Future<List<Map<String, dynamic>>> getUsers() async {
    final headers = await _getHeaders();
    // Pedir populate=* para incluir relaciones (p. ej. sucursal)
    final url = Uri.parse('$_baseUrl/users?populate=*');

    try {
      final response = await _getWithTimeout(url, headers);

      if (response.statusCode == 200) {
        // Strapi puede devolver una lista directamente o { data: [...] } dependiendo de la versión/endpoint.
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
        if (decoded is Map && decoded.containsKey('data')) {
          final list = decoded['data'] as List<dynamic>;
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
        throw Exception('Formato de respuesta inesperado al obtener usuarios');
      } else {
        throw Exception('Error al obtener usuarios: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getUsers: $e');
      rethrow;
    }
  }

  /// Crear un nuevo usuario
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String email,
    required String password,
    String tipoUsuario = 'empleado',
    bool confirmed = true,
    bool blocked = false,
    int? roleId,
    int? sucursalId, // ID de la sucursal a asignar al usuario (opcional)
  }) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$_baseUrl/users');

    // Si no se proporciona roleId, intentar obtener el rol "Authenticated" (normalmente es 1)
    int finalRoleId = roleId ?? 1;

    // Si roleId es null, intentar obtener el rol correcto
    if (roleId == null) {
      try {
        final roles = await getUserRoles();
        final authenticatedRole = roles.firstWhere(
          (role) => role['type'] == 'authenticated',
          orElse: () => {'id': 1},
        );
        finalRoleId = authenticatedRole['id'] ?? 1;
      } catch (e) {
        print('No se pudo obtener el rol, usando ID 1 por defecto');
      }
    }

    final Map<String, dynamic> payload = {
      'username': username,
      'email': email,
      'password': password,
      'role': finalRoleId,
      'tipoUsuario': tipoUsuario,
      'confirmed': confirmed,
      'blocked': blocked,
    };
    if (sucursalId != null) {
      // Asignar relación con la sucursal (Strapi acepta el id para relaciones)
      payload['sucursal'] = sucursalId;
    }
    final body = jsonEncode(payload);

    try {
      final response = await _postWithTimeout(url, headers, body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['error']?['message'] ?? 'Error al crear usuario';
        print('Error completo al crear usuario: ${response.body}');
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('Error en createUser: $e');
      rethrow;
    }
  }

  /// Actualizar un usuario existente
  Future<Map<String, dynamic>> updateUser(
    String documentId, {
    String? username,
    String? email,
    bool? confirmed,
    bool? blocked,
    int? roleId,
  }) async {
    final headers = await _getHeaders();

    // Primero obtener el usuario para conseguir su ID numérico
    int userId;
    try {
      final users = await getUsers();
      final user = users.firstWhere(
        (u) => u['documentId'] == documentId,
        orElse: () => throw Exception('Usuario no encontrado'),
      );
      userId = user['id'];
    } catch (e) {
      print('Error al buscar usuario: $e');
      throw Exception('Usuario no encontrado');
    }

    // Usar el ID numérico en la URL
    final url = Uri.parse('$_baseUrl/users/$userId');

    // Si no se proporciona roleId, intentar obtener el rol "Authenticated"
    int? finalRoleId = roleId;
    if (finalRoleId == null) {
      try {
        final roles = await getUserRoles();
        final authenticatedRole = roles.firstWhere(
          (role) => role['type'] == 'authenticated',
          orElse: () => {'id': 1},
        );
        finalRoleId = authenticatedRole['id'] ?? 1;
      } catch (e) {
        print('No se pudo obtener el rol, usando ID 1 por defecto');
        finalRoleId = 1;
      }
    }

    final Map<String, dynamic> updates = {
      'role': finalRoleId, // Siempre incluir role
    };
    if (username != null) updates['username'] = username;
    if (email != null) updates['email'] = email;
    if (confirmed != null) updates['confirmed'] = confirmed;
    if (blocked != null) updates['blocked'] = blocked;

    final body = jsonEncode(updates);

    print('Actualizando usuario $userId con body: $body');

    try {
      final response = await _putWithTimeout(url, headers, body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['error']?['message'] ?? 'Error al actualizar usuario';
        print('Error completo al actualizar usuario: ${response.body}');
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('Error en updateUser: $e');
      rethrow;
    }
  }

  /// Eliminar un usuario
  Future<void> deleteUser(String documentId) async {
    final headers = await _getHeaders();

    // Primero obtener el usuario para conseguir su ID numérico
    int userId;
    try {
      final users = await getUsers();
      final user = users.firstWhere(
        (u) => u['documentId'] == documentId,
        orElse: () => throw Exception('Usuario no encontrado'),
      );
      userId = user['id'];
    } catch (e) {
      print('Error al buscar usuario: $e');
      throw Exception('Usuario no encontrado');
    }

    final url = Uri.parse('$_baseUrl/users/$userId');

    print('Eliminando usuario $userId');

    try {
      final response = await http.delete(url, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al eliminar usuario: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en deleteUser: $e');
      rethrow;
    }
  }

  /// Debug: obtener sucursales con detalle de cada intento (para diagnóstico)
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

   /// Debug: verificar que el JWT actual sea válido contra el endpoint auth/v1/user
   Future<Map<String, dynamic>> debugAuthCheck() async {
     try {
       final url = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/user');
       final headers = await _getHeaders();
       print('debugAuthCheck: llamando $url con Authorization present: ${headers.containsKey('Authorization')}');
       final response = await _getWithTimeout(url, headers, seconds: 8);
       print('debugAuthCheck: status=${response.statusCode} body=${response.body}');
       if (response.statusCode == 200) {
         final data = jsonDecode(response.body);
         return {'ok': true, 'data': data};
       } else {
         return {'ok': false, 'status': response.statusCode, 'body': response.body};
       }
     } catch (e) {
       print('debugAuthCheck error: $e');
       return {'ok': false, 'error': e.toString()};
     }
   }
}




