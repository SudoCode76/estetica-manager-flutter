import 'package:flutter/material.dart';
import 'package:app_estetica/screens/admin/clients/clients_screen.dart';
import 'package:app_estetica/screens/admin/tickets/tickets_screen.dart';
import 'package:app_estetica/screens/admin/sesiones_screen.dart';
import 'package:app_estetica/screens/admin/treatments_screen.dart';
import 'package:app_estetica/screens/admin/tickets/payments_screen.dart';
import 'package:app_estetica/screens/admin/employees_screen.dart';
import 'package:app_estetica/screens/login/login_screen.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/screens/admin/tickets/new_ticket_screen.dart';
import 'package:app_estetica/repositories/catalog_repository.dart';
import 'package:app_estetica/services/supabase_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:app_estetica/providers/ticket_provider.dart';
import 'dart:async';
import 'package:app_estetica/screens/admin/reports/reports_screen.dart';
import 'package:app_estetica/widgets/main_drawer.dart';

class AdminHomeScreen extends StatefulWidget {
  final bool isEmployee;

  const AdminHomeScreen({super.key, this.isEmployee = false});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  SucursalProvider? _sucursalProvider;
  late CatalogRepository _catalogRepo;
  List<dynamic> _sucursales = [];
  bool _isLoadingSucursales = true;
  bool _isInitialized =
      false; // NUEVO: controla si está listo para mostrar pantallas
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Datos del usuario empleado
  Map<String, dynamic>? _employeeData;
  int? _employeeSucursalId;
  String? _employeeSucursalName;

  // Pantallas para admin (todas) - usando Key para forzar recreación cuando cambia sucursal
  List<Widget> get _adminScreens => [
    TicketsScreen(
      key: ValueKey('tickets_${_sucursalProvider?.selectedSucursalId}'),
    ),
    SesionesScreen(
      key: ValueKey('sesiones_${_sucursalProvider?.selectedSucursalId}'),
    ),
    ClientsScreen(
      key: ValueKey('clients_${_sucursalProvider?.selectedSucursalId}'),
    ),
    TreatmentsScreen(
      key: ValueKey('treatments_${_sucursalProvider?.selectedSucursalId}'),
    ),
    PaymentsScreen(
      key: ValueKey('payments_${_sucursalProvider?.selectedSucursalId}'),
    ),
    // Reportes debe estar en la posición 5 del Drawer
    ReportsScreen(
      key: ValueKey('reports_${_sucursalProvider?.selectedSucursalId}'),
    ),
    EmployeesScreen(
      key: ValueKey('employees_${_sucursalProvider?.selectedSucursalId}'),
    ),
  ];

  // Pantallas para empleado (solo tickets y clientes) - usando Key para forzar recreación
  List<Widget> get _employeeScreens => [
    TicketsScreen(
      key: ValueKey('emp_tickets_${_sucursalProvider?.selectedSucursalId}'),
    ),
    SesionesScreen(
      key: ValueKey('emp_sesiones_${_sucursalProvider?.selectedSucursalId}'),
    ),
    ClientsScreen(
      key: ValueKey('emp_clients_${_sucursalProvider?.selectedSucursalId}'),
    ),
  ];

  List<Widget> get _screens =>
      widget.isEmployee ? _employeeScreens : _adminScreens;

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
              final nombre =
                  attrs['nombreSucursal'] ??
                  attrs['nombre'] ??
                  attrs['nombre_sucursal'];
              return {'id': attrs['id'], 'nombreSucursal': nombre};
            }
            final id = d['id'] ?? d['ID'];
            final nombre =
                d['nombreSucursal'] ?? d['nombre'] ?? d['nombre_sucursal'];
            if (id != null) return {'id': id, 'nombreSucursal': nombre};
          }
        }
        if (sucursalObj.containsKey('attributes')) {
          final attrs = Map<String, dynamic>.from(sucursalObj['attributes']);
          final id = sucursalObj['id'] ?? attrs['id'];
          final nombre =
              attrs['nombreSucursal'] ??
              attrs['nombre'] ??
              attrs['nombre_sucursal'];
          if (id != null) return {'id': id, 'nombreSucursal': nombre};
        }
        if (sucursalObj.containsKey('id')) {
          final id = sucursalObj['id'];
          final nombre =
              sucursalObj['nombreSucursal'] ??
              sucursalObj['nombre'] ??
              sucursalObj['nombre_sucursal'];
          return {'id': id, 'nombreSucursal': nombre};
        }
      }
    } catch (e) {
      debugPrint('AdminHomeScreen: Error extrayendo sucursal: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadEmployeeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null) {
        final user = jsonDecode(userString);
        debugPrint('AdminHomeScreen: Empleado data: $user');
        _employeeData = user;

        if (user['sucursal'] != null) {
          final extracted = _extractSucursal(user['sucursal']);
          if (extracted != null) {
            _employeeSucursalId = extracted['id'];
            _employeeSucursalName = extracted['nombreSucursal'] ?? 'Sin nombre';
            debugPrint(
              'AdminHomeScreen: Sucursal del empleado (extraida): $_employeeSucursalId - $_employeeSucursalName',
            );
          } else {
            debugPrint(
              'AdminHomeScreen: Warning: user.sucursal exists but could not extract',
            );
          }
        }
        return user;
      }
    } catch (e) {
      debugPrint('AdminHomeScreen: Error cargando datos empleado: $e');
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sucursalProvider == null) {
      _sucursalProvider = SucursalInherited.of(context);
      // Obtener repositorios inyectados
      _catalogRepo = Provider.of<CatalogRepository>(context, listen: false);
      debugPrint(
        'AdminHomeScreen: Got provider from context: $_sucursalProvider',
      );
      debugPrint(
        'AdminHomeScreen: Provider has sucursalId: ${_sucursalProvider?.selectedSucursalId}',
      );
      debugPrint('AdminHomeScreen: isEmployee: ${widget.isEmployee}');

      // Inicializar según el tipo de usuario
      _initializeForUserType();
    }
  }

  Future<void> _initializeForUserType() async {
    debugPrint(
      'AdminHomeScreen: _initializeForUserType started, isEmployee=${widget.isEmployee}',
    );

    // Cargar datos del usuario siempre (necesario tanto para admin como employee)
    debugPrint('AdminHomeScreen: Cargando datos del usuario (común)');
    await _loadEmployeeData();

    if (widget.isEmployee) {
      // Para empleado: primero limpiar cualquier sucursal anterior
      debugPrint('AdminHomeScreen: Limpiando sucursal anterior...');
      _sucursalProvider?.clearSucursal();

      // Esperar un poco para que se limpie
      await Future.delayed(const Duration(milliseconds: 50));

      // Luego cargar datos y establecer sucursal del empleado
      debugPrint('AdminHomeScreen: Cargando datos del empleado...');
      await _loadEmployeeData();

      debugPrint('AdminHomeScreen: Estableciendo sucursal del empleado...');
      await _setupEmployeeSucursal();

      // Verificar que se estableció correctamente
      debugPrint(
        'AdminHomeScreen: Sucursal después de setup: ${_sucursalProvider?.selectedSucursalId}',
      );
    } else {
      // Para admin: cargar todas las sucursales
      await _loadSucursales();
    }

    // Marcar como inicializado DESPUÉS de establecer la sucursal
    if (mounted) {
      debugPrint('AdminHomeScreen: Marcando como inicializado');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _setupEmployeeSucursal() async {
    debugPrint('AdminHomeScreen: _setupEmployeeSucursal started');

    // Esperar a que se carguen los datos del empleado si aún no están listos
    if (_employeeSucursalId == null) {
      await _loadEmployeeData();
    }

    if (_employeeSucursalId != null && _employeeSucursalName != null) {
      debugPrint(
        'AdminHomeScreen: ✓ Estableciendo sucursal del empleado: $_employeeSucursalId - $_employeeSucursalName',
      );
      _sucursalProvider?.setSucursal(
        _employeeSucursalId!,
        _employeeSucursalName!,
      );

      // Crear lista de sucursales con solo la del empleado (para mostrar en el drawer)
      _sucursales = [
        {'id': _employeeSucursalId, 'nombreSucursal': _employeeSucursalName},
      ];
      _isLoadingSucursales = false;

      // Esperar un frame para que el provider notifique a los listeners
      await Future.delayed(const Duration(milliseconds: 100));

      // Verificar que la sucursal se estableció correctamente
      debugPrint(
        'AdminHomeScreen: Sucursal en provider después de setup: ${_sucursalProvider?.selectedSucursalId}',
      );
    } else {
      debugPrint('AdminHomeScreen: ⚠️ Empleado sin sucursal asignada');
      _isLoadingSucursales = false;
    }
  }

  Future<void> _loadSucursales() async {
    debugPrint('AdminHomeScreen: _loadSucursales started');
    debugPrint(
      'AdminHomeScreen: Provider selectedSucursalId ANTES de cargar = ${_sucursalProvider?.selectedSucursalId}',
    );
    try {
      // Intentar obtener con timeout para evitar bloqueos
      final sucursales = await _catalogRepo.getSucursales().timeout(
        const Duration(seconds: 8),
      );
      debugPrint('AdminHomeScreen: Loaded ${sucursales.length} sucursales');
      // Guardar cache local de sucursales para fallback si el servidor está lento
      await _saveSucursalesCache(sucursales);
      setState(() {
        _sucursales = sucursales;
        _isLoadingSucursales = false;
        // Sólo seleccionar la primera sucursal si no hay selección previa persistida
        if (_sucursales.isNotEmpty &&
            _sucursalProvider?.selectedSucursalId == null) {
          debugPrint(
            'AdminHomeScreen: Setting default sucursal: ${_sucursales.first['id']} - ${_sucursales.first['nombreSucursal']}',
          );
          _sucursalProvider?.setSucursal(
            _sucursales.first['id'],
            _sucursales.first['nombreSucursal'],
          );
        } else {
          debugPrint(
            'AdminHomeScreen: Sucursal ya establecida: ${_sucursalProvider?.selectedSucursalId} - ${_sucursalProvider?.selectedSucursalName}',
          );
        }
      });
      debugPrint(
        'AdminHomeScreen: Provider selectedSucursalId DESPUES de cargar = ${_sucursalProvider?.selectedSucursalId}',
      );
    } catch (e) {
      debugPrint('AdminHomeScreen: Error loading sucursales: $e');
      final msg = e is TimeoutException
          ? 'Timeout al cargar sucursales (verifica conexión)'
          : e.toString();
      // Intentar cargar desde caché local
      final cached = await _loadSucursalesCache();
      if (cached != null && cached.isNotEmpty) {
        debugPrint(
          'AdminHomeScreen: Using cached sucursales (${cached.length}) as fallback',
        );
        setState(() {
          _sucursales = cached;
          _isLoadingSucursales = false;
          // Si no hay selección previa, seleccionar la primera del cache
          if (_sucursales.isNotEmpty &&
              _sucursalProvider?.selectedSucursalId == null) {
            _sucursalProvider?.setSucursal(
              _sucursales.first['id'],
              _sucursales.first['nombreSucursal'],
            );
          }
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Usando datos en caché: servidor lento o inaccesible',
              ),
            ),
          );
      } else {
        // No hay caché: informar y permitir reintento
        setState(() {
          _isLoadingSucursales = false;
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error cargando sucursales: $msg')),
          );
      }
    }
  }

  // Guardar lista de sucursales en SharedPreferences como JSON
  Future<void> _saveSucursalesCache(List<dynamic> sucursales) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = jsonEncode(sucursales);
      await prefs.setString('cachedSucursales', s);
      debugPrint(
        'AdminHomeScreen: Saved ${sucursales.length} sucursales to cache',
      );
    } catch (e) {
      debugPrint('AdminHomeScreen: Error saving sucursales cache: $e');
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
      debugPrint('AdminHomeScreen: Error loading sucursales cache: $e');
      return null;
    }
  }

  Future<void> _retryLoadSucursales() async {
    setState(() {
      _isLoadingSucursales = true;
    });
    await _loadSucursales();
  }

  Future<void> _logout() async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          icon: Icon(Icons.logout, color: colorScheme.error, size: 32),
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // Mostrar loader mientras se cierra sesión
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  'Cerrando sesión...',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await SupabaseAuthService().signOut();
      _sucursalProvider?.clearSucursal();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final username = _employeeData != null
        ? (_employeeData?['username'] ??
              (_employeeData?['email'] ??
                  (widget.isEmployee ? 'Empleado' : 'Administrador')))
        : (widget.isEmployee ? 'Empleado' : 'Administrador');
    final rolLabel = _employeeData != null
        ? (_employeeData?['tipoUsuario'] ??
              (widget.isEmployee ? 'Empleado' : 'Administrador'))
        : (widget.isEmployee ? 'Empleado' : 'Administrador');

    // Títulos dinámicos por índice
    const screenTitles = [
      'Tickets',
      'Agenda de Sesiones',
      'Clientes',
      'Tratamientos',
      'Pagos',
      'Reportes',
      'Empleados',
    ];
    final currentTitle = screenTitles[_selectedIndex.clamp(
      0,
      screenTitles.length - 1,
    )];

    return Scaffold(
      key: _scaffoldKey,
      drawer: MainDrawer(
        username: username,
        rolLabel: rolLabel,
        isEmployee: widget.isEmployee,
        isLoadingSucursales: _isLoadingSucursales,
        employeeSucursalName: _employeeSucursalName,
        sucursales: _sucursales,
        selectedSucursalId: _sucursalProvider?.selectedSucursalId,
        selectedIndex: _selectedIndex,
        onSucursalChanged: (id, name) {
          setState(() {
            _sucursalProvider?.setSucursal(id, name);
          });
        },
        onRetryLoadSucursales: _retryLoadSucursales,
        onIndexChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        onLogout: _logout,
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Menú',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.spa_rounded,
              color: colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(currentTitle),
          ],
        ),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.primary,
        scrolledUnderElevation: 2,
      ),
      body: ScaffoldKeyInherited(
        scaffoldKey: _scaffoldKey,
        child: _screens[_selectedIndex],
      ),
      floatingActionButton: _selectedIndex == 0
          ? Builder(
              builder: (context) {
                final screenWidth = MediaQuery.of(context).size.width;
                final isCompact = screenWidth < 360;

                if (isCompact) {
                  return FloatingActionButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final userJson = prefs.getString('user');
                      String? userIdStr;
                      if (userJson != null && userJson.isNotEmpty) {
                        try {
                          final Map<String, dynamic> userMap = jsonDecode(
                            userJson,
                          );
                          userIdStr = userMap['id']?.toString();
                        } catch (_) {
                          userIdStr = null;
                        }
                      }
                      if (!context.mounted) return;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NewTicketScreen(
                            key: ValueKey(
                              'new_ticket_${DateTime.now().millisecondsSinceEpoch}',
                            ),
                            currentUserId: userIdStr,
                          ),
                        ),
                      );
                      if (result == true && context.mounted) {
                        try {
                          await Provider.of<TicketProvider>(
                            context,
                            listen: false,
                          ).fetchCurrent();
                        } catch (e) {
                          setState(() {});
                        }
                      }
                    },
                    child: const Icon(Icons.add_rounded),
                  );
                }

                return FloatingActionButton.extended(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final userJson = prefs.getString('user');
                    String? userIdStr;
                    if (userJson != null && userJson.isNotEmpty) {
                      try {
                        final Map<String, dynamic> userMap = jsonDecode(
                          userJson,
                        );
                        userIdStr = userMap['id']?.toString();
                      } catch (_) {
                        userIdStr = null;
                      }
                    }
                    if (!context.mounted) return;
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewTicketScreen(
                          key: ValueKey(
                            'new_ticket_${DateTime.now().millisecondsSinceEpoch}',
                          ),
                          currentUserId: userIdStr,
                        ),
                      ),
                    );
                    if (result == true && context.mounted) {
                      try {
                        await Provider.of<TicketProvider>(
                          context,
                          listen: false,
                        ).fetchCurrent();
                      } catch (e) {
                        setState(() {});
                      }
                    }
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nuevo Ticket'),
                );
              },
            )
          : null,
    );
  }
}
