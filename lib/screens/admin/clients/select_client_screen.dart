import 'dart:async';

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
  static const int _pageSize = 20;

  List<dynamic> clients = [];
  bool isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? loadError;
  String query = '';

  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
    _animationController.forward();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          _hasMore &&
          !_isLoadingMore &&
          !isLoading) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadClients([String? q, bool append = false]) async {
    if (!append) {
      setState(() {
        isLoading = true;
        loadError = null;
        clients = [];
        _currentPage = 1;
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final repo = Provider.of<ClienteRepository>(context, listen: false);
      final data = await repo.searchClientes(
        sucursalId: widget.sucursalId,
        query: q,
        page: _currentPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (append) {
          clients.addAll(data);
        } else {
          clients = data;
        }
        _hasMore = data.length == _pageSize;
        isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      final msg = e.toString();
      if (kDebugMode) debugPrint('SelectClientScreen: error: $msg');
      if (!mounted) return;
      setState(() {
        loadError = msg;
        if (!append) clients = [];
        isLoading = false;
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar clientes: $msg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _loadMore() {
    _currentPage++;
    final q = query.trim();
    _loadClients(q.isEmpty ? null : q, true);
  }

  Future<void> _openCreateClient() async {
    final res = await CreateClientDialog.show(context, widget.sucursalId);
    if (!mounted) return;
    if (res != null) {
      Navigator.pop(context, res);
    } else {
      final q = query.trim();
      if (q.length >= 3) {
        await _loadClients(q);
      }
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final trimmed = v.trim();
      setState(() => query = trimmed);
      if (trimmed.isEmpty) {
        // limpiar resultados sin disparar query
        setState(() {
          clients = [];
          _hasMore = false;
          loadError = null;
        });
      } else if (trimmed.length >= 3) {
        _loadClients(trimmed);
      }
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
              child: _buildBody(cs, tt),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, TextTheme tt) {
    // Estado inicial: sin búsqueda aún
    if (!isLoading && clients.isEmpty && query.isEmpty && loadError == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Escribe al menos 3 caracteres\npara buscar',
              textAlign: TextAlign.center,
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Query muy corto (1-2 chars): indicar que se necesitan más
    if (!isLoading &&
        clients.isEmpty &&
        query.isNotEmpty &&
        query.length < 3 &&
        loadError == null) {
      return Center(
        child: Text(
          'Escribe al menos 3 caracteres\npara buscar',
          textAlign: TextAlign.center,
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 12),
            Text(
              'Buscando clientes...',
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
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
              Icon(Icons.error_outline, size: 56, color: cs.error),
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
                onPressed: () => _loadClients(
                  query.trim().isEmpty ? null : query.trim(),
                ),
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
              'No se encontraron clientes',
              style: tt.titleLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _openCreateClient,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Registrar cliente'),
            ),
          ],
        ),
      );
    }

    final itemCount = clients.length + (_isLoadingMore ? 1 : 0);

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        if (idx == clients.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final c = clients[idx] as Map<String, dynamic>;
        final nombre =
            ('${c['nombreCliente'] ?? ''} ${c['apellidoCliente'] ?? ''}')
                .trim();
        final telefono = c['telefono']?.toString() ?? '';
        final initials = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

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
          tileColor: cs.surfaceContainerHighest.withValues(alpha: 0.02),
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
  }
}
