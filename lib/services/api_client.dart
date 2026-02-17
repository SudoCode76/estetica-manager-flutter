import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_estetica/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente base con helpers HTTP y utilidades compartidas.
class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  static String? debugBaseUrl;
  static const String _productionUrl =
      'https://fantastic-agreement-b2f3f76198.strapiapp.com/api';
  String get baseUrl => (debugBaseUrl != null && debugBaseUrl!.isNotEmpty)
      ? debugBaseUrl!
      : _productionUrl;

  Future<Map<String, String>> getHeaders() async {
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
    headers['Authorization'] = hasJwt
        ? 'Bearer $jwt'
        : 'Bearer ${SupabaseConfig.supabaseAnonKey}';
    return headers;
  }

  Future<http.Response> getWithTimeout(
    Uri uri,
    Map<String, String> headers, {
    int seconds = 8,
  }) async {
    try {
      final resp = await http
          .get(uri, headers: headers)
          .timeout(Duration(seconds: seconds));
      return resp;
    } catch (e) {
      rethrow;
    }
  }

  Future<http.Response> postWithTimeout(
    Uri uri,
    Map<String, String> headers,
    Object? body, {
    int seconds = 8,
  }) async {
    try {
      final resp = await http
          .post(uri, headers: headers, body: body)
          .timeout(Duration(seconds: seconds));
      return resp;
    } catch (e) {
      rethrow;
    }
  }

  Future<http.Response> patchWithTimeout(
    Uri uri,
    Map<String, String> headers,
    Object? body, {
    int seconds = 8,
  }) async {
    try {
      final resp = await http
          .patch(uri, headers: headers, body: body)
          .timeout(Duration(seconds: seconds));
      return resp;
    } catch (e) {
      rethrow;
    }
  }

  // Normalización mínima usada por endpoints que vienen de Strapi
  List<dynamic> normalizeItems(List<dynamic> items) {
    return items.map((item) {
      if (item is Map && item.containsKey('attributes')) {
        final attrs = Map<String, dynamic>.from(item['attributes']);
        attrs['id'] = item['id'];
        item.forEach((k, v) {
          if (k != 'attributes' && k != 'id' && !attrs.containsKey(k))
            attrs[k] = v;
        });
        attrs.forEach((key, value) {
          if (value is Map && value.containsKey('data')) {
            final relationData = value['data'];
            if (relationData == null)
              attrs[key] = null;
            else if (relationData is Map)
              attrs[key] = normalizeItems([relationData]).first;
            else if (relationData is List)
              attrs[key] = normalizeItems(relationData);
          }
        });
        return attrs;
      }
      return item;
    }).toList();
  }

  List<dynamic> normalizarDatosVista(List<dynamic> data) {
    return data.map((item) {
      final newItem = Map<String, dynamic>.from(item);
      if (newItem['cliente'] == null) {
        newItem['cliente'] = {
          'nombrecliente': newItem['nombrecliente'] ?? '',
          'apellidocliente': newItem['apellidocliente'] ?? '',
          'telefono': newItem['telefono'],
          'id': newItem['cliente_id'],
        };
      }
      if (newItem['tratamiento'] == null) {
        newItem['tratamiento'] = {
          'nombretratamiento': newItem['nombretratamiento'] ?? '',
          'precio': newItem['precio'],
        };
      }
      if (newItem['estado_sesion_enum'] == null &&
          newItem['estado_sesion'] != null) {
        newItem['estado_sesion_enum'] = newItem['estado_sesion'];
      }
      return newItem;
    }).toList();
  }
}
