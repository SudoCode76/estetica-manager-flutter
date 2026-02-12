import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogRepository {
  final SupabaseClient _client;

  CatalogRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  // --- LECTURA (GET) ---

  Future<List<dynamic>> getCategorias() async {
    try {
      final data = await _client.from('categoriaTratamiento').select('*');
      return (data as List<dynamic>).map((e) {
        if (e is Map<String, dynamic>) {
          return {
            'id': e['id'],
            'documentId': e['id'].toString(), // Aseguramos tener documentId
            'nombreCategoria': e['nombreCategoria'] ?? e['nombre_categoria'] ?? e['name'],
            // Leemos estadocategoria (DB) y lo guardamos como estadoCategoria (App)
            'estadoCategoria': e['estadoCategoria'] ?? e['estadocategoria'] ?? true,
            'created_at': e['created_at']
          };
        }
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
        if (e is Map<String, dynamic>) {
          return {
            'id': e['id'],
            'documentId': e['id'].toString(),
            'nombreTratamiento': e['nombretratamiento'] ?? e['nombreTratamiento'] ?? e['name'],
            'precio': e['precio'],
            // Leemos estadotratamiento (DB) y lo guardamos como estadoTratamiento (App)
            'estadoTratamiento': e['estadotratamiento'] ?? e['estadoTratamiento'] ?? true,
            'categoria_tratamiento': e['categoria_id'] ?? e['categoria_tratamiento'] ?? null,
            'created_at': e['created_at']
          };
        }
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
        if (e is Map<String, dynamic>) {
          return {
            'id': e['id'],
            'nombreSucursal': e['nombreSucursal'] ?? e['nombresucursal'] ?? e['name']
          };
        }
        return e;
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  // --- ESCRITURA (CREATE / UPDATE) ---

  Future<Map<String, dynamic>> crearCategoria(Map<String, dynamic> categoria) async {
    try {
      final payload = <String, dynamic>{};
      // Mapeo App -> DB
      if (categoria.containsKey('nombreCategoria')) payload['nombreCategoria'] = categoria['nombreCategoria'];
      // Nota: Postgres suele ser case-insensitive para columnas sin comillas, pero mejor usar minúsculas si falla
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

      // CORRECCIÓN: Mapear las llaves antes de enviar
      final payload = <String, dynamic>{};
      if (changes.containsKey('nombreCategoria')) payload['nombreCategoria'] = changes['nombreCategoria'];

      // Aquí está el arreglo clave para categorías:
      if (changes.containsKey('estadoCategoria')) {
         // Intentamos enviar 'estadoCategoria' tal cual, pero si falla, prueba cambiar a 'estadocategoria'
         payload['estadoCategoria'] = changes['estadoCategoria'];
      }

      final res = await _client.from('categoriaTratamiento').update(payload).eq('id', idInt).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> crearTratamiento(Map<String, dynamic> tratamiento) async {
    try {
      final payload = <String, dynamic>{};
      // Mapeo manual App -> DB (Esto ya estaba bien en tu código original)
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

      // CORRECCIÓN IMPORTANTE: Mapear 'estadoTratamiento' -> 'estadotratamiento'
      final payload = <String, dynamic>{};

      if (changes.containsKey('nombreTratamiento')) payload['nombretratamiento'] = changes['nombreTratamiento'];
      if (changes.containsKey('precio')) payload['precio'] = changes['precio'];

      // Aquí arreglamos el error de "Column not found":
      if (changes.containsKey('estadoTratamiento')) payload['estadotratamiento'] = changes['estadoTratamiento'];

      if (changes.containsKey('categoria_tratamiento')) {
        final cat = changes['categoria_tratamiento'];
        if (cat is Map && cat.containsKey('id')) payload['categoria_id'] = cat['id'];
        else if (cat is int) payload['categoria_id'] = cat;
      }

      // Si el payload está vacío, no hacemos nada
      if (payload.isEmpty) return {};

      final res = await _client.from('tratamiento').update(payload).eq('id', idInt).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      rethrow;
    }
  }
}
