import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_estetica/services/supabase_auth_service.dart';

class AuthRepository {
  final SupabaseAuthService _auth = SupabaseAuthService();
  final SupabaseClient _client;

  AuthRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Login via SupabaseAuthService
  Future<Map<String, dynamic>> login(String email, String password) {
    return _auth.login(email, password);
  }

  /// Obtener usuarios (profiles) con opción de filtro por sucursal o búsqueda
  Future<List<dynamic>> getUsuarios({int? sucursalId, String? query}) async {
    try {
      var qb = _client.from('profiles').select('*, email');
      if (sucursalId != null) qb = qb.eq('sucursal_id', sucursalId);
      if (query != null && query.isNotEmpty)
        qb = qb.ilike('username', '%$query%');
      final data = await qb;
      return (data as List<dynamic>).map((e) {
        if (e is Map<String, dynamic>)
          return {
            'id': e['id'],
            'documentId': e['id']?.toString(),
            'username': e['username'] ?? e['user_metadata']?['username'] ?? '',
            'email': e['email'] ?? e['user_metadata']?['email'] ?? '',
            'tipoUsuario': e['tipo_usuario'] ?? e['tipoUsuario'] ?? 'empleado',
            'sucursal': e['sucursal_id'] != null
                ? {'id': e['sucursal_id'], 'nombreSucursal': null}
                : null,
            'confirmed': e['confirmed'] ?? true,
            'blocked': e['blocked'] ?? false,
            'createdAt': e['created_at'] ?? e['createdAt'],
          };
        return e;
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Obtener perfil por id
  Future<Map<String, dynamic>?> getUsuarioById(String id) async {
    try {
      final resp = await _client
          .from('profiles')
          .select('*, email')
          .eq('id', id)
          .maybeSingle();
      if (resp == null) return null;
      return Map<String, dynamic>.from(resp);
    } catch (e) {
      rethrow;
    }
  }

  /// Crear usuario con signUp (usa SupabaseAuthService)
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String email,
    required String password,
    String tipoUsuario = 'empleado',
    int? sucursalId,
    bool? confirmed,
    bool? blocked,
  }) async {
    return _auth.signUp(
      email: email,
      password: password,
      username: username,
      tipoUsuario: tipoUsuario,
      sucursalId: sucursalId,
    );
  }

  /// Actualizar perfil (profiles)
  Future<Map<String, dynamic>> updateUser(
    String documentId, {
    String? username,
    String? email,
    String? tipoUsuario,
    int? sucursalId,
    bool? confirmed,
    bool? blocked,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (username != null) payload['username'] = username;
      if (tipoUsuario != null) payload['tipo_usuario'] = tipoUsuario;
      if (sucursalId != null) payload['sucursal_id'] = sucursalId;

      if (payload.isEmpty)
        throw Exception('No hay campos válidos para actualizar en profiles');

      final data = await _client
          .from('profiles')
          .update(payload)
          .eq('id', documentId)
          .select()
          .single();
      return Map<String, dynamic>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Variante que acepta confirmed/blocked directamente (intentamos actualizar en profiles)
  Future<Map<String, dynamic>> updateUserWithFlags2(
    String documentId, {
    String? username,
    String? email,
    bool? confirmed,
    bool? blocked,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (username != null) payload['username'] = username;
      if (email != null) payload['email'] = email;
      if (confirmed != null) payload['confirmed'] = confirmed;
      if (blocked != null) payload['blocked'] = blocked;

      if (payload.isEmpty) throw Exception('No hay campos para actualizar');

      final resp = await _client
          .from('profiles')
          .update(payload)
          .eq('id', documentId)
          .select()
          .single();
      return Map<String, dynamic>.from(resp);
    } catch (e) {
      rethrow;
    }
  }

  /// Eliminar perfil (nota: no borra auth.user a menos que uses funciones admin)
  Future<void> deleteUser(String documentId) async {
    try {
      await _client.from('profiles').delete().eq('id', documentId);
    } catch (e) {
      rethrow;
    }
  }

  // Edge Functions: mantener wrappers que ya usábamos anteriormente
  Future<Map<String, dynamic>> crearUsuarioFunction({
    required String email,
    required String password,
    required String nombre,
    required int sucursalId,
    required String tipoUsuario,
  }) async {
    // 1. Obtener el token de la sesión actual
    final session = _client.auth.currentSession;
    final token = session?.accessToken;

    if (token == null) {
      throw Exception('No hay sesión activa para autorizar la creación');
    }

    final body = {
      'email': email,
      'password': password,
      'nombre': nombre,
      'sucursal_id': sucursalId,
      'tipo_usuario': tipoUsuario,
      'token_admin': token, // token de la sesión que autoriza la operación
    };

    try {
      final resp = await _client.functions.invoke('crear-usuario', body: body);

      // Si la función devolvió datos en formato map, retornarlos
      if (resp.data is Map<String, dynamic>)
        return resp.data as Map<String, dynamic>;
      return {'result': resp.data};
    } on FunctionException catch (e) {
      // Capturar errores específicos de la función (400, 401, 500)
      String message;
      if (e.details is Map && (e.details as Map).containsKey('error')) {
        message = (e.details as Map)['error'].toString();
      } else {
        message = e.toString();
      }
      throw Exception(message);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> eliminarUsuarioFunction(String idUsuario) async {
    // 1. Obtener el token de la sesión actual (Admin)
    final session = _client.auth.currentSession;
    final token = session?.accessToken;

    if (token == null) {
      throw Exception('No hay sesión activa para autorizar la eliminación');
    }

    final body = {
      'id_a_borrar': idUsuario,
      'token_admin': token, // <-- incluir token de admin
    };

    try {
      final resp = await _client.functions.invoke(
        'eliminar-usuario',
        body: body,
      );

      if (resp.data is Map<String, dynamic>) {
        return resp.data as Map<String, dynamic>;
      }
      return {'result': resp.data};
    } on FunctionException catch (e) {
      // Capturar errores específicos de la función (401, 403, etc)
      String message;
      if (e.details is Map && (e.details as Map).containsKey('error')) {
        message = (e.details as Map)['error'].toString();
      } else {
        message = e.toString();
      }
      throw Exception(message);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> editarPasswordFunction(
    String idUsuario,
    String nuevaPassword,
  ) async {
    final body = {'id_usuario': idUsuario, 'nueva_password': nuevaPassword};
    final resp = await _client.functions.invoke('editar-password', body: body);
    if (resp.status == 200 || resp.status == 201) {
      if (resp.data is Map<String, dynamic>)
        return resp.data as Map<String, dynamic>;
      return {'result': resp.data};
    }
    throw Exception(
      'Error editando password via function: status=${resp.status} data=${resp.data}',
    );
  }
}
