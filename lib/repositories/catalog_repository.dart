import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogRepository {
  final SupabaseClient _client;

  CatalogRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  Future<List<dynamic>> getCategorias() async {
    try {
      final data = await _client.from('categoriaTratamiento').select('*');
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
      rethrow;
    }
  }

  Future<List<dynamic>> getTratamientos({int? categoriaId}) async {
    try {
      var qb = _client.from('tratamiento').select('*');
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
      rethrow;
    }
  }

  Future<List<dynamic>> getSucursales() async {
    try {
      final data = await _client.from('sucursales').select('*');
      return (data as List<dynamic>).map((e) {
        if (e is Map<String, dynamic>) return {
          'id': e['id'],
          'nombreSucursal': e['nombreSucursal'] ?? e['nombre_sucursal'] ?? e['name']
        };
        return e;
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> crearCategoria(Map<String, dynamic> categoria) async {
    try {
      final payload = <String, dynamic>{};
      if (categoria.containsKey('nombreCategoria')) payload['nombreCategoria'] = categoria['nombreCategoria'];
      if (categoria.containsKey('estadoCategoria')) payload['estadoCategoria'] = categoria['estadoCategoria'];

      final res = await _client.from('categoriaTratamiento').insert(payload).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCategoria(String documentId, Map<String, dynamic> changes) async {
    try {
      final idInt = int.tryParse(documentId.toString());
      if (idInt == null) throw Exception('ID de categoría inválido: $documentId');
      final res = await _client.from('categoriaTratamiento').update(changes).eq('id', idInt).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> crearTratamiento(Map<String, dynamic> tratamiento) async {
    try {
      final payload = <String, dynamic>{};
      if (tratamiento.containsKey('nombreTratamiento')) payload['nombretratamiento'] = tratamiento['nombreTratamiento'];
      if (tratamiento.containsKey('precio')) payload['precio'] = tratamiento['precio'];
      if (tratamiento.containsKey('estadoTratamiento')) payload['estadotratamiento'] = tratamiento['estadoTratamiento'];
      if (tratamiento.containsKey('categoria_tratamiento')) {
        final cat = tratamiento['categoria_tratamiento'];
        if (cat is Map && cat.containsKey('id')) payload['categoria_id'] = cat['id'];
        else if (cat is int) payload['categoria_id'] = cat;
      }

      final res = await _client.from('tratamiento').insert(payload).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTratamiento(String documentId, Map<String, dynamic> changes) async {
    try {
      final idInt = int.tryParse(documentId.toString());
      if (idInt == null) throw Exception('ID de tratamiento inválido: $documentId');
      final res = await _client.from('tratamiento').update(changes).eq('id', idInt).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      rethrow;
    }
  }
}
