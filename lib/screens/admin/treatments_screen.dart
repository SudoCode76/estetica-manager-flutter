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
  bool _loading = true;
  bool _loadingCreate = false;
  int? _selectedCategoriaId;

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
      setState(() {
        _categorias = cats;
        _tratamientos = trats;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando tratamientos: $e')));
    }
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
              Navigator.pop(context, true);
              setState(() => _loadingCreate = true);
              try {
                await _api.crearCategoria({'nombreCategoria': nombre});
                await _loadAll();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoría creada')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creando categoría: $e')));
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
      builder: (context) => AlertDialog(
        title: const Text('Crear tratamiento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 8),
              TextField(controller: precioCtrl, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              if (_categorias.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: selectedCatId,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: _categorias.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['nombreCategoria'] ?? '-'))).toList(),
                  onChanged: (v) {
                    selectedCatId = v;
                  },
                )
              else
                const Text('Crea primero una categoría'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final nombre = nombreCtrl.text.trim();
              final precio = precioCtrl.text.trim();
              if (nombre.isEmpty || precio.isEmpty) return;
              Navigator.pop(context, true);
              setState(() => _loadingCreate = true);
              try {
                final Map<String, dynamic> payload = {
                  'nombreTratamiento': nombre,
                  'precio': precio,
                  'estadoTratamiento': true,
                };
                if (selectedCatId != null) payload['categoria_tratamiento'] = selectedCatId;
                await _api.crearTratamiento(payload);
                await _loadAll();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tratamiento creado')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creando tratamiento: $e')));
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

  Widget _buildCategoryChip(Map<String, dynamic> c, ColorScheme cs, TextTheme tt) {
    final bool selected = _selectedCategoriaId == c['id'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: ChoiceChip(
        label: Text(c['nombreCategoria'] ?? '-', style: tt.bodyMedium?.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
        selected: selected,
        onSelected: (v) async {
          setState(() => _selectedCategoriaId = v ? c['id'] : null);
          final tr = await _api.getTratamientos(categoriaId: v ? c['id'] : null);
          setState(() => _tratamientos = tr);
        },
        selectedColor: cs.primaryContainer,
        backgroundColor: cs.surface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          itemBuilder: (context, index) => _buildCategoryChip(_categorias[index] as Map<String, dynamic>, cs, tt),
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
          final c = _categorias[index];
          final selected = _selectedCategoriaId == c['id'];
          return ListTile(
            title: Text(c['nombreCategoria'] ?? '-', style: tt.bodyMedium),
            selected: selected,
            selectedColor: cs.primary,
            onTap: () async {
              setState(() => _selectedCategoriaId = c['id']);
              final tr = await _api.getTratamientos(categoriaId: c['id']);
              setState(() => _tratamientos = tr);
            },
          );
        },
      ),
    );
  }

  Widget _buildTratamientoItem(Map<String, dynamic> t, ColorScheme cs, TextTheme tt) {
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
              ],
            ),
          ],
        ),
      ),
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
              // Header with actions (responsive)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isVeryNarrow = constraints.maxWidth < 420;
                  final buttonStyle = FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );

                  if (isVeryNarrow) {
                    // Mobile: stack title and full-width buttons
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Categorías', style: tt.titleMedium),
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

                  // Wider screens: show title left and compact buttons to the right
                  return Row(
                    children: [
                      Text('Categorías', style: tt.titleMedium),
                      const Spacer(),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: FilledButton.icon(
                          style: buttonStyle,
                          onPressed: _showCreateCategoriaDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Nueva categoría'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: FilledButton.icon(
                          style: buttonStyle,
                          onPressed: _showCreateTratamientoDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Nuevo tratamiento'),
                        ),
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
                                          itemBuilder: (context, index) => _buildTratamientoItem(_tratamientos[index] as Map<String, dynamic>, cs, tt),
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
                                          itemBuilder: (context, index) => _buildTratamientoItem(_tratamientos[index] as Map<String, dynamic>, cs, tt),
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
