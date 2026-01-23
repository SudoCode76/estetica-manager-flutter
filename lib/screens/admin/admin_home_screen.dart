import 'package:flutter/material.dart';
import 'package:app_estetica/screens/admin/clients_screen.dart';
import 'package:app_estetica/screens/admin/reporte_ventas_screen.dart';
import 'package:app_estetica/screens/admin/settings_screen.dart';
import 'package:app_estetica/screens/admin/tickets_screen.dart';
import 'package:app_estetica/screens/admin/treatments_screen.dart';
import 'package:app_estetica/screens/admin/payments_screen.dart';
import 'package:app_estetica/screens/admin/employees_screen.dart';
import 'package:app_estetica/screens/login/login_screen.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/screens/admin/new_ticket_screen.dart';
import 'package:app_estetica/services/api_service.dart';
import 'package:app_estetica/services/supabase_auth_service.dart';
import 'package:app_estetica/widgets/create_client_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:app_estetica/providers/ticket_provider.dart';

class AdminHomeScreen extends StatefulWidget {
  final bool isEmployee;

  const AdminHomeScreen({Key? key, this.isEmployee = false}) : super(key: key);

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  SucursalProvider? _sucursalProvider;
  final ApiService _api = ApiService();
  List<dynamic> _sucursales = [];
  bool _isLoadingSucursales = true;
  bool _isInitialized = false; // NUEVO: controla si está listo para mostrar pantallas
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Datos del usuario empleado
  Map<String, dynamic>? _employeeData;
  int? _employeeSucursalId;
  String? _employeeSucursalName;

  // Pantallas para admin (todas) - usando Key para forzar recreación cuando cambia sucursal
  List<Widget> get _adminScreens => [
    TicketsScreen(key: ValueKey('tickets_${_sucursalProvider?.selectedSucursalId}')),
    ClientsScreen(key: ValueKey('clients_${_sucursalProvider?.selectedSucursalId}')),
    TreatmentsScreen(key: ValueKey('treatments_${_sucursalProvider?.selectedSucursalId}')),
    PaymentsScreen(key: ValueKey('payments_${_sucursalProvider?.selectedSucursalId}')),
    ReporteVentasScreen(key: ValueKey('reports_${_sucursalProvider?.selectedSucursalId}')),
    EmployeesScreen(key: ValueKey('employees_${_sucursalProvider?.selectedSucursalId}')),
    const SettingsScreen(),
  ];

  // Pantallas para empleado (solo tickets y clientes) - usando Key para forzar recreación
  List<Widget> get _employeeScreens => [
    TicketsScreen(key: ValueKey('emp_tickets_${_sucursalProvider?.selectedSucursalId}')),
    ClientsScreen(key: ValueKey('emp_clients_${_sucursalProvider?.selectedSucursalId}')),
  ];

  List<Widget> get _screens => widget.isEmployee ? _employeeScreens : _adminScreens;

  @override
  void initState() {
    super.initState();
    // NO cargar datos aquí, esperar a didChangeDependencies para tener el provider
  }

  // Helper para extraer/normalizar la sucursal (reutilizable)
  Map<String, dynamic>? _extractSucursal(dynamic sucursalObj) {
    if (sucursalObj == null) return null;
    try {
      if (sucursalObj is Map) {
        if (sucursalObj.containsKey('data')) {
          final d = sucursalObj['data'];
          if (d is Map) {
            if (d.containsKey('attributes')) {
              final attrs = Map<String, dynamic>.from(d['attributes']);
              attrs['id'] = d['id'] ?? attrs['id'];
              final nombre = attrs['nombreSucursal'] ?? attrs['nombre'] ?? attrs['nombre_sucursal'];
              return {'id': attrs['id'], 'nombreSucursal': nombre};
            }
            final id = d['id'] ?? d['ID'];
            final nombre = d['nombreSucursal'] ?? d['nombre'] ?? d['nombre_sucursal'];
            if (id != null) return {'id': id, 'nombreSucursal': nombre};
          }
        }
        if (sucursalObj.containsKey('attributes')) {
          final attrs = Map<String, dynamic>.from(sucursalObj['attributes']);
          final id = sucursalObj['id'] ?? attrs['id'];
          final nombre = attrs['nombreSucursal'] ?? attrs['nombre'] ?? attrs['nombre_sucursal'];
          if (id != null) return {'id': id, 'nombreSucursal': nombre};
        }
        if (sucursalObj.containsKey('id')) {
          final id = sucursalObj['id'];
          final nombre = sucursalObj['nombreSucursal'] ?? sucursalObj['nombre'] ?? sucursalObj['nombre_sucursal'];
          return {'id': id, 'nombreSucursal': nombre};
        }
      }
    } catch (e) {
      print('AdminHomeScreen: Error extrayendo sucursal: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadEmployeeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null) {
        final user = jsonDecode(userString);
        print('AdminHomeScreen: Empleado data: $user');
        _employeeData = user;

        if (user['sucursal'] != null) {
          final extracted = _extractSucursal(user['sucursal']);
          if (extracted != null) {
            _employeeSucursalId = extracted['id'];
            _employeeSucursalName = extracted['nombreSucursal'] ?? 'Sin nombre';
            print('AdminHomeScreen: Sucursal del empleado (extraida): $_employeeSucursalId - $_employeeSucursalName');
          } else {
            print('AdminHomeScreen: Warning: user.sucursal exists but could not extract');
          }
        }
        return user;
      }
    } catch (e) {
      print('AdminHomeScreen: Error cargando datos empleado: $e');
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sucursalProvider == null) {
      _sucursalProvider = SucursalInherited.of(context);
      print('AdminHomeScreen: Got provider from context: $_sucursalProvider');
      print('AdminHomeScreen: Provider has sucursalId: ${_sucursalProvider?.selectedSucursalId}');
      print('AdminHomeScreen: isEmployee: ${widget.isEmployee}');

      // Inicializar según el tipo de usuario
      _initializeForUserType();
    }
  }

  Future<void> _initializeForUserType() async {
    print('AdminHomeScreen: _initializeForUserType started, isEmployee=${widget.isEmployee}');

    if (widget.isEmployee) {
      // Para empleado: primero limpiar cualquier sucursal anterior
      print('AdminHomeScreen: Limpiando sucursal anterior...');
      _sucursalProvider?.clearSucursal();

      // Esperar un poco para que se limpie
      await Future.delayed(const Duration(milliseconds: 50));

      // Luego cargar datos y establecer sucursal del empleado
      print('AdminHomeScreen: Cargando datos del empleado...');
      await _loadEmployeeData();

      print('AdminHomeScreen: Estableciendo sucursal del empleado...');
      await _setupEmployeeSucursal();

      // Verificar que se estableció correctamente
      print('AdminHomeScreen: Sucursal después de setup: ${_sucursalProvider?.selectedSucursalId}');
    } else {
      // Para admin: cargar todas las sucursales
      await _loadSucursales();
    }

    // Marcar como inicializado DESPUÉS de establecer la sucursal
    if (mounted) {
      print('AdminHomeScreen: Marcando como inicializado');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _setupEmployeeSucursal() async {
    print('AdminHomeScreen: _setupEmployeeSucursal started');

    // Esperar a que se carguen los datos del empleado si aún no están listos
    if (_employeeSucursalId == null) {
      await _loadEmployeeData();
    }

    if (_employeeSucursalId != null && _employeeSucursalName != null) {
      print('AdminHomeScreen: ✓ Estableciendo sucursal del empleado: $_employeeSucursalId - $_employeeSucursalName');
      _sucursalProvider?.setSucursal(_employeeSucursalId!, _employeeSucursalName!);

      // Crear lista de sucursales con solo la del empleado (para mostrar en el drawer)
      _sucursales = [
        {'id': _employeeSucursalId, 'nombreSucursal': _employeeSucursalName}
      ];
      _isLoadingSucursales = false;

      // Esperar un frame para que el provider notifique a los listeners
      await Future.delayed(const Duration(milliseconds: 100));

      // Verificar que la sucursal se estableció correctamente
      print('AdminHomeScreen: Sucursal en provider después de setup: ${_sucursalProvider?.selectedSucursalId}');
    } else {
      print('AdminHomeScreen: ⚠️ Empleado sin sucursal asignada');
      _isLoadingSucursales = false;
    }
  }

  Future<void> _loadSucursales() async {
    print('AdminHomeScreen: _loadSucursales started');
    print('AdminHomeScreen: Provider selectedSucursalId ANTES de cargar = ${_sucursalProvider?.selectedSucursalId}');
    try {
      final sucursales = await _api.getSucursales();
      print('AdminHomeScreen: Loaded ${sucursales.length} sucursales');
      // Guardar cache local de sucursales para fallback si el servidor está lento
      await _saveSucursalesCache(sucursales);
      setState(() {
        _sucursales = sucursales;
        _isLoadingSucursales = false;
        // Sólo seleccionar la primera sucursal si no hay selección previa persistida
        if (_sucursales.isNotEmpty && _sucursalProvider?.selectedSucursalId == null) {
          print('AdminHomeScreen: Setting default sucursal: ${_sucursales.first['id']} - ${_sucursales.first['nombreSucursal']}');
          _sucursalProvider?.setSucursal(
            _sucursales.first['id'],
            _sucursales.first['nombreSucursal'],
          );
        } else {
          print('AdminHomeScreen: Sucursal ya establecida: ${_sucursalProvider?.selectedSucursalId} - ${_sucursalProvider?.selectedSucursalName}');
        }
      });
      print('AdminHomeScreen: Provider selectedSucursalId DESPUES de cargar = ${_sucursalProvider?.selectedSucursalId}');
    } catch (e) {
      print('AdminHomeScreen: Error loading sucursales: $e');
      // Intentar cargar desde caché local
      final cached = await _loadSucursalesCache();
      if (cached != null && cached.isNotEmpty) {
        print('AdminHomeScreen: Using cached sucursales (${cached.length}) as fallback');
        setState(() {
          _sucursales = cached;
          _isLoadingSucursales = false;
          // Si no hay selección previa, seleccionar la primera del cache
          if (_sucursales.isNotEmpty && _sucursalProvider?.selectedSucursalId == null) {
            _sucursalProvider?.setSucursal(_sucursales.first['id'], _sucursales.first['nombreSucursal']);
          }
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usando datos en caché: servidor lento o inaccesible')));
      } else {
        // No hay caché: informar y permitir reintento
        setState(() {
          _isLoadingSucursales = false;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando sucursales: $e')));
      }
    }
  }

  // Guardar lista de sucursales en SharedPreferences como JSON
  Future<void> _saveSucursalesCache(List<dynamic> sucursales) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = jsonEncode(sucursales);
      await prefs.setString('cachedSucursales', s);
      print('AdminHomeScreen: Saved ${sucursales.length} sucursales to cache');
    } catch (e) {
      print('AdminHomeScreen: Error saving sucursales cache: $e');
    }
  }

  // Cargar cache de sucursales si existe
  Future<List<dynamic>?> _loadSucursalesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('cachedSucursales');
      if (s == null || s.isEmpty) return null;
      final decoded = jsonDecode(s) as List<dynamic>;
      return decoded;
    } catch (e) {
      print('AdminHomeScreen: Error loading sucursales cache: $e');
      return null;
    }
  }

  Future<void> _retryLoadSucursales() async {
    setState(() {
      _isLoadingSucursales = true;
    });
    await _loadSucursales();
  }

  void _logout() {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(Icons.logout, color: colorScheme.error, size: 32),
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);

                try {
                  // Cerrar sesión con Supabase (esto limpia SharedPreferences también)
                  await SupabaseAuthService().signOut();

                  // Limpiar sucursal del provider
                  _sucursalProvider?.clearSucursal();

                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  }
                } catch (e) {
                  print('Error al cerrar sesión: $e');
                  // Aún así navegar al login
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
              ),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Mostrar loading mientras se inicializa
    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Cargando...',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    // Verificar si el empleado tiene sucursal asignada
    if (widget.isEmployee && _employeeSucursalId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error de Configuración'),
          backgroundColor: colorScheme.errorContainer,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 80,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Sin Sucursal Asignada',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tu cuenta de empleado no tiene una sucursal asignada. Por favor, contacta al administrador para que te asigne una sucursal.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar Sesión'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final username = widget.isEmployee ? (_employeeData?['username'] ?? 'Empleado') : 'Administrador';
    final rolLabel = widget.isEmployee ? 'Empleado' : 'Administrador';

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: colorScheme.primary,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxHeight < 150;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_circle,
                            size: isSmall ? 36 : 48,
                            color: colorScheme.onPrimary,
                          ),
                          SizedBox(width: isSmall ? 8 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmall ? 14 : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  rolLabel,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onPrimary.withValues(alpha: 0.8),
                                    fontSize: isSmall ? 11 : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmall ? 8 : 16),
                      // Selector de sucursal - BLOQUEADO para empleados
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmall ? 8 : 12,
                          vertical: isSmall ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.onPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                    child: _isLoadingSucursales
                        ? Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cargando...',
                                style: TextStyle(color: colorScheme.onPrimary),
                              ),
                            ],
                          )
                        : widget.isEmployee
                            // Para empleados: mostrar sucursal bloqueada
                            ? Row(
                                children: [
                                  Icon(Icons.location_on, color: colorScheme.onPrimary, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _employeeSucursalName ?? 'Sin sucursal',
                                      style: TextStyle(
                                        color: colorScheme.onPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.lock,
                                    size: 16,
                                    color: colorScheme.onPrimary.withValues(alpha: 0.6),
                                  ),
                                ],
                              )
                            // Para admin: dropdown editable
                            : Row(
                                children: [
                                  Icon(Icons.location_on, color: colorScheme.onPrimary, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _sucursales.isEmpty
                                        ? Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'No hay sucursales disponibles',
                                                  style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: _retryLoadSucursales,
                                                icon: Icon(Icons.refresh, color: colorScheme.onPrimary),
                                                tooltip: 'Reintentar',
                                              ),
                                            ],
                                          )
                                        : DropdownButtonHideUnderline(
                                            child: Builder(
                                              builder: (context) {
                                                final currentId = _sucursalProvider?.selectedSucursalId;
                                                final validValue = currentId != null && _sucursales.any((s) => s['id'] == currentId) ? currentId : null;

                                                return DropdownButton<int>(
                                                  value: validValue,
                                                  isExpanded: true,
                                                  dropdownColor: colorScheme.surface,
                                                  icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
                                                  style: TextStyle(
                                                    color: colorScheme.onSurface,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  hint: Text(
                                                    'Seleccionar sucursal',
                                                    style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.7)),
                                                  ),
                                                  items: _sucursales.map((s) {
                                                    return DropdownMenuItem<int>(
                                                      value: s['id'],
                                                      child: Text(s['nombreSucursal'] ?? '-'),
                                                    );
                                                  }).toList(),
                                                  onChanged: (value) {
                                                    if (value != null) {
                                                      final sucursal = _sucursales.firstWhere((s) => s['id'] == value);
                                                      setState(() {
                                                        _sucursalProvider?.setSucursal(value, sucursal['nombreSucursal']);
                                                      });
                                                    }
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                  ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Tickets - disponible para todos
                  _DrawerItem(
                    icon: Icons.receipt_long_outlined,
                    selectedIcon: Icons.receipt_long,
                    label: 'Tickets',
                    selected: _selectedIndex == 0,
                    onTap: () {
                      setState(() { _selectedIndex = 0; });
                      Navigator.pop(context);
                    },
                  ),
                  // Clientes - disponible para todos
                  _DrawerItem(
                    icon: Icons.people_outline,
                    selectedIcon: Icons.people,
                    label: 'Clientes',
                    selected: _selectedIndex == 1,
                    onTap: () {
                      setState(() { _selectedIndex = 1; });
                      Navigator.pop(context);
                    },
                  ),
                  // Las siguientes opciones SOLO para admin
                  if (!widget.isEmployee) ...[
                    _DrawerItem(
                      icon: Icons.spa,
                      selectedIcon: Icons.spa,
                      label: 'Tratamientos',
                      selected: _selectedIndex == 2,
                      onTap: () {
                        setState(() { _selectedIndex = 2; });
                        Navigator.pop(context);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.payments,
                      selectedIcon: Icons.payments_outlined,
                      label: 'Pagos',
                      selected: _selectedIndex == 3,
                      onTap: () {
                        setState(() { _selectedIndex = 3; });
                        Navigator.pop(context);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.insights_outlined,
                      selectedIcon: Icons.bar_chart,
                      label: 'Reportes',
                      selected: _selectedIndex == 4,
                      onTap: () {
                        setState(() { _selectedIndex = 4; });
                        Navigator.pop(context);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.people_outline_rounded,
                      selectedIcon: Icons.people_rounded,
                      label: 'Empleados',
                      selected: _selectedIndex == 5,
                      onTap: () {
                        setState(() { _selectedIndex = 5; });
                        Navigator.pop(context);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.settings_outlined,
                      selectedIcon: Icons.settings,
                      label: 'Configuración',
                      selected: _selectedIndex == 6,
                      onTap: () {
                        setState(() { _selectedIndex = 6; });
                        Navigator.pop(context);
                      },
                    ),
                  ],
                  // Botón de reintento para cargar sucursales
                  if (!widget.isEmployee) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ElevatedButton.icon(
                        onPressed: _retryLoadSucursales,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar Cargar Sucursales'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Cerrar sesión al final
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: Icon(Icons.logout_rounded, color: colorScheme.error),
                  title: Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
        body: SafeArea(
          child: ScaffoldKeyInherited(
            scaffoldKey: _scaffoldKey,
            child: Column(
              children: [
                // Header global (menú + logo + título)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 360;
                    final isVerySmall = constraints.maxWidth < 340;
                    return Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 8 : 16,
                      isCompact ? 12 : 16,
                      isCompact ? 8 : 16,
                      8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                          style: IconButton.styleFrom(
                            minimumSize: Size(isCompact ? 36 : 40, isCompact ? 36 : 40),
                            fixedSize: Size(isCompact ? 36 : 40, isCompact ? 36 : 40),
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        SizedBox(width: isVerySmall ? 6 : (isCompact ? 8 : 12)),
                        Icon(
                          Icons.spa_rounded,
                          color: colorScheme.primary,
                          size: isVerySmall ? 20 : (isCompact ? 24 : 28),
                        ),
                        SizedBox(width: isVerySmall ? 4 : (isCompact ? 6 : 8)),
                        Expanded(
                          child: Text(
                            'App Estética',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: isVerySmall ? 16 : (isCompact ? 18 : null),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Pantalla seleccionada
              Expanded(child: _screens[_selectedIndex]),
            ],
          ),
        ),
        ),
        floatingActionButton: _selectedIndex == 0
          ? Builder(
              builder: (context) {
                final screenWidth = MediaQuery.of(context).size.width;
                final isCompact = screenWidth < 360;

                if (isCompact) {
                  return FloatingActionButton(
                    onPressed: () async {
                      // obtener user id desde prefs y pasarlo a NewTicketScreen
                      final prefs = await SharedPreferences.getInstance();
                      final userJson = prefs.getString('user');
                      String? userIdStr;
                      if (userJson != null && userJson.isNotEmpty) {
                        try {
                          final Map<String, dynamic> userMap = jsonDecode(userJson);
                          userIdStr = userMap['id']?.toString();
                        } catch (_) {
                          userIdStr = null;
                        }
                      }
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NewTicketScreen(
                            key: ValueKey('new_ticket_${DateTime.now().millisecondsSinceEpoch}'),
                            currentUserId: userIdStr,
                          ),
                        ),
                      );
                      if (result == true) {
                        // Refrescar globalmente usando los mismos filtros que la pantalla de tickets
                        try {
                          await context.read<TicketProvider>().fetchCurrent();
                        } catch (e) {
                          setState(() {});
                        }
                      }
                    },
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.add),
                  );
                }

                return FloatingActionButton.extended(
                  onPressed: () async {
                    // obtener user id desde prefs y pasarlo a NewTicketScreen
                    final prefs = await SharedPreferences.getInstance();
                    final userJson = prefs.getString('user');
                    String? userIdStr;
                    if (userJson != null && userJson.isNotEmpty) {
                      try {
                        final Map<String, dynamic> userMap = jsonDecode(userJson);
                        userIdStr = userMap['id']?.toString();
                      } catch (_) {
                        userIdStr = null;
                      }
                    }
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewTicketScreen(
                          key: ValueKey('new_ticket_${DateTime.now().millisecondsSinceEpoch}'),
                          currentUserId: userIdStr,
                        ),
                      ),
                    );
                    if (result == true) {
                      // Refrescar globalmente usando los mismos filtros que la pantalla de tickets
                      try {
                        await context.read<TicketProvider>().fetchCurrent();
                      } catch (e) {
                        setState(() {});
                      }
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo Ticket'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                );
              },
            )
          : _selectedIndex == 1
            ? Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final isCompact = screenWidth < 360;

                  if (isCompact) {
                    return FloatingActionButton(
                      onPressed: () async {
                        if (_sucursalProvider?.selectedSucursalId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Selecciona una sucursal en el menú lateral antes de continuar'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        final result = await CreateClientDialog.show(context, _sucursalProvider!.selectedSucursalId!);

                        if (result != null) {
                          // refrescar clientes - rebuild forzado
                          setState(() {});
                        }
                      },
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.person_add),
                    );
                  }

                  return FloatingActionButton.extended(
                    onPressed: () async {
                      if (_sucursalProvider?.selectedSucursalId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Selecciona una sucursal en el menú lateral antes de continuar'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      final result = await CreateClientDialog.show(context, _sucursalProvider!.selectedSucursalId!);

                      if (result != null) {
                        // refrescar clientes - rebuild forzado
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Nuevo Cliente'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  );
                },
              )
            : null,
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: Icon(
            selected ? selectedIcon : icon,
            color: selected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            size: 24,
          ),
          title: Text(
            label,
            style: textTheme.bodyLarge?.copyWith(
              color: selected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }
}
