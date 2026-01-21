import 'package:flutter/material.dart';
import 'package:app_estetica/services/api_service.dart';

class TreatmentsScreen extends StatefulWidget {
  const TreatmentsScreen({Key? key}) : super(key: key);

  @override
  State<TreatmentsScreen> createState() => _TreatmentsScreenState();
}

class _TreatmentsScreenState extends State<TreatmentsScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  List<dynamic> _categoriasAll = [];
  List<dynamic> _tratamientosAll = [];

  List<dynamic> _categorias = [];
  List<dynamic> _tratamientos = [];

  bool _loading = true;
  bool _saving = false;
  bool _showDisabled = false;
  int? _selectedCategoriaId;

  final TextEditingController _categorySearchCtrl = TextEditingController();
  final TextEditingController _treatmentSearchCtrl = TextEditingController();
  int? _treatmentCategoryFilter;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _categorySearchCtrl.addListener(() => _applyCategorySearch(_categorySearchCtrl.text));
    _treatmentSearchCtrl.addListener(() => _applyTreatmentSearch(_treatmentSearchCtrl.text));
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Rebuild when tab index changes (swipe or programmatic)
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _categorySearchCtrl.dispose();
    _treatmentSearchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final cats = await _api.getCategorias();
      final trats = await _api.getTratamientos();
      _categoriasAll = cats;
      _tratamientosAll = trats;
      _applyFilters();
      _applyCategorySearch(_categorySearchCtrl.text);
      _applyTreatmentSearch(_treatmentSearchCtrl.text);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    if (_showDisabled) {
      _categorias = List<dynamic>.from(_categoriasAll);
      _tratamientos = List<dynamic>.from(_tratamientosAll);
    } else {
      _categorias = _categoriasAll.where((c) => c['estadoCategoria'] == true || c['estadoCategoria'] == null).toList();
      _tratamientos = _tratamientosAll.where((t) => t['estadoTratamiento'] == true || t['estadoTratamiento'] == null).toList();
    }
  }

  void _applyCategorySearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _applyFilters();
      } else {
        final base = _showDisabled ? _categoriasAll : _categoriasAll.where((c) => c['estadoCategoria'] == true || c['estadoCategoria'] == null);
        _categorias = base.where((c) => (c['nombreCategoria']?.toString().toLowerCase() ?? '').contains(q)).toList();
      }
    });
  }

  void _applyTreatmentSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      List<dynamic> base = _showDisabled ? List<dynamic>.from(_tratamientosAll) : _filterTratamientosList(_tratamientosAll);
      if (_treatmentCategoryFilter != null) {
        base = base.where((t) {
          final cat = t['categoria_tratamiento'];
          final catId = (cat is Map) ? cat['id'] : cat;
          return catId == _treatmentCategoryFilter;
        }).toList();
      }
      if (q.isEmpty) {
        _tratamientos = base;
      } else {
        _tratamientos = base.where((t) {
          final name = (t['nombreTratamiento']?.toString().toLowerCase()) ?? '';
          final desc = (t['descripcion']?.toString().toLowerCase()) ?? '';
          return name.contains(q) || desc.contains(q);
        }).toList();
      }
    });
  }

  List<dynamic> _filterTratamientosList(List<dynamic> list) {
    if (_showDisabled) return List<dynamic>.from(list);
    final activeCatIds = _categoriasAll.where((c) => c['estadoCategoria'] == true || c['estadoCategoria'] == null).map((c) => c['id']).toSet();
    return list.where((t) {
      final bool tratActivo = t['estadoTratamiento'] == true || t['estadoTratamiento'] == null;
      if (!tratActivo) return false;
      final cat = t['categoria_tratamiento'];
      if (cat == null) return true;
      final catId = (cat is Map) ? cat['id'] : cat;
      if (catId == null) return true;
      return activeCatIds.contains(catId);
    }).toList();
  }

  int _countTratamientosPorCategoria(int? categoriaId) {
    if (categoriaId == null) return 0;
    return _tratamientosAll.where((t) {
      final cat = t['categoria_tratamiento'];
      final catId = (cat is Map) ? cat['id'] : cat;
      return catId == categoriaId && (t['estadoTratamiento'] == true || t['estadoTratamiento'] == null);
    }).length;
  }

  String _getCategoriaNombreFromTratamiento(Map<String, dynamic> t) {
    final cat = t['categoria_tratamiento'];
    if (cat == null) return 'Sin categoría';
    if (cat is Map) return cat['nombreCategoria'] ?? 'Sin categoría';
    final found = _categoriasAll.firstWhere((c) => c['id'] == cat, orElse: () => null);
    return found != null ? (found['nombreCategoria'] ?? 'Sin categoría') : 'Sin categoría';
  }

  // ---- CRUD helpers (crear/editar/activar/desactivar) ----
  Future<void> _showCreateCategoriaDialog() async {
    final TextEditingController ctrl = TextEditingController();
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear categoría'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            final nombre = ctrl.text.trim();
            if (nombre.isEmpty) return;
            Navigator.pop(ctx, true);
            setState(() => _saving = true);
            try {
              final existing = _categoriasAll.firstWhere((c) => (c['nombreCategoria']?.toString().trim().toLowerCase() ?? '') == nombre.toLowerCase(), orElse: () => null);
              if (existing != null) {
                if ((existing['estadoCategoria'] == true)) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La categoría ya existe')));
                } else {
                  // reactivar
                  await _api.updateCategoria(existing['documentId'] ?? existing['id'].toString(), {'estadoCategoria': true});
                  await _loadAll();
                }
              } else {
                await _api.crearCategoria({'nombreCategoria': nombre});
                await _loadAll();
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            } finally {
              if (mounted) setState(() => _saving = false);
            }
          }, child: const Text('Crear')),
        ],
      ),
    );
  }

  Future<void> _showCreateTratamientoDialog() async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    int? selectedCatId = _categorias.isNotEmpty ? _categorias.first['id'] : null;

    await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isNarrowDialog = MediaQuery.of(ctx).size.width < 420;
        final maxW = isNarrowDialog ? MediaQuery.of(ctx).size.width - 32 : 520.0;
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: isNarrowDialog ? 16 : 48, vertical: 24),
          title: const Text('Crear tratamiento'),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 12),
                  TextField(controller: precioCtrl, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  if (_categorias.isNotEmpty)
                    DropdownButtonFormField<int>(
                      initialValue: selectedCatId,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: _categorias.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['nombreCategoria'] ?? '-'))).toList(),
                      onChanged: (v) => selectedCatId = v,
                    )
                  else
                    const Align(alignment: Alignment.centerLeft, child: Text('Crea primero una categoría')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () async {
              final nombre = nombreCtrl.text.trim();
              final precio = precioCtrl.text.trim();
              if (nombre.isEmpty || precio.isEmpty) return;
              Navigator.pop(ctx, true);
              setState(() => _saving = true);
              try {
                final existing = _tratamientosAll.firstWhere((t) {
                  final tname = (t['nombreTratamiento']?.toString().trim().toLowerCase()) ?? '';
                  final tcat = (t['categoria_tratamiento'] is Map) ? t['categoria_tratamiento']['id'] : t['categoria_tratamiento'];
                  return tname == nombre.toLowerCase() && (selectedCatId == null ? true : (tcat == selectedCatId));
                }, orElse: () => null);
                if (existing != null) {
                  if (existing['estadoTratamiento'] == true) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El tratamiento ya existe')));
                  } else {
                    await _api.updateTratamiento(existing['documentId'] ?? existing['id'].toString(), {'estadoTratamiento': true});
                    await _loadAll();
                  }
                } else {
                  final Map<String, dynamic> payload = {'nombreTratamiento': nombre, 'precio': precio, 'estadoTratamiento': true};
                  if (selectedCatId != null) payload['categoria_tratamiento'] = selectedCatId;
                  await _api.crearTratamiento(payload);
                  await _loadAll();
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            }, child: const Text('Crear')),
          ],
        );
      },
    );
  }

  Future<void> _showEditTratamientoDialog(Map<String, dynamic> t) async {
    final nombreCtrl = TextEditingController(text: t['nombreTratamiento'] ?? '');
    final precioCtrl = TextEditingController(text: t['precio']?.toString() ?? '');
    int? selectedCatId = (t['categoria_tratamiento'] is Map) ? t['categoria_tratamiento']['id'] : t['categoria_tratamiento'];

    await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isNarrowDialog = MediaQuery.of(ctx).size.width < 420;
        final maxW = isNarrowDialog ? MediaQuery.of(ctx).size.width - 32 : 520.0;
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: isNarrowDialog ? 16 : 48, vertical: 24),
          title: const Text('Editar tratamiento'),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 12),
                  TextField(controller: precioCtrl, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  if (_categoriasAll.isNotEmpty)
                    DropdownButtonFormField<int>(
                      initialValue: selectedCatId,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: _categoriasAll.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['nombreCategoria'] ?? '-'))).toList(),
                      onChanged: (v) => selectedCatId = v,
                    )
                  else
                    const Align(alignment: Alignment.centerLeft, child: Text('No hay categorías')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () async {
              final nombre = nombreCtrl.text.trim();
              final precio = precioCtrl.text.trim();
              if (nombre.isEmpty || precio.isEmpty) return;
              Navigator.pop(ctx, true);
              setState(() => _saving = true);
              try {
                final Map<String, dynamic> payload = {'nombreTratamiento': nombre, 'precio': precio, 'categoria_tratamiento': selectedCatId, 'estadoTratamiento': t['estadoTratamiento'] ?? true};
                await _api.updateTratamiento(t['documentId'] ?? t['id'].toString(), payload);
                await _loadAll();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error actualizando: $e')));
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            }, child: const Text('Guardar')),
          ],
        );
      },
    );
  }

  Future<void> _toggleTratamientoEstado(Map<String, dynamic> t) async {
    final docId = t['documentId'] ?? t['id']?.toString();
    if (docId == null) return;
    setState(() => _saving = true);
    try {
      final newEstado = !(t['estadoTratamiento'] == true);
      await _api.updateTratamiento(docId, {'estadoTratamiento': newEstado});
      await _loadAll();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showEditCategoriaDialog(Map<String, dynamic> c) async {
    final ctrl = TextEditingController(text: c['nombreCategoria'] ?? '');
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar categoría'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            final nombre = ctrl.text.trim();
            if (nombre.isEmpty) return;
            Navigator.pop(ctx, true);
            setState(() => _saving = true);
            try {
              await _api.updateCategoria(c['documentId'] ?? c['id'].toString(), {'nombreCategoria': nombre, 'estadoCategoria': c['estadoCategoria'] ?? true});
              await _loadAll();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            } finally {
              if (mounted) setState(() => _saving = false);
            }
          }, child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<void> _toggleCategoriaEstado(Map<String, dynamic> c) async {
    final docId = c['documentId'] ?? c['id']?.toString();
    if (docId == null) return;
    setState(() => _saving = true);
    try {
      final newEstado = !(c['estadoCategoria'] == true);
      await _api.updateCategoria(docId, {'estadoCategoria': newEstado});
      await _loadAll();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // UI builders
  Widget _buildCategoryListItem(Map<String, dynamic> c, ColorScheme cs, TextTheme tt, bool isNarrow) {
    final int count = _countTratamientosPorCategoria(c['id']);
    final bool selected = _selectedCategoriaId == c['id'];
    final bool activo = c['estadoCategoria'] == true || c['estadoCategoria'] == null;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isNarrow ? 4 : 12, vertical: 6),
      decoration: BoxDecoration(
        color: activo ? cs.surface : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: selected ? Border.all(color: cs.primary, width: 2) : Border.all(color: cs.outlineVariant.withValues(alpha: 0.3), width: 1),
        boxShadow: activo ? [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(isNarrow ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c['nombreCategoria'] ?? '-',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: activo ? cs.onSurface : cs.onSurfaceVariant,
                      fontSize: isNarrow ? 15 : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Botones de acción
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _showEditCategoriaDialog(c),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
                        foregroundColor: cs.primary,
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: 'Editar',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(activo ? Icons.visibility_off_outlined : Icons.restore_outlined, size: 18),
                      onPressed: () => _toggleCategoriaEstado(c),
                      style: IconButton.styleFrom(
                        backgroundColor: activo ? cs.errorContainer.withValues(alpha: 0.5) : cs.primaryContainer.withValues(alpha: 0.5),
                        foregroundColor: activo ? cs.error : cs.primary,
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: activo ? 'Desactivar' : 'Reactivar',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: activo ? cs.secondaryContainer : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count tratamiento${count != 1 ? 's' : ''}',
                    style: tt.bodySmall?.copyWith(
                      color: activo ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: isNarrow ? 11 : null,
                    ),
                  ),
                ),
                if (!activo)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Desactivada',
                      style: tt.bodySmall?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.w600,
                        fontSize: isNarrow ? 11 : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesTab(ColorScheme cs, TextTheme tt, bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra de búsqueda y controles mejorada
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 0 : 4.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: TextField(
                    controller: _categorySearchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant, size: isNarrow ? 20 : 24),
                      hintText: 'Buscar categorías...',
                      hintStyle: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        fontSize: isNarrow ? 14 : null,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 16, vertical: isNarrow ? 12 : 14),
                    ),
                    style: TextStyle(fontSize: isNarrow ? 14 : null),
                  ),
                ),
              ),
              SizedBox(width: isNarrow ? 8 : 12),
              Container(
                decoration: BoxDecoration(
                  color: _showDisabled ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: IconButton(
                  icon: Icon(
                    _showDisabled ? Icons.visibility : Icons.visibility_off_outlined,
                    color: _showDisabled ? cs.primary : cs.onSurfaceVariant,
                    size: isNarrow ? 20 : 24,
                  ),
                  onPressed: () {
                    setState(() {
                      _showDisabled = !_showDisabled;
                      _applyFilters();
                      _applyCategorySearch(_categorySearchCtrl.text);
                      _applyTreatmentSearch(_treatmentSearchCtrl.text);
                    });
                  },
                  padding: EdgeInsets.all(isNarrow ? 8 : 12),
                  constraints: BoxConstraints(minWidth: isNarrow ? 40 : 48, minHeight: isNarrow ? 40 : 48),
                  tooltip: _showDisabled ? 'Ocultar desactivados' : 'Mostrar desactivados',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: _categorias.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No hay categorías', style: tt.bodyMedium)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _categorias.length,
                    itemBuilder: (context, index) {
                      final c = _categorias[index] as Map<String, dynamic>;
                      return _buildCategoryListItem(c, cs, tt, isNarrow);
                    },
                  ),
          ),
        ),
        SizedBox(height: isNarrow ? 8 : 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Total de ${_categorias.length} categorías registradas',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: isNarrow ? 11 : null,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SizedBox(height: isNarrow ? 72 : 60), // espacio para FAB
      ],
    );
  }

  Widget _buildTratamientoItem(Map<String, dynamic> t, ColorScheme cs, TextTheme tt, bool isNarrow) {
    final bool activoTrat = t['estadoTratamiento'] == true || t['estadoTratamiento'] == null;
    final String categoriaNombre = _getCategoriaNombreFromTratamiento(t);
    final String precio = t['precio']?.toString() ?? '-';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isNarrow ? 4 : 12, vertical: 6),
      decoration: BoxDecoration(
        color: activoTrat ? cs.surface : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3), width: 1),
        boxShadow: activoTrat ? [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(isNarrow ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t['nombreTratamiento'] ?? '-',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: activoTrat ? cs.onSurface : cs.onSurfaceVariant,
                      fontSize: isNarrow ? 15 : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Botones de acción
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _showEditTratamientoDialog(t),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
                        foregroundColor: cs.primary,
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: 'Editar',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(activoTrat ? Icons.visibility_off_outlined : Icons.restore_outlined, size: 18),
                      onPressed: () => _toggleTratamientoEstado(t),
                      style: IconButton.styleFrom(
                        backgroundColor: activoTrat ? cs.errorContainer.withValues(alpha: 0.5) : cs.primaryContainer.withValues(alpha: 0.5),
                        foregroundColor: activoTrat ? cs.error : cs.primary,
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: activoTrat ? 'Desactivar' : 'Reactivar',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Badge de categoría
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: activoTrat ? cs.secondaryContainer : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.label_outline,
                        size: 12,
                        color: activoTrat ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          categoriaNombre,
                          style: tt.bodySmall?.copyWith(
                            color: activoTrat ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: isNarrow ? 11 : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de precio
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: activoTrat ? cs.tertiaryContainer : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_money,
                        size: 12,
                        color: activoTrat ? cs.onTertiaryContainer : cs.onSurfaceVariant,
                      ),
                      Text(
                        precio,
                        style: tt.bodySmall?.copyWith(
                          color: activoTrat ? cs.onTertiaryContainer : cs.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          fontSize: isNarrow ? 11 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!activoTrat)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Desactivado',
                      style: tt.bodySmall?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.w600,
                        fontSize: isNarrow ? 11 : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreatmentsTab(ColorScheme cs, TextTheme tt, bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra de búsqueda y controles mejorada
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 0 : 4.0, vertical: 8.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: TextField(
                        controller: _treatmentSearchCtrl,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant, size: isNarrow ? 20 : 24),
                          hintText: 'Buscar tratamientos...',
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            fontSize: isNarrow ? 14 : null,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 16, vertical: isNarrow ? 12 : 14),
                        ),
                        style: TextStyle(fontSize: isNarrow ? 14 : null),
                      ),
                    ),
                  ),
                  SizedBox(width: isNarrow ? 8 : 12),
                  Container(
                    decoration: BoxDecoration(
                      color: _showDisabled ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _showDisabled ? Icons.visibility : Icons.visibility_off_outlined,
                        color: _showDisabled ? cs.primary : cs.onSurfaceVariant,
                        size: isNarrow ? 20 : 24,
                      ),
                      onPressed: () {
                        setState(() {
                          _showDisabled = !_showDisabled;
                          _applyFilters();
                          _applyCategorySearch(_categorySearchCtrl.text);
                          _applyTreatmentSearch(_treatmentSearchCtrl.text);
                        });
                      },
                      padding: EdgeInsets.all(isNarrow ? 8 : 12),
                      constraints: BoxConstraints(minWidth: isNarrow ? 40 : 48, minHeight: isNarrow ? 40 : 48),
                      tooltip: _showDisabled ? 'Ocultar desactivados' : 'Mostrar desactivados',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Filtro de categoría
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                ),
                padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 16, vertical: 4),
                child: DropdownButtonFormField<int?>(
                  initialValue: _treatmentCategoryFilter,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.filter_list, size: isNarrow ? 20 : 24),
                    contentPadding: EdgeInsets.symmetric(vertical: isNarrow ? 6 : 8),
                  ),
                  hint: Text(
                    'Filtrar por categoría',
                    style: TextStyle(fontSize: isNarrow ? 14 : null),
                  ),
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: isNarrow ? 14 : null,
                  ),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'Todas las categorías',
                        style: TextStyle(fontSize: isNarrow ? 14 : null),
                      ),
                    ),
                    ..._categoriasAll.map<DropdownMenuItem<int?>>((c) => DropdownMenuItem<int?>(
                      value: c['id'],
                      child: Text(
                        c['nombreCategoria'] ?? '-',
                        style: TextStyle(fontSize: isNarrow ? 14 : null),
                      ),
                    )),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _treatmentCategoryFilter = v;
                      _applyTreatmentSearch(_treatmentSearchCtrl.text);
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: _tratamientos.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No hay tratamientos', style: tt.bodyMedium)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 140), // espacio extra abajo para FAB
                    itemCount: _tratamientos.length,
                    itemBuilder: (context, index) => _buildTratamientoItem(_tratamientos[index] as Map<String, dynamic>, cs, tt, isNarrow),
                  ),
          ),
        ),
        SizedBox(height: isNarrow ? 8 : 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Total de ${_tratamientos.length} tratamientos registrados',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: isNarrow ? 11 : null,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SizedBox(height: isNarrow ? 72 : 60),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    final isNarrow = mq.size.width < 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: isNarrow
        ? FloatingActionButton(
            onPressed: () async {
              final tabIndex = _tabController.index;
              if (tabIndex == 0) {
                await _showCreateCategoriaDialog();
              } else {
                await _showCreateTratamientoDialog();
              }
            },
            child: const Icon(Icons.add),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            elevation: 4,
          )
        : FloatingActionButton.extended(
            onPressed: () async {
              final tabIndex = _tabController.index;
              if (tabIndex == 0) {
                await _showCreateCategoriaDialog();
              } else {
                await _showCreateTratamientoDialog();
              }
            },
            icon: const Icon(Icons.add),
            label: Text(_tabController.index == 0 ? 'Nueva Categoría' : 'Nuevo Tratamiento'),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            elevation: 4,
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: Column(
            children: [
              // TabBar con diseño moderno (mismo que Reportes/Tickets)
              Container(
                margin: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 50, vertical: 12),
                height: isNarrow ? 48 : 56,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(isNarrow ? 24 : 28),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(isNarrow ? 24 : 28),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  labelColor: cs.onPrimary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  dividerColor: Colors.transparent,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: isNarrow ? 14 : 16),
                  unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: isNarrow ? 14 : 16),
                  tabs: const [
                    Tab(text: 'Categorías'),
                    Tab(text: 'Tratamientos'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8.0 : 12.0),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _loading ? const Center(child: CircularProgressIndicator()) : _buildCategoriesTab(cs, tt, isNarrow),
                      _loading ? const Center(child: CircularProgressIndicator()) : _buildTreatmentsTab(cs, tt, isNarrow),
                    ],
                  ),
                ),
              ),
              if (_saving) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  // refresh helper
  Future<void> _refresh() async {
    await _loadAll();
  }
}
