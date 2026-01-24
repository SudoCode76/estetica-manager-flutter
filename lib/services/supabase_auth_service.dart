import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Servicio de autenticación con Supabase
class SupabaseAuthService {
  // Singleton
  static final SupabaseAuthService _instance = SupabaseAuthService._internal();
  factory SupabaseAuthService() => _instance;
  SupabaseAuthService._internal();

  // Cliente de Supabase
  SupabaseClient get client => Supabase.instance.client;

  /// Login con email y password
  /// Retorna un Map con los datos del usuario autenticado y su perfil
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('=== Iniciando login con Supabase ===');
      print('Email: $email');
      
      // Autenticar con Supabase
      final AuthResponse response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      print('=== Login exitoso ===');
      
      final user = response.user;
      if (user == null) {
        throw Exception('No se pudo obtener el usuario');
      }

      print('Usuario ID: ${user.id}');
      print('User metadata: ${user.userMetadata}');

      // Obtener el perfil del usuario desde la tabla profiles
      Map<String, dynamic>? profileResponse;
      Map<String, dynamic>? sucursalData;
      
      try {
        profileResponse = await client
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .maybeSingle();

        print('=== Perfil obtenido: $profileResponse ===');

        // Si el perfil tiene sucursal_id, obtener los datos de la sucursal
        if (profileResponse != null && profileResponse['sucursal_id'] != null) {
          sucursalData = await client
              .from('sucursales')
              .select('*')
              .eq('id', profileResponse['sucursal_id'])
              .maybeSingle();

          print('=== Sucursal obtenida: $sucursalData ===');
        }
      } catch (profileError) {
        print('=== ERROR AL OBTENER PERFIL: $profileError ===');
        // Continuar sin perfil, usar solo user_metadata
      }

      // Construir objeto de respuesta similar al de Strapi para mantener compatibilidad
      // Priorizar user_metadata sobre profileResponse
      final userMap = {
        'id': user.id,
        'email': user.email,
        'username': user.userMetadata?['username'] ?? profileResponse?['username'] ?? email,
        'tipoUsuario': user.userMetadata?['tipo_usuario'] ?? profileResponse?['tipo_usuario'] ?? 'empleado',
        'sucursal': sucursalData != null ? {
          'id': sucursalData['id'],
          'nombreSucursal': sucursalData['nombreSucursal'] ?? sucursalData['nombresucursal'],
        } : null,
        'sucursalId': user.userMetadata?['sucursal_id'] ?? profileResponse?['sucursal_id'],
        'confirmed': user.emailConfirmedAt != null,
        'blocked': false,
        'createdAt': user.createdAt,
        'updatedAt': user.updatedAt,
      };

      print('=== Usuario mapeado: $userMap ===');

      return {
        'user': userMap,
        'jwt': response.session?.accessToken,
        'session': response.session?.toJson(),
      };
    } catch (e) {
      print('=== ERROR EN LOGIN SUPABASE: $e ===');
      print('=== Tipo de error: ${e.runtimeType} ===');
      if (e is AuthException) {
        print('=== AuthException message: ${e.message} ===');
        print('=== AuthException statusCode: ${e.statusCode} ===');
        if (e.message.contains('Invalid login credentials') || 
            e.message.contains('invalid') ||
            e.statusCode == '400') {
          throw Exception('Credenciales inválidas');
        }
        throw Exception(e.message);
      }
      if (e is Exception) {
        throw e;
      }
      throw Exception('Error desconocido: $e');
    }
  }

  /// Registrar nuevo usuario
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String username,
    String tipoUsuario = 'empleado',
    int? sucursalId,
  }) async {
    try {
      print('=== Registrando usuario en Supabase ===');
      
      final AuthResponse response = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'tipo_usuario': tipoUsuario,
          'sucursal_id': sucursalId,
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception('No se pudo crear el usuario');
      }

      print('=== Usuario registrado exitosamente ===');
      print('Usuario ID: ${user.id}');

      // Actualizar el perfil en la tabla profiles si es necesario
      if (sucursalId != null || tipoUsuario != 'empleado') {
        await client.from('profiles').update({
          'tipo_usuario': tipoUsuario,
          'sucursal_id': sucursalId,
        }).eq('id', user.id);
      }

      return {
        'user': {
          'id': user.id,
          'email': user.email,
          'username': username,
          'tipoUsuario': tipoUsuario,
          'sucursalId': sucursalId,
        },
        'jwt': response.session?.accessToken,
      };
    } catch (e) {
      print('=== ERROR EN REGISTRO SUPABASE: $e ===');
      if (e is AuthException) {
        throw Exception(e.message);
      }
      rethrow;
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
      
      // Limpiar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt');
      await prefs.remove('user');
      await prefs.remove('userType');
      await prefs.remove('selectedSucursalId');
      await prefs.remove('selectedSucursalName');
      
      print('=== Sesión cerrada exitosamente ===');
    } catch (e) {
      print('=== ERROR AL CERRAR SESIÓN: $e ===');
      rethrow;
    }
  }

  /// Obtener el usuario actual
  User? getCurrentUser() {
    return client.auth.currentUser;
  }

  /// Verificar si hay una sesión activa
  bool isAuthenticated() {
    return client.auth.currentUser != null;
  }

  /// Obtener la sesión actual
  Session? getCurrentSession() {
    return client.auth.currentSession;
  }

  /// Refrescar el token
  Future<void> refreshSession() async {
    try {
      final response = await client.auth.refreshSession();
      if (response.session == null) {
        throw Exception('No se pudo refrescar la sesión');
      }
    } catch (e) {
      print('=== ERROR AL REFRESCAR SESIÓN: $e ===');
      rethrow;
    }
  }

  /// Obtener perfil completo del usuario actual
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;

      final profileResponse = await client
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse == null) {
        // Si no hay perfil, devolver datos desde user_metadata
        return {
          'id': user.id,
          'email': user.email,
          'username': user.userMetadata?['username'] ?? user.email,
          'tipoUsuario': user.userMetadata?['tipo_usuario'] ?? 'empleado',
          'sucursal': null,
          'sucursalId': user.userMetadata?['sucursal_id'],
        };
      }

      // Obtener sucursal si existe
      Map<String, dynamic>? sucursalData;
      if (profileResponse['sucursal_id'] != null) {
        try {
          sucursalData = await client
              .from('sucursales')
              .select('*')
              .eq('id', profileResponse['sucursal_id'])
              .maybeSingle();
        } catch (e) {
          print('=== ERROR AL OBTENER SUCURSAL: $e ===');
        }
      }

      return {
        'id': user.id,
        'email': user.email,
        'username': profileResponse['username'] ?? user.userMetadata?['username'],
        'tipoUsuario': profileResponse['tipo_usuario'] ?? user.userMetadata?['tipo_usuario'],
        'sucursal': sucursalData,
        'sucursalId': profileResponse['sucursal_id'],
      };
    } catch (e) {
      print('=== ERROR AL OBTENER PERFIL: $e ===');
      return null;
    }
  }

  /// Guardar sesión en SharedPreferences (para compatibilidad con código existente)
  Future<void> saveSessionToPrefs(Map<String, dynamic> loginResult) async {
    final prefs = await SharedPreferences.getInstance();
    final user = loginResult['user'];
    final jwt = loginResult['jwt'];
    final sessionObj = loginResult['session'];
    String? refreshToken;
    try {
      if (sessionObj != null && sessionObj is Map && sessionObj['refresh_token'] != null) {
        refreshToken = sessionObj['refresh_token'];
      } else if (loginResult['refreshToken'] != null) {
        refreshToken = loginResult['refreshToken'];
      }
    } catch (_) {}

    await prefs.setString('jwt', jwt ?? '');
    await prefs.setString('user', jsonEncode(user));
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString('refreshToken', refreshToken);
    }
    await prefs.setString('userType', user['tipoUsuario'] ?? '');
    
    // Guardar datos de sucursal si están disponibles
    if (user['sucursalId'] != null) {
      await prefs.setInt('selectedSucursalId', user['sucursalId']);
    }
    if (user['sucursal'] != null && user['sucursal']['nombreSucursal'] != null) {
      await prefs.setString('selectedSucursalName', user['sucursal']['nombreSucursal']);
    }
    
    // Si el usuario es administrador, guardar su JWT también como adminToken para usar en las Functions.
    try {
      if (jwt != null && jwt.toString().isNotEmpty && (user['tipoUsuario']?.toString().toLowerCase() ?? '') == 'administrador') {
        // Importar ApiService aquí para evitar circularidad en top-level
        // Nota: este guardado es para facilitar las llamadas a las Edge Functions desde la app.
        try {
          // Guardar admin token directamente en SharedPreferences (evita circular import con ApiService)
          final prefs2 = await SharedPreferences.getInstance();
          await prefs2.setString('adminToken', jwt.toString());
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await prefs2.setString('adminRefreshToken', refreshToken);
          }
          print('saveSessionToPrefs: admin token saved in prefs because user is administrador');
        } catch (e) {
          print('saveSessionToPrefs: could not save admin token in prefs: $e');
        }
      }
    } catch (_) {}

    print('=== Sesión guardada en SharedPreferences ===');
  }

  /// Restaurar sesión desde SharedPreferences
  Future<bool> restoreSessionFromPrefs() async {
    try {
      final session = getCurrentSession();
      if (session != null) {
        print('=== Sesión de Supabase activa ===');
        return true;
      }
      return false;
    } catch (e) {
      print('=== ERROR AL RESTAURAR SESIÓN: $e ===');
      return false;
    }
  }
}
