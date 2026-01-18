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
  Widget _buildCategoryListItem(Map<String, dynamic> c, ColorScheme cs, TextTheme tt) {
    final int count = _countTratamientosPorCategoria(c['id']);
    final bool selected = _selectedCategoriaId == c['id'];
    final bool activo = c['estadoCategoria'] == true || c['estadoCategoria'] == null;
    final double op = activo ? 1.0 : 0.6;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: selected ? Border.all(color: cs.primaryContainer, width: 2) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14),
        child: Opacity(
          opacity: op,
          child: Row(
            children: [
              Expanded(child: Text(c['nombreCategoria'] ?? '-', style: tt.bodyLarge)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      // Edit
                      Container(
                        decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(Icons.edit, size: 18, color: cs.onSurfaceVariant),
                          onPressed: () => _showEditCategoriaDialog(c),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Trash = desactivar OR restore = reactivar
                      Container(
                        decoration: BoxDecoration(color: activo ? cs.errorContainer : cs.primaryContainer, shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(activo ? Icons.delete : Icons.restore, size: 18, color: activo ? cs.onErrorContainer : cs.onPrimaryContainer),
                          onPressed: () => _toggleCategoriaEstado(c),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('$count tratamientos', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      if (!activo) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                          child: Text('Desactivada', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesTab(ColorScheme cs, TextTheme tt, bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 480;
          if (narrow) {
            return Column(
              children: [
                TextField(
                  controller: _categorySearchCtrl,
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Buscar categorías', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      tooltip: _showDisabled ? 'Ocultar desactivados' : 'Mostrar desactivados',
                      icon: Icon(_showDisabled ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _showDisabled = !_showDisabled;
                          _applyFilters();
                          _applyCategorySearch(_categorySearchCtrl.text);
                          _applyTreatmentSearch(_treatmentSearchCtrl.text);
                        });
                      },
                    ),
                    const Spacer(),
                    const SizedBox(width: 56),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _categorySearchCtrl,
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Buscar categorías', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _showDisabled ? 'Ocultar desactivados' : 'Mostrar desactivados',
                icon: Icon(_showDisabled ? Icons.visibility : Icons.visibility_off),
                onPressed: () {
                  setState(() {
                    _showDisabled = !_showDisabled;
                    _applyFilters();
                    _applyCategorySearch(_categorySearchCtrl.text);
                    _applyTreatmentSearch(_treatmentSearchCtrl.text);
                  });
                },
              ),
              const SizedBox(width: 8),
              // dejamos el botones Añadir solo como espacio (FAB abajo)
              const SizedBox(width: 56),
            ],
          );
        }),
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
                      return _buildCategoryListItem(c, cs, tt);
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text('Total de ${_categorias.length} categorías registradas', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
        const SizedBox(height: 60), // espacio para FAB
      ],
    );
  }

  Widget _buildTratamientoItem(Map<String, dynamic> t, ColorScheme cs, TextTheme tt) {
    final bool activoTrat = t['estadoTratamiento'] == true || t['estadoTratamiento'] == null;
    final String categoriaNombre = _getCategoriaNombreFromTratamiento(t);
    final String precio = t['precio']?.toString() ?? '-';

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;

        final infoSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t['nombreTratamiento'] ?? '-',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Categoría: $categoriaNombre',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text('\$$precio', style: tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        );

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
              child: IconButton(
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                padding: const EdgeInsets.all(6),
                icon: Icon(Icons.edit, size: 18, color: cs.onSurfaceVariant),
                onPressed: () => _showEditTratamientoDialog(t),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(color: activoTrat ? cs.errorContainer : cs.primaryContainer, shape: BoxShape.circle),
              child: IconButton(
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                padding: const EdgeInsets.all(6),
                icon: Icon(activoTrat ? Icons.delete : Icons.restore, size: 18, color: activoTrat ? cs.onErrorContainer : cs.onPrimaryContainer),
                onPressed: () => _toggleTratamientoEstado(t),
              ),
            ),
          ],
        );

        final statusChip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: activoTrat ? cs.primary.withAlpha(25) : cs.error.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(activoTrat ? 'Activo' : 'Inactivo', style: tt.bodySmall?.copyWith(color: activoTrat ? cs.primary : cs.error)),
        );

        final double opTrat = activoTrat ? 1.0 : 0.6;

        return Opacity(
          opacity: opTrat,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14),
              child: narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        infoSection,
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            actions,
                            const SizedBox(width: 12),
                            statusChip,
                            if (!activoTrat)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12)),
                                  child: Text('Desactivado', style: tt.bodySmall?.copyWith(color: cs.onSurface)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: infoSection),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            actions,
                            const SizedBox(height: 8),
                            statusChip,
                            if (!activoTrat)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12)),
                                  child: Text('Desactivado', style: tt.bodySmall?.copyWith(color: cs.onSurface)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTreatmentsTab(ColorScheme cs, TextTheme tt, bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          if (narrow) {
            return Column(
              children: [
                TextField(
                  controller: _treatmentSearchCtrl,
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Buscar tratamientos', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        isExpanded: true,
                        initialValue: _treatmentCategoryFilter,
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                          ..._categoriasAll.map<DropdownMenuItem<int?>>((c) => DropdownMenuItem<int?>(value: c['id'], child: Text(c['nombreCategoria'] ?? '-'))),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _treatmentCategoryFilter = v;
                            _applyTreatmentSearch(_treatmentSearchCtrl.text);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // icono mostrar/ocultar desactivados
                    IconButton(
                      tooltip: _showDisabled ? 'Ocultar desactivados' : 'Mostrar desactivados',
                      icon: Icon(_showDisabled ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _showDisabled = !_showDisabled;
                          _applyFilters();
                          _applyCategorySearch(_categorySearchCtrl.text);
                          _applyTreatmentSearch(_treatmentSearchCtrl.text);
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const SizedBox(width: 56),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _treatmentSearchCtrl,
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Buscar tratamientos', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: _treatmentCategoryFilter,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                    ..._categoriasAll.map<DropdownMenuItem<int?>>((c) => DropdownMenuItem<int?>(value: c['id'], child: Text(c['nombreCategoria'] ?? '-'))),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _treatmentCategoryFilter = v;
                      _applyTreatmentSearch(_treatmentSearchCtrl.text);
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _showDisabled ? 'Ocultar desactivados' : 'Mostrar desactivados',
                icon: Icon(_showDisabled ? Icons.visibility : Icons.visibility_off),
                onPressed: () {
                  setState(() {
                    _showDisabled = !_showDisabled;
                    _applyFilters();
                    _applyCategorySearch(_categorySearchCtrl.text);
                    _applyTreatmentSearch(_treatmentSearchCtrl.text);
                  });
                },
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 56),
            ],
          );
        }),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: _tratamientos.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No hay tratamientos', style: tt.bodyMedium)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 140), // espacio extra abajo para FAB
                    itemCount: _tratamientos.length,
                    itemBuilder: (context, index) => _buildTratamientoItem(_tratamientos[index] as Map<String, dynamic>, cs, tt),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text('Total de ${_tratamientos.length} tratamientos registrados', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
        const SizedBox(height: 60),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final tabIndex = _tabController.index;
          if (tabIndex == 0) {
            await _showCreateCategoriaDialog();
          } else {
            await _showCreateTratamientoDialog();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        elevation: 6,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 16.0),
            child: Column(
              children: [
                // Control segmentado personalizado (pill)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(32)),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: List.generate(2, (i) {
                        final bool selected = i == _tabController.index;
                        final String label = i == 0 ? 'Categorías' : 'Tratamientos';
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _tabController.animateTo(i),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selected ? Theme.of(context).cardColor : Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Center(child: Text(label, style: selected ? tt.bodyMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w600) : tt.bodyMedium)),
                                ),
                                const SizedBox(height: 6),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 3,
                                  width: selected ? 28 : 0,
                                  decoration: BoxDecoration(color: selected ? cs.primary : Colors.transparent, borderRadius: BorderRadius.circular(2)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _loading ? const Center(child: CircularProgressIndicator()) : _buildCategoriesTab(cs, tt, isNarrow),
                      _loading ? const Center(child: CircularProgressIndicator()) : _buildTreatmentsTab(cs, tt, isNarrow),
                    ],
                  ),
                ),
                if (_saving) const LinearProgressIndicator(),
              ],
            ),
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
