import 'package:flutter/material.dart';
import 'package:app_estetica/services/api_service.dart';

class TreatmentsScreen extends StatefulWidget {
  const TreatmentsScreen({Key? key}) : super(key: key);

  @override
  State<TreatmentsScreen> createState() => _TreatmentsScreenState();
}

class _TreatmentsScreenState extends State<TreatmentsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _categorias = [];
  List<dynamic> _tratamientos = [];
  List<dynamic> _categoriasAll = [];
  List<dynamic> _tratamientosAll = [];
  bool _loading = true;
  bool _loadingCreate = false;
  int? _selectedCategoriaId;
  bool _showDisabled = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final cats = await _api.getCategorias();
      final trats = await _api.getTratamientos();
      // Guardar listas originales
      _categoriasAll = cats;
      _tratamientosAll = trats;
      // Aplicar filtro por estado (por defecto true)
      _applyFilters(_showDisabled);
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando tratamientos: $e')));
    }
  }

  void _applyFilters(bool showDisabled) {
    if (showDisabled) {
      _categorias = List<dynamic>.from(_categoriasAll);
      _tratamientos = List<dynamic>.from(_tratamientosAll);
    } else {
      _categorias = _categoriasAll.where((c) => c['estadoCategoria'] == true || c['estadoCategoria'] == null).toList();
      _tratamientos = _tratamientosAll.where((t) => t['estadoTratamiento'] == true || t['estadoTratamiento'] == null).toList();
    }
  }

  // Filtra una lista de tratamientos según el flag _showDisabled
  List<dynamic> _filterTratamientosList(List<dynamic> tr) {
    if (_showDisabled) return List<dynamic>.from(tr);

    // Build set of active category ids
    final activeCatIds = _categoriasAll
        .where((c) => c['estadoCategoria'] == true || c['estadoCategoria'] == null)
        .map((c) => c['id'])
        .toSet();

    return tr.where((t) {
      final bool tratActivo = t['estadoTratamiento'] == true || t['estadoTratamiento'] == null;
      if (!tratActivo) return false;
      // Si el tratamiento tiene categoría, comprobar que la categoría esté activa
      final cat = t['categoria_tratamiento'];
      if (cat == null) return true;
      final catId = (cat is Map) ? cat['id'] : cat;
      if (catId == null) return true;
      return activeCatIds.contains(catId);
    }).toList();
  }

  Future<void> _refresh() async => await _loadAll();

  Future<void> _showCreateCategoriaDialog() async {
    final TextEditingController nombreCtrl = TextEditingController();
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear categoría'),
        content: TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final nombre = nombreCtrl.text.trim();
              if (nombre.isEmpty) return;
              // buscar existencia (case-insensitive)
              final existing = _categoriasAll.firstWhere(
                (c) => (c['nombreCategoria']?.toString().trim().toLowerCase() ?? '') == nombre.toLowerCase(),
                orElse: () => null,
              );
              Navigator.pop(context, true);
              setState(() => _loadingCreate = true);
              try {
                if (existing != null) {
                  final bool estado = existing['estadoCategoria'] == true;
                  if (estado) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La categoría ya existe')));
                  } else {
                    // ofrecer reactivar
                    final react = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                      title: const Text('Categoría desactivada'),
                      content: const Text('La categoría ya existe pero está desactivada. ¿Deseas reactivarla?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
                      ],
                    ));
                    if (react == true) {
                      await _api.updateCategoria(existing['documentId'] ?? existing['id'].toString(), {'estadoCategoria': true});
                      await _loadAll();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoría reactivada')));
                    }
                  }
                } else {
                  await _api.crearCategoria({'nombreCategoria': nombre});
                  await _loadAll();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoría creada')));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creando/activando categoría: $e')));
              } finally {
                setState(() => _loadingCreate = false);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateTratamientoDialog() async {
    final TextEditingController nombreCtrl = TextEditingController();
    final TextEditingController precioCtrl = TextEditingController();
    int? selectedCatId = _categorias.isNotEmpty ? _categorias.first['id'] : null;

    await showDialog<bool>(
      context: context,
      builder: (context) {
        final screenW = MediaQuery.of(context).size.width;
        final isNarrowDialog = screenW < 420;
        final maxDialogWidth = isNarrowDialog ? screenW - 32 : 520.0;

        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: isNarrowDialog ? 16 : 48, vertical: 24),
          title: const Text('Crear tratamiento'),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxDialogWidth),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: precioCtrl,
                    decoration: const InputDecoration(labelText: 'Precio'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  if (_categorias.isNotEmpty)
                    // Wrap dropdown in SizedBox to avoid weird overflow inside dialog
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedCatId,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: _categorias
                            .map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['nombreCategoria'] ?? '-')))
                            .toList(),
                        onChanged: (v) {
                          selectedCatId = v;
                        },
                      ),
                    )
                  else
                    const Align(alignment: Alignment.centerLeft, child: Text('Crea primero una categoría')),
                ],
              ),
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: isNarrowDialog ? 16 : 8, vertical: 8),
          actions: isNarrowDialog
              ? [
                  // For narrow screens show stacked full-width buttons
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final nombre = nombreCtrl.text.trim();
                        final precio = precioCtrl.text.trim();
                        if (nombre.isEmpty || precio.isEmpty) return;
                        Navigator.pop(context, true);
                        setState(() => _loadingCreate = true);
                        try {
                          // comprobar existencia (name + categoria)
                          final nombreLower = nombre.toLowerCase();
                          final existing = _tratamientosAll.firstWhere(
                            (t) {
                              final tname = (t['nombreTratamiento']?.toString().trim().toLowerCase()) ?? '';
                              final tcat = (t['categoria_tratamiento'] is Map) ? t['categoria_tratamiento']['id'] : t['categoria_tratamiento'];
                              return tname == nombreLower && (selectedCatId == null ? true : (tcat == selectedCatId));
                            },
                            orElse: () => null,
                          );
                          if (existing != null) {
                            final bool estado = existing['estadoTratamiento'] == true;
                            if (estado) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El tratamiento ya existe')));
                            } else {
                              // ofrecer reactivar
                              final react = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                                title: const Text('Tratamiento desactivado'),
                                content: const Text('El tratamiento ya existe pero está desactivado. ¿Deseas reactivarlo?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
                                ],
                              ));
                              if (react == true) {
                                await _api.updateTratamiento(existing['documentId'] ?? existing['id'].toString(), {'estadoTratamiento': true});
                                await _loadAll();
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tratamiento reactivado')));
                              }
                            }
                          } else {
                            final Map<String, dynamic> payload = {
                              'nombreTratamiento': nombre,
                              'precio': precio,
                              'estadoTratamiento': true,
                            };
                            if (selectedCatId != null) payload['categoria_tratamiento'] = selectedCatId;
                            await _api.crearTratamiento(payload);
                            await _loadAll();
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tratamiento creado')));
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creando tratamiento: $e')));
                        } finally {
                          setState(() => _loadingCreate = false);
                        }
                      },
                      child: const Text('Crear'),
                    ),
                  ),
                ]
              : [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  FilledButton(
                    onPressed: () async {
                      final nombre = nombreCtrl.text.trim();
                      final precio = precioCtrl.text.trim();
                      if (nombre.isEmpty || precio.isEmpty) return;
                      Navigator.pop(context, true);
                      setState(() => _loadingCreate = true);
                      try {
                        // comprobar existencia (name + categoria)
                        final nombreLower = nombre.toLowerCase();
                        final existing = _tratamientosAll.firstWhere(
                          (t) {
                            final tname = (t['nombreTratamiento']?.toString().trim().toLowerCase()) ?? '';
                            final tcat = (t['categoria_tratamiento'] is Map) ? t['categoria_tratamiento']['id'] : t['categoria_tratamiento'];
                            return tname == nombreLower && (selectedCatId == null ? true : (tcat == selectedCatId));
                          },
                          orElse: () => null,
                        );
                        if (existing != null) {
                          final bool estado = existing['estadoTratamiento'] == true;
                          if (estado) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El tratamiento ya existe')));
                          } else {
                            // ofrecer reactivar
                            final react = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                              title: const Text('Tratamiento desactivado'),
                              content: const Text('El tratamiento ya existe pero está desactivado. ¿Deseas reactivarlo?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
                              ],
                            ));
                            if (react == true) {
                              await _api.updateTratamiento(existing['documentId'] ?? existing['id'].toString(), {'estadoTratamiento': true});
                              await _loadAll();
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tratamiento reactivado')));
                            }
                          }
                        } else {
                          final Map<String, dynamic> payload = {
                            'nombreTratamiento': nombre,
                            'precio': precio,
                            'estadoTratamiento': true,
                          };
                          if (selectedCatId != null) payload['categoria_tratamiento'] = selectedCatId;
                          await _api.crearTratamiento(payload);
                          await _loadAll();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tratamiento creado')));
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creando tratamiento: $e')));
                      } finally {
                        setState(() => _loadingCreate = false);
                      }
                    },
                    child: const Text('Crear'),
                  ),
                ],
        );
      },
    );
  }

  Widget _buildCategoryChip(Map<String, dynamic> c, ColorScheme cs, TextTheme tt) {
    final bool selected = _selectedCategoriaId == c['id'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: GestureDetector(
        onLongPress: () async {
          // Show options for this category on mobile (editar / toggle estado)
          final action = await showModalBottomSheet<String?>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Editar'),
                    onTap: () => Navigator.pop(ctx, 'editar'),
                  ),
                  ListTile(
                    leading: Icon(c['estadoCategoria'] == true ? Icons.toggle_off : Icons.toggle_on),
                    title: Text(c['estadoCategoria'] == true ? 'Desactivar' : 'Activar'),
                    onTap: () => Navigator.pop(ctx, 'toggle'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: const Text('Cancelar'),
                    onTap: () => Navigator.pop(ctx, null),
                  ),
                ],
              ),
            ),
          );
          if (action == 'editar') {
            await _showEditCategoriaDialog(c);
          } else if (action == 'toggle') {
            await _toggleCategoriaEstado(c);
          }
        },
        child: ChoiceChip(
          label: Text(c['nombreCategoria'] ?? '-', style: tt.bodyMedium?.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
          selected: selected,
          onSelected: (v) async {
            setState(() => _selectedCategoriaId = v ? c['id'] : null);
            final tr = await _api.getTratamientos(categoriaId: v ? c['id'] : null);
            setState(() => _tratamientos = _filterTratamientosList(tr));
          },
          selectedColor: cs.primaryContainer,
          backgroundColor: cs.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildCategoryList(ColorScheme cs, TextTheme tt, bool isNarrow) {
    if (_categorias.isEmpty) return const SizedBox.shrink();

    if (isNarrow) {
      return SizedBox(
        height: 64,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _categorias.length,
          itemBuilder: (context, index) {
            final c = _categorias[index] as Map<String, dynamic>;
            // Show chip plus an explicit menu button for mobile
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCategoryChip(c, cs, tt),
                  const SizedBox(width: 4),
                  // Small menu button visible on mobile for discoverability
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.more_vert, size: 18),
                      onPressed: () async {
                        final action = await showModalBottomSheet<String?>(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text('Editar'),
                                  onTap: () => Navigator.pop(ctx, 'editar'),
                                ),
                                ListTile(
                                  leading: Icon(c['estadoCategoria'] == true ? Icons.toggle_off : Icons.toggle_on),
                                  title: Text(c['estadoCategoria'] == true ? 'Desactivar' : 'Activar'),
                                  onTap: () => Navigator.pop(ctx, 'toggle'),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.close),
                                  title: const Text('Cancelar'),
                                  onTap: () => Navigator.pop(ctx, null),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (action == 'editar') {
                          await _showEditCategoriaDialog(c);
                        } else if (action == 'toggle') {
                          await _toggleCategoriaEstado(c);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // Side list for wider screens
    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _categorias.length,
        separatorBuilder: (_, __) => const Divider(height: 0.5),
        itemBuilder: (context, index) {
          final c = _categorias[index] as Map<String, dynamic>;
          final selected = _selectedCategoriaId == c['id'];
          return _buildCategoryListItem(c, tt, selected);
        },
      ),
    );
  }

  Widget _buildTratamientoItem(Map<String, dynamic> t, ColorScheme cs, TextTheme tt, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['nombreTratamiento'] ?? '-', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Precio: \$${t['precio'] ?? '-'}', style: tt.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  t['estadoTratamiento'] == true ? Icons.check_circle : Icons.block,
                  color: t['estadoTratamiento'] == true ? Colors.green : cs.error,
                  size: 22,
                ),
                const SizedBox(height: 8),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'editar') {
                      await _showEditTratamientoDialog(t);
                    } else if (value == 'toggle') {
                      await _toggleTratamientoEstado(t);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'editar', child: Text('Editar')),
                    PopupMenuItem(value: 'toggle', child: Text((t['estadoTratamiento'] == true) ? 'Desactivar' : 'Activar')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditTratamientoDialog(Map<String, dynamic> t) async {
    final TextEditingController nombreCtrl = TextEditingController(text: t['nombreTratamiento'] ?? '');
    final TextEditingController precioCtrl = TextEditingController(text: t['precio']?.toString() ?? '');
    int? selectedCatId = (t['categoria_tratamiento'] is Map) ? t['categoria_tratamiento']['id'] : t['categoria_tratamiento'];

    await showDialog<bool>(
      context: context,
      builder: (context) {
        final screenW = MediaQuery.of(context).size.width;
        final isNarrowDialog = screenW < 420;
        final maxDialogWidth = isNarrowDialog ? screenW - 32 : 520.0;
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: isNarrowDialog ? 16 : 48, vertical: 24),
          title: const Text('Editar tratamiento'),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxDialogWidth),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 12),
                  TextField(controller: precioCtrl, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  if (_categoriasAll.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedCatId,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: _categoriasAll.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['nombreCategoria'] ?? '-'))).toList(),
                        onChanged: (v) => selectedCatId = v,
                      ),
                    )
                  else
                    const Align(alignment: Alignment.centerLeft, child: Text('No hay categorías')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () async {
              final nombre = nombreCtrl.text.trim();
              final precio = precioCtrl.text.trim();
              if (nombre.isEmpty || precio.isEmpty) return;
              Navigator.pop(context, true);
              setState(() => _loadingCreate = true);
              try {
                final payload = {'nombreTratamiento': nombre, 'precio': precio, 'categoria_tratamiento': selectedCatId, 'estadoTratamiento': t['estadoTratamiento'] ?? true};
                await _api.updateTratamiento(t['documentId'] ?? t['id'].toString(), payload);
                await _loadAll();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tratamiento actualizado')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error actualizando tratamiento: $e')));
              } finally {
                setState(() => _loadingCreate = false);
              }
            }, child: const Text('Guardar')),
          ],
        );
      }
    );
  }

  Future<void> _toggleTratamientoEstado(Map<String, dynamic> t) async {
    final bool newEstado = !(t['estadoTratamiento'] == true);
    final docId = t['documentId'] ?? t['id']?.toString();
    if (docId == null) return;
    try {
      setState(() => _loadingCreate = true);
      final payload = {'estadoTratamiento': newEstado};
      await _api.updateTratamiento(docId, payload);
      await _loadAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newEstado ? 'Tratamiento activado' : 'Tratamiento desactivado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error actualizando estado: $e')));
    } finally {
      setState(() => _loadingCreate = false);
    }
  }

  // Similar actions for categories: build list items with popup menu
  Widget _buildCategoryListItem(Map<String, dynamic> c, TextTheme tt, bool selected) {
    return ListTile(
      title: Text(c['nombreCategoria'] ?? '-', style: tt.bodyMedium),
      selected: selected,
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'editar') {
            await _showEditCategoriaDialog(c);
          } else if (v == 'toggle') {
            await _toggleCategoriaEstado(c);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'editar', child: Text('Editar')),
          PopupMenuItem(value: 'toggle', child: Text((c['estadoCategoria'] == true) ? 'Desactivar' : 'Activar')),
        ],
      ),
      onTap: () async {
        setState(() => _selectedCategoriaId = c['id']);
        final tr = await _api.getTratamientos(categoriaId: c['id']);
        setState(() => _tratamientos = _filterTratamientosList(tr));
      },
    );
  }

  Future<void> _showEditCategoriaDialog(Map<String, dynamic> c) async {
    final TextEditingController nombreCtrl = TextEditingController(text: c['nombreCategoria'] ?? '');
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar categoría'),
        content: TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            final nombre = nombreCtrl.text.trim();
            if (nombre.isEmpty) return;
            Navigator.pop(context, true);
            setState(() => _loadingCreate = true);
            try {
              final payload = {'nombreCategoria': nombre, 'estadoCategoria': c['estadoCategoria'] ?? true};
              await _api.updateCategoria(c['documentId'] ?? c['id'].toString(), payload);
              await _loadAll();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoría actualizada')));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error actualizando categoría: $e')));
            } finally {
              setState(() => _loadingCreate = false);
            }
          }, child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<void> _toggleCategoriaEstado(Map<String, dynamic> c) async {
    final bool newEstado = !(c['estadoCategoria'] == true);
    final docId = c['documentId'] ?? c['id']?.toString();
    if (docId == null) return;
    try {
      setState(() => _loadingCreate = true);
      final payload = {'estadoCategoria': newEstado};
      await _api.updateCategoria(docId, payload);
      await _loadAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newEstado ? 'Categoría activada' : 'Categoría desactivada')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error actualizando estado: $e')));
    } finally {
      setState(() => _loadingCreate = false);
    }
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
              // Header with actions (responsive)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isVeryNarrow = constraints.maxWidth < 420;
                  final buttonStyle = FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );

                  if (isVeryNarrow) {
                    // Mobile: stack title, toggle and full-width buttons
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('Categorías', style: tt.titleMedium)),
                            Tooltip(
                              message: _showDisabled ? 'Ocultar desactivados' : 'Mostrar desactivados',
                              child: IconButton(
                                icon: Icon(_showDisabled ? Icons.visibility : Icons.visibility_off),
                                onPressed: () {
                                  setState(() {
                                    _showDisabled = !_showDisabled;
                                    _applyFilters(_showDisabled);
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: buttonStyle,
                            onPressed: _showCreateCategoriaDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Nueva categoría'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: buttonStyle,
                            onPressed: _showCreateTratamientoDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Nuevo tratamiento'),
                          ),
                        ),
                      ],
                    );
                  }

                  // Wider screens: show title left, toggle, and compact buttons to the right
                  // Pero usamos Wrap para evitar overflow en pantallas medianas
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Categorías', style: tt.titleMedium),
                          const Spacer(),
                          // Toggle show disabled
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Mostrar desactivados', style: tt.bodySmall),
                              const SizedBox(width: 6),
                              Switch(
                                value: _showDisabled,
                                onChanged: (v) {
                                  setState(() {
                                    _showDisabled = v;
                                    _applyFilters(_showDisabled);
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Botones en Wrap para que se acomoden automáticamente
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            style: buttonStyle,
                            onPressed: _showCreateCategoriaDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nueva categoría'),
                          ),
                          FilledButton.icon(
                            style: buttonStyle,
                            onPressed: _showCreateTratamientoDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nuevo tratamiento'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Body responsive
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : isNarrow
                        ? Column(
                            children: [
                              // categories as horizontal chips
                              _buildCategoryList(cs, tt, true),
                              const SizedBox(height: 8),
                              // treatments list
                              Expanded(
                                child: Card(
                                  child: _tratamientos.isEmpty
                                      ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No hay tratamientos', style: tt.bodyMedium)))
                                      : ListView.builder(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          itemCount: _tratamientos.length,
                                          itemBuilder: (context, index) => _buildTratamientoItem(_tratamientos[index] as Map<String, dynamic>, cs, tt, index),
                                        ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              // Left: categories (fixed width)
                              Flexible(
                                flex: 3,
                                child: SizedBox(
                                  height: double.infinity,
                                  child: _buildCategoryList(cs, tt, false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Right: tratamientos
                              Flexible(
                                flex: 7,
                                child: Card(
                                  child: _tratamientos.isEmpty
                                      ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No hay tratamientos', style: tt.bodyMedium)))
                                      : ListView.builder(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          itemCount: _tratamientos.length,
                                          itemBuilder: (context, index) => _buildTratamientoItem(_tratamientos[index] as Map<String, dynamic>, cs, tt, index),
                                        ),
                                ),
                              ),
                            ],
                          ),
              ),

              if (_loadingCreate) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
