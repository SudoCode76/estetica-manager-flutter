import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:app_estetica/services/api_service.dart';
import 'package:app_estetica/widgets/create_client_dialog.dart';

class SelectClientScreen extends StatefulWidget {
  final int sucursalId;
  const SelectClientScreen({Key? key, required this.sucursalId}) : super(key: key);

  @override
  State<SelectClientScreen> createState() => _SelectClientScreenState();
}

class _SelectClientScreenState extends State<SelectClientScreen> with SingleTickerProviderStateMixin {
  final ApiService api = ApiService();
  List<dynamic> clients = [];
  bool isLoading = true;
  String? loadError;
  String query = '';
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
    setState(() { isLoading = true; loadError = null; });
    try {
      final sucursalId = widget.sucursalId;
      print('SelectClientScreen: Loading clientes for sucursal=$sucursalId query=$q');
      final data = await api.getClientes(sucursalId: sucursalId, query: q);
      print('SelectClientScreen: Loaded ${data.length} clientes');
      setState(() {
        clients = data;
        isLoading = false;
      });
    } catch (e) {
      final msg = e.toString();
      print('SelectClientScreen: Error loading clientes: $msg');
      setState(() {
        loadError = msg;
        clients = [];
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar clientes: $msg'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _showCreateClientDialog() async {
    final result = await CreateClientDialog.show(context, widget.sucursalId);

    if (result != null) {
      // Si se creó un cliente, retornarlo al caller (NewTicketScreen)
      if (mounted) Navigator.pop(context, result);
    } else {
      // Si se canceló, recargar la lista
      await _loadClients(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Seleccionar cliente',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: _showCreateClientDialog,
            tooltip: 'Registrar nuevo cliente',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search bar mejorado
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Buscar por nombre, apellido o teléfono',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search),
              ),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      query = '';
                      _debounce?.cancel();
                      _loadClients();
                    },
                  ),
              ],
              elevation: const WidgetStatePropertyAll(2),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: (v) {
                query = v;
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  _loadClients(query);
                });
              },
            ),
          ),

          // Lista de clientes
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Cargando clientes...',
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : (loadError != null)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Error al cargar clientes',
                                  style: textTheme.titleLarge?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  loadError!,
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: () => _loadClients(query),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reintentar'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : clients.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person_search_rounded,
                                      size: 48,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    query.isEmpty
                                        ? 'No hay clientes en esta sucursal'
                                        : 'No se encontraron clientes',
                                    style: textTheme.titleLarge?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    query.isEmpty
                                        ? 'Registra el primer cliente'
                                        : 'Intenta con otro término de búsqueda',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (query.isEmpty) ...[
                                    const SizedBox(height: 24),
                                    FilledButton.tonalIcon(
                                      onPressed: _showCreateClientDialog,
                                      icon: const Icon(Icons.person_add_rounded),
                                      label: const Text('Registrar cliente'),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: clients.length,
                              itemBuilder: (context, i) {
                                final c = clients[i];
                                final nombre = '${c['nombreCliente'] ?? ''} ${c['apellidoCliente'] ?? ''}'.trim();
                                final telefono = c['telefono']?.toString() ?? '';
                                final initials = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: colorScheme.outline.withValues(alpha: 0.1),
                                            width: 1,
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => Navigator.pop(context, c),
                                            borderRadius: BorderRadius.circular(20),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Hero(
                                                    tag: 'client_${c['id']}',
                                                    child: Container(
                                                      width: 56,
                                                      height: 56,
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            colorScheme.primaryContainer,
                                                            colorScheme.secondaryContainer,
                                                          ],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: colorScheme.primary.withValues(alpha: 0.2),
                                                            blurRadius: 8,
                                                            offset: const Offset(0, 4),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          initials,
                                                          style: textTheme.headlineMedium?.copyWith(
                                                            color: colorScheme.onPrimaryContainer,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          nombre.isNotEmpty ? nombre : 'Sin nombre',
                                                          style: textTheme.titleMedium?.copyWith(
                                                            fontWeight: FontWeight.bold,
                                                            color: colorScheme.onSurface,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons.phone_outlined,
                                                              size: 16,
                                                              color: colorScheme.primary,
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              telefono.isNotEmpty ? telefono : 'Sin teléfono',
                                                              style: textTheme.bodyMedium?.copyWith(
                                                                color: colorScheme.onSurfaceVariant,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.chevron_right_rounded,
                                                    color: colorScheme.onSurfaceVariant,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
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
