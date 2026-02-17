import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_estetica/repositories/cliente_repository.dart';
import 'package:app_estetica/widgets/create_client_dialog.dart';

class SelectClientScreen extends StatefulWidget {
  final int sucursalId;
  const SelectClientScreen({super.key, required this.sucursalId});

  @override
  State<SelectClientScreen> createState() => _SelectClientScreenState();
}

class _SelectClientScreenState extends State<SelectClientScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> clients = [];
  bool isLoading = true;
  String? loadError;
  String query = '';
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClients();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadClients([String? q]) async {
    setState(() {
      isLoading = true;
      loadError = null;
    });
    try {
      final data = await Provider.of<ClienteRepository>(
        context,
        listen: false,
      ).searchClientes(sucursalId: widget.sucursalId, query: q);
      setState(() {
        clients = data;
        isLoading = false;
      });
    } catch (e) {
      final msg = e.toString();
      if (kDebugMode) debugPrint('SelectClientScreen: error: $msg');
      setState(() {
        loadError = msg;
        clients = [];
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar clientes: $msg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openCreateClient() async {
    final res = await CreateClientDialog.show(context, widget.sucursalId);
    if (res != null) {
      if (mounted) Navigator.pop(context, res);
    } else {
      await _loadClients(query);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => query = v);
      _loadClients(v.trim().isEmpty ? null : v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar cliente'),
        elevation: 0,
        backgroundColor: cs.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _openCreateClient,
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Registrar nuevo cliente',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, apellido o teléfono',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Builder(
                builder: (context) {
                  if (isLoading) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: cs.primary),
                          const SizedBox(height: 12),
                          Text(
                            'Cargando clientes...',
                            style: tt.bodyLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (loadError != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 56,
                              color: cs.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error al cargar clientes',
                              style: tt.titleLarge?.copyWith(
                                color: cs.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(loadError!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => _loadClients(query),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (clients.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            size: 64,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            query.isEmpty
                                ? 'No hay clientes en esta sucursal'
                                : 'No se encontraron clientes',
                            style: tt.titleLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (query.isEmpty)
                            FilledButton.tonalIcon(
                              onPressed: _openCreateClient,
                              icon: const Icon(Icons.person_add_rounded),
                              label: const Text('Registrar cliente'),
                            ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: clients.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final c = clients[idx] as Map<String, dynamic>;
                      final nombre =
                          ('${c['nombreCliente'] ?? ''} ${c['apellidoCliente'] ?? ''}')
                              .trim();
                      final telefono = c['telefono']?.toString() ?? '';
                      final initials = nombre.isNotEmpty
                          ? nombre[0].toUpperCase()
                          : '?';

                      return ListTile(
                        onTap: () => Navigator.pop(context, c),
                        leading: CircleAvatar(
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            initials,
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(nombre.isNotEmpty ? nombre : 'Sin nombre'),
                        subtitle: Text(
                          telefono.isNotEmpty ? telefono : 'Sin teléfono',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        tileColor: cs.surfaceContainerHighest.withValues(
                          alpha: 0.02,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
