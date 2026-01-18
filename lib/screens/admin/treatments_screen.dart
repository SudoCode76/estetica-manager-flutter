import 'package:flutter/material.dart';
import 'package:app_estetica/services/api_service.dart';

class TreatmentsScreen extends StatefulWidget {
  const TreatmentsScreen({Key? key}) : super(key: key);

  @override
  State<TreatmentsScreen> createState() => _TreatmentsScreenState();
}

class _TreatmentsScreenState extends State<TreatmentsScreen> {
  final ApiService _api = ApiService();

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
  }

  @override
  void dispose() {
    _categorySearchCtrl.dispose();
    _treatmentSearchCtrl.dispose();
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
  Widget _buildCategoryListItem(Map<String, dynamic> c, TextTheme tt) {
    final int count = _countTratamientosPorCategoria(c['id']);
    return ListTile(
      title: Text(c['nombreCategoria'] ?? '-', style: tt.bodyMedium),
      subtitle: Text('$count tratamientos', style: tt.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showEditCategoriaDialog(c)),
          IconButton(icon: Icon((c['estadoCategoria'] == true) ? Icons.toggle_on : Icons.toggle_off, size: 22, color: (c['estadoCategoria'] == true) ? Colors.green : null), onPressed: () => _toggleCategoriaEstado(c)),
        ],
      ),
      onTap: () async {
        setState(() => _selectedCategoriaId = c['id']);
        final tr = await _api.getTratamientos(categoriaId: c['id']);
        setState(() => _tratamientos = _filterTratamientosList(tr));
      },
    );
  }

  Widget _buildCategoriesTab(ColorScheme cs, TextTheme tt, bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
            FilledButton.icon(onPressed: _showCreateCategoriaDialog, icon: const Icon(Icons.add), label: const Text('Nueva')),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: _categorias.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No hay categorías', style: tt.bodyMedium)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _categorias.length,
                    separatorBuilder: (_, __) => const Divider(height: 0.5),
                    itemBuilder: (context, index) {
                      final c = _categorias[index] as Map<String, dynamic>;
                      return _buildCategoryListItem(c, tt);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTratamientoItem(Map<String, dynamic> t, ColorScheme cs, TextTheme tt) {
    final bool activo = t['estadoTratamiento'] == true || t['estadoTratamiento'] == null;
    final String categoriaNombre = _getCategoriaNombreFromTratamiento(t);
    final String precio = t['precio']?.toString() ?? '-';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: activo ? Colors.green.withAlpha(31) : cs.error.withAlpha(31),
        child: Icon(activo ? Icons.check : Icons.block, color: activo ? Colors.green : cs.error, size: 18),
      ),
      title: Text(t['nombreTratamiento'] ?? '-', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 4), Text('Categoría: $categoriaNombre', style: tt.bodySmall), const SizedBox(height: 2), Text('Precio: \$$precio', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))]),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'editar') await _showEditTratamientoDialog(t);
          if (v == 'toggle') await _toggleTratamientoEstado(t);
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'editar', child: Text('Editar')),
          PopupMenuItem(value: 'toggle', child: Text((t['estadoTratamiento'] == true) ? 'Desactivar' : 'Activar')),
        ],
      ),
      onTap: () async => await _showEditTratamientoDialog(t),
    );
  }

  Widget _buildTreatmentsTab(ColorScheme cs, TextTheme tt, bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
            FilledButton.icon(onPressed: _showCreateTratamientoDialog, icon: const Icon(Icons.add), label: const Text('Nuevo')),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: _tratamientos.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No hay tratamientos', style: tt.bodyMedium)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _tratamientos.length,
                    itemBuilder: (context, index) => _buildTratamientoItem(_tratamientos[index] as Map<String, dynamic>, cs, tt),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    final isNarrow = mq.size.width < 600;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              DefaultTabController(
                length: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TabBar(
                        labelColor: cs.onPrimaryContainer,
                        unselectedLabelColor: cs.onSurfaceVariant,
                        indicator: BoxDecoration(borderRadius: BorderRadius.circular(8), color: cs.primaryContainer),
                        tabs: const [Tab(text: 'Categorías'), Tab(text: 'Tratamientos')],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: mq.size.height * 0.75,
                      child: TabBarView(
                        children: [
                          _loading ? const Center(child: CircularProgressIndicator()) : _buildCategoriesTab(cs, tt, isNarrow),
                          _loading ? const Center(child: CircularProgressIndicator()) : _buildTreatmentsTab(cs, tt, isNarrow),
                        ],
                      ),
                    ),
                  ],
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
