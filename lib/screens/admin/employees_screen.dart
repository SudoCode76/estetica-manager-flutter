import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';
import '../../providers/sucursal_provider.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({Key? key}) : super(key: key);

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _employees = [];
  bool _loading = false;
  String? _error;
  String _searchQuery = '';

  // Provider de sucursal
  SucursalProvider? _sucursalProvider;

  // Diagnostic fields
  int? _diagProviderId;
  int? _diagPrefsId;
  bool _diagAuthPresent = false;
  int? _lastFetchedCount;
  Map<String, dynamic>? _lastFetchedSample;

  @override
  void initState() {
    super.initState();
    // No cargar aquí: esperar a que el provider esté disponible en didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = SucursalInherited.of(context);
    if (provider != _sucursalProvider) {
      _sucursalProvider?.removeListener(_onSucursalChanged);
      _sucursalProvider = provider;
      _sucursalProvider?.addListener(_onSucursalChanged);
      // Cargar empleados para la sucursal actual (si existe)
      _loadEmployees();
    }
  }

  @override
  void dispose() {
    _sucursalProvider?.removeListener(_onSucursalChanged);
    super.dispose();
  }

  void _onSucursalChanged() {
    // Cuando cambia la sucursal, recargar la lista
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    var sucId = _sucursalProvider?.selectedSucursalId;
    _diagProviderId = sucId;
    print('EmployeesScreen: provider.selectedSucursalId = $sucId');
    // Si provider no tiene sucursal, intentar fallback desde SharedPreferences
    if (sucId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final prefId = prefs.getInt('selectedSucursalId');
        print('EmployeesScreen: prefs.selectedSucursalId = $prefId');
        _diagPrefsId = prefId;
        if (prefId != null) {
          sucId = prefId;
          // intentar establecer en provider si existe
          if (_sucursalProvider != null) {
            _sucursalProvider!.setSucursal(prefId, prefs.getString('selectedSucursalName') ?? '');
          }
        }
      } catch (e) {
        print('EmployeesScreen: error leyendo prefs fallback: $e');
      }
    }

    // Chequear si hay JWT en session o prefs
    try {
      final session = Supabase.instance.client.auth.currentSession;
      _diagAuthPresent = session?.accessToken?.isNotEmpty ?? false;
      if (!_diagAuthPresent) {
        final prefs = await SharedPreferences.getInstance();
        _diagAuthPresent = (prefs.getString('jwt') ?? '').isNotEmpty;
      }
    } catch (_) {
      _diagAuthPresent = false;
    }

    if (sucId == null) {
      // No hay sucursal seleccionada: limpiar lista y mostrar mensaje
      setState(() {
        _employees = [];
        _loading = false;
        _error = null; // mostramos UI con botón para abrir el drawer
      });
      return;
    }

    try {
      final users = await _api.getUsuarios(sucursalId: sucId);
      _lastFetchedCount = users.length;
      _lastFetchedSample = users.isNotEmpty && users.first is Map ? Map<String, dynamic>.from(users.first) : null;
      print('EmployeesScreen: fetched users count=${users.length}');
      // Si no hay resultados para la sucursal, intentar fetch sin filtro para diagnosticar
      if (users.isEmpty) {
        try {
          final all = await _api.getUsuarios();
          _lastFetchedCount = all.length;
          _lastFetchedSample = all.first is Map ? Map<String, dynamic>.from(all.first) : null;
          print('EmployeesScreen: fetched ALL users count=${all.length} (diagnóstico)');
          if (all.isNotEmpty) {
            print('EmployeesScreen: ejemplo user[0]=${all.first}');
            // Avisar en UI que no hay empleados para la sucursal pero sí existen usuarios globales
            setState(() {
              _error = 'No se encontraron empleados para la sucursal seleccionada. Hay ${all.length} usuarios en total (revisa sucursal_id de los perfiles).';
              _employees = [];
              _loading = false;
            });
            return;
          }
        } catch (diagErr) {
          print('EmployeesScreen: diagnostic fetch failed: $diagErr');
        }
      }
      setState(() {
        // Mostrar usuarios con roles relevantes (administrador, empleado, vendedor, gerente)
        final allowed = {'administrador', 'admin', 'empleado', 'vendedor', 'gerente'};
        _employees = users.where((u) {
          final t = (u['tipoUsuario'] ?? u['tipo_usuario'] ?? '').toString().toLowerCase();
          // Si tipo vacío, incluir (posible perfil incompleto)
          if (t.isEmpty) return true;
          return allowed.contains(t);
        }).map<Map<String, dynamic>>((u) => Map<String, dynamic>.from(u)).toList();
        print('EmployeesScreen: filtered usuarios (roles allowed) count=${_employees.length}');
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    if (_searchQuery.isEmpty) return _employees;
    return _employees.where((e) {
      final username = (e['username'] ?? '').toString().toLowerCase();
      final email = (e['email'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return username.contains(query) || email.contains(query);
    }).toList();
  }

  void _showEmployeeDialog(Map<String, dynamic>? employee) {
    // Si es edición, primero obtener perfil actualizado (incluye email)
    if (employee != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => FutureBuilder<Map<String, dynamic>?>(
          future: ApiService().getUsuarioById(employee['id']?.toString() ?? employee['documentId']?.toString() ?? ''),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            if (snap.hasError) return AlertDialog(title: const Text('Error'), content: Text('No se pudo obtener el perfil: ${snap.error}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))]);
            final full = snap.data ?? employee;
            return _EmployeeDialog(
              employee: full,
              onSaved: () {
                Navigator.pop(context);
                _loadEmployees();
              },
            );
          },
        ),
      );
      return;
    }

    // Crear nuevo
    showDialog(
      context: context,
      builder: (context) => _EmployeeDialog(
        employee: null,
        onSaved: () {
          Navigator.pop(context);
          _loadEmployees();
        },
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> employee) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          const SizedBox(width: 8),
          Text('Eliminar Empleado', style: theme.textTheme.titleMedium)
        ]),
        content: Text('¿Seguro que deseas eliminar a "${employee['username'] ?? employee['email']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteEmployee(employee);
            },
            child: const Text('Eliminar'),
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEmployee(Map<String, dynamic> employee) async {
    try {
      final id = employee['documentId'] ?? employee['id']?.toString();
      if (id == null) throw Exception('ID de usuario no disponible');
      await ApiService().eliminarUsuarioFunction(id.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empleado eliminado'), backgroundColor: Colors.green));
      _loadEmployees();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Empleados'),
        elevation: 0,
        surfaceTintColor: colorScheme.surfaceTint,
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            tooltip: 'Diag',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => _showDebugDialog(),
          ),
          if (!_loading)
            IconButton.filledTonal(
              onPressed: _loadEmployees,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Si no hay sucursal seleccionada, mostrar call-to-action en la parte superior
          if (_sucursalProvider?.selectedSucursalId == null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('No hay sucursal seleccionada. Elige una sucursal en el menú lateral para ver los empleados.', style: theme.textTheme.bodyMedium),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      final sk = ScaffoldKeyInherited.of(context);
                      if (sk != null && sk.currentState != null) {
                        sk.currentState!.openDrawer();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abre el menú lateral y selecciona una sucursal')));
                      }
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text('Seleccionar'),
                  ),
                ],
              ),
            ),

          // Header compacto con contador
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.primaryContainer.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.people_rounded,
                    color: colorScheme.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Empleados',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '${_filteredEmployees.length}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Filtrando',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Buscador compacto
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o email',
                prefixIcon: Icon(Icons.search_rounded, color: colorScheme.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Lista de empleados
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline_rounded, size: 56, color: colorScheme.error),
                              const SizedBox(height: 16),
                              Text(
                                'Error al cargar empleados',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_error',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _loadEmployees,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredEmployees.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _searchQuery.isEmpty ? Icons.people_outline_rounded : Icons.search_off_rounded,
                                  size: 72,
                                  color: colorScheme.outlineVariant,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _searchQuery.isEmpty ? 'No hay empleados registrados' : 'No se encontraron empleados',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isEmpty ? 'Agrega tu primer empleado con el botón de abajo' : 'Intenta con otros términos de búsqueda',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadEmployees,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                              itemCount: _filteredEmployees.length,
                              itemBuilder: (context, index) {
                                final employee = _filteredEmployees[index];
                                return _EmployeeCard(
                                  employee: employee,
                                  onEdit: () => _showEmployeeDialog(employee),
                                  onDelete: () => _confirmDelete(employee),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEmployeeDialog(null),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Nuevo'),
        elevation: 2,
      ),
    );
  }

  // Mostrar diálogo de diagnóstico (está en el scope de _EmployeesScreenState)
  void _showDebugDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diagnóstico'),
        content: FutureBuilder<Map<String, dynamic>>(
          future: _gatherDiagnostics(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const SizedBox(width: 300, height: 120, child: Center(child: CircularProgressIndicator()));
            if (snap.hasError) return Text('Error diagnóstico: \\${snap.error}');
            final data = snap.data ?? {};
            return SingleChildScrollView(child: SelectableText(JsonEncoder.withIndent('  ').convert(data)));
          },
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  // Recolectar datos de diagnóstico (usa el provider desde el BuildContext)
  Future<Map<String, dynamic>> _gatherDiagnostics() async {
    final api = ApiService();
    final provider = SucursalInherited.of(context);
    final providerSuc = provider?.selectedSucursalId;
    final prefs = await SharedPreferences.getInstance();
    final prefSuc = prefs.getInt('selectedSucursalId');
    final auth = await api.debugAuthCheck();
    final sucursales = await api.debugGetSucursalesDetailed();
    List<dynamic> usuarios = [];
    try {
      usuarios = await api.getUsuarios(sucursalId: providerSuc ?? prefSuc);
    } catch (e) {
      usuarios = ['error: $e'];
    }
    return {
      'provider_selectedSucursalId': providerSuc,
      'prefs_selectedSucursalId': prefSuc,
      'debugAuthCheck': auth,
      'debugSucursales': sucursales,
      'usuarios_sample_count_or_error': usuarios is List ? usuarios.length : usuarios,
      'usuarios_sample_first': usuarios is List && usuarios.isNotEmpty ? usuarios.first : null,
    };
  }
}

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EmployeeCard({
    Key? key,
    required this.employee,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final confirmed = employee['confirmed'] ?? false;
    final blocked = employee['blocked'] ?? false;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar compacto
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.primaryContainer.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    (employee['username'] ?? 'E').toString()[0].toUpperCase(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info compacta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      employee['username'] ?? '',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            employee['email'] ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Badges compactos
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (blocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.block_rounded,
                            size: 12,
                            color: colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Bloqueado',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (confirmed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 12,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Activo',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pending_rounded,
                            size: 12,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Pendiente',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 4),

              // Menú compacto
              IconButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => _EmployeeActionsSheet(
                      employee: employee,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
                  );
                },
                icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurfaceVariant),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bottom Sheet para acciones
class _EmployeeActionsSheet extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EmployeeActionsSheet({
    Key? key,
    required this.employee,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Título
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.primaryContainer.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      (employee['username'] ?? 'E').toString()[0].toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee['username'] ?? '',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        employee['email'] ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // Acciones
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.edit_rounded, size: 20, color: colorScheme.primary),
            ),
            title: const Text('Editar empleado'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pop(context);
              onEdit();
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_rounded, size: 20, color: colorScheme.error),
            ),
            title: const Text('Eliminar empleado'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _EmployeeDialog extends StatefulWidget {
  final Map<String, dynamic>? employee;
  final VoidCallback onSaved;

  const _EmployeeDialog({
    Key? key,
    this.employee,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _confirmed = true;
  bool _loading = false;
  bool _obscurePassword = true;
  String _tipoUsuario = 'empleado';
  String? _currentUserType;
  bool _canSetRole = false;

  @override
  void initState() {
    super.initState();
    if (widget.employee != null) {
      _usernameController.text = widget.employee!['username'] ?? '';
      _emailController.text = widget.employee!['email'] ?? '';
      _confirmed = widget.employee!['confirmed'] ?? true;
      // _blocked = widget.employee!['blocked'] ?? false;
      _tipoUsuario = widget.employee!['tipoUsuario'] ?? 'empleado';
    }

    // Leer userType desde SharedPreferences para permitir que solo administradores cambien el rol
    SharedPreferences.getInstance().then((prefs) {
      final ut = prefs.getString('userType') ?? '';
      setState(() {
        _currentUserType = ut;
        _canSetRole = (ut == 'admin' || ut == 'administrador' || ut == 'gerente');
      });
    }).catchError((e) {
      print('Error leyendo userType desde prefs: $e');
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEdit = widget.employee != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header compacto
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primaryContainer,
                              colorScheme.primaryContainer.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEdit ? 'Editar Empleado' : 'Nuevo Empleado',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Nombre de usuario
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre de usuario',
                      prefixIcon: const Icon(Icons.person_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingrese un nombre de usuario';
                      }
                      if (value.length < 3) {
                        return 'Mínimo 3 caracteres';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isEdit, // Solo editable al crear
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingrese un email';
                      }
                      if (!value.contains('@')) {
                        return 'Email inválido';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // Contraseña (OBLIGATORIA para crear, opcional para editar)
                  if (!isEdit) ...[
                    // Campo de contraseña para CREAR nuevo usuario
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese una contraseña';
                        }
                        if (value.length < 6) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Cambiar contraseña (solo para editar)
                  if (isEdit) ...[
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña (opcional)',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      ),
                      obscureText: _obscurePassword,
                      onChanged: (v) => setState(() {}), // Rebuild para habilitar botón
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton.tonal(
                          onPressed: _passwordController.text.isEmpty || _loading
                              ? null
                              : () async {
                                  // Llamar a la function para cambiar password
                                  try {
                                    setState(() => _loading = true);
                                    final id = widget.employee!['documentId'] ?? widget.employee!['id']?.toString();
                                    if (id == null) throw Exception('ID no disponible');

                                    // OBTENER TOKEN FRESCO del SDK
                                    final session = Supabase.instance.client.auth.currentSession;
                                    if (session == null || session.isExpired) {
                                      throw Exception('Sesión expirada. Vuelve a iniciar sesión');
                                    }

                                    await ApiService().editarPasswordFunction(id.toString(), _passwordController.text);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada'), backgroundColor: Colors.green));
                                    // Limpiar campo
                                    _passwordController.clear();
                                    setState(() {});
                                  } catch (e) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cambiando contraseña: $e'), backgroundColor: Colors.red));
                                  } finally {
                                    if (mounted) setState(() => _loading = false);
                                  }
                                },
                          child: const Text('Cambiar contraseña'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Switches compactos
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.verified_rounded, size: 18, color: Colors.green.shade700),
                          ),
                          title: Text('Cuenta verificada', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text('Puede iniciar sesión', style: theme.textTheme.bodySmall),
                          trailing: Switch(
                            value: _confirmed,
                            onChanged: (value) => setState(() => _confirmed = value),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                        // Reemplazamos el switch de 'bloqueado' por un botón para eliminar el usuario directamente
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
                          ),
                          title: Text('Eliminar usuario', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text('Eliminará la cuenta del sistema (acción irreversible)', style: theme.textTheme.bodySmall),
                          trailing: FilledButton.tonal(
                            onPressed: () async {
                              final id = widget.employee!['documentId'] ?? widget.employee!['id']?.toString();
                              if (id == null) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID de usuario no disponible')));
                                return;
                              }
                              final confirmedDelete = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                                title: const Text('Confirmar eliminación'),
                                content: Text('¿Seguro que deseas eliminar al usuario "${widget.employee!['username'] ?? widget.employee!['email']}"? Esta acción no se puede deshacer.'),
                                actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar'))],
                              ));
                              if (confirmedDelete == true) {
                                try {
                                  setState(() => _loading = true);
                                  await ApiService().eliminarUsuarioFunction(id.toString());
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario eliminado'), backgroundColor: Colors.green));
                                  widget.onSaved();
                                  Navigator.pop(context);
                                } catch (e) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error eliminando usuario: $e'), backgroundColor: Colors.red));
                                } finally {
                                  if (mounted) setState(() => _loading = false);
                                }
                              }
                            },
                            child: const Text('Eliminar'),
                            style: FilledButton.styleFrom(backgroundColor: colorScheme.errorContainer, foregroundColor: colorScheme.error),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Selección de tipo de usuario (solo visible para administradores o al editar si ya tiene rol)
                  if (_canSetRole || widget.employee != null)
                    DropdownButtonFormField<String>(
                      value: _tipoUsuario,
                      decoration: InputDecoration(
                        labelText: 'Tipo de usuario',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'administrador', child: Text('Administrador')),
                        DropdownMenuItem(value: 'empleado', child: Text('Empleado')),
                      ],
                      onChanged: _canSetRole ? (v) => setState(() => _tipoUsuario = v ?? 'empleado') : null,
                    ),

                  const SizedBox(height: 20),

                  // Botones
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _loading ? null : () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _loading ? null : _save,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded),
                        label: Text(isEdit ? 'Guardar' : 'Crear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final api = ApiService();

      if (widget.employee != null) {
        // Actualizar
        final sucId = widget.employee!['sucursal'] is Map ? widget.employee!['sucursal']['id'] : widget.employee!['sucursal_id'];
        await api.updateUser(
          widget.employee!['documentId'],
          username: _usernameController.text,
          email: _emailController.text,
          tipoUsuario: _tipoUsuario,
          sucursalId: sucId is int ? sucId : (sucId != null ? int.tryParse(sucId.toString()) : null),
        );
      } else {
         // Obtener sucursal seleccionada desde el provider
         final provider = SucursalInherited.of(context);
         final selectedSucursalId = provider?.selectedSucursalId;
         if (selectedSucursalId == null) {
           // No permitimos crear empleado sin sucursal asignada
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una sucursal en el menú lateral antes de crear el empleado'), backgroundColor: Colors.orange));
           if (mounted) setState(() => _loading = false);
           return;
         }
        // Crear usando la function de Supabase que definiste
        await api.crearUsuarioFunction(
          email: _emailController.text,
          password: _passwordController.text,
          nombre: _usernameController.text,
          sucursalId: selectedSucursalId,
          tipoUsuario: _tipoUsuario ?? 'empleado',
        );
      }

      if (mounted) {
        // Si estamos editando, intentar también actualizar flag 'confirmed' solamente si el backend la soporta.
        if (widget.employee != null) {
          try {
            final origConfirmed = widget.employee!['confirmed'] ?? true;
            if (origConfirmed != _confirmed) {
              try {
                await api.updateUserWithFlags2(widget.employee!['documentId'], username: null, email: null, confirmed: _confirmed);
              } catch (e) {
                final msg = e.toString();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo actualizar flag confirmed: $msg'), backgroundColor: Colors.orange));
              }
            }
          } catch (_) {}

        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.employee != null ? 'Empleado actualizado' : 'Empleado creado'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

}
