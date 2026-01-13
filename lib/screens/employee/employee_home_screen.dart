import 'package:flutter/material.dart';
import 'package:app_estetica/screens/admin/tickets_screen.dart';
import 'package:app_estetica/screens/admin/clients_screen.dart';
import 'package:app_estetica/screens/admin/new_ticket_screen.dart';
import 'package:app_estetica/screens/login/login_screen.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/widgets/create_client_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  SucursalProvider? _sucursalProvider;
  Map<String, dynamic>? _userData;
  bool _isLoadingUser = true;

  // Nuevo: key para acceder a TicketsScreen
  final GlobalKey _ticketsKey = GlobalKey();

  // NO crear las pantallas aquí, se crearán dinámicamente en build
  List<Widget> _getScreens() {
    return [
      TicketsScreen(key: _ticketsKey),
      const ClientsScreen(key: ValueKey('clients_screen')),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');

      print('EmployeeHome: User string from prefs: $userString');

      if (userString != null) {
        final user = jsonDecode(userString);
        print('EmployeeHome: User decoded: $user');

        setState(() {
          _userData = user;
        });

        // Establecer la sucursal aquí después de cargar los datos
        if (user['sucursal'] == null) {
          print('EmployeeHome: ⚠️ ADVERTENCIA: El empleado no tiene sucursal asignada');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tu usuario no tiene sucursal asignada. Contacta al administrador.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          print('EmployeeHome: Sucursal del empleado: ${user['sucursal']}');
          // Establecer la sucursal inmediatamente después de cargar los datos
          _setupEmployeeSucursal(user['sucursal']);
        }
      }
    } catch (e) {
      print('EmployeeHome: ❌ Error cargando datos del usuario: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos del empleado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingUser = false;
      });
    }
  }

  void _setupEmployeeSucursal(Map<String, dynamic> sucursal) {
    final sucursalId = sucursal['id'];
    final sucursalNombre = sucursal['nombreSucursal'] ?? 'Sin nombre';

    print('EmployeeHome: _setupEmployeeSucursal - id=$sucursalId, nombre=$sucursalNombre');

    // Obtener el provider del contexto
    final provider = SucursalInherited.of(context);
    if (provider != null) {
      print('EmployeeHome: ✓✓✓ Estableciendo sucursal del empleado: $sucursalId - $sucursalNombre');
      provider.setSucursal(sucursalId, sucursalNombre);
      _sucursalProvider = provider;
    } else {
      print('EmployeeHome: ⚠️ Provider no disponible aún');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('EmployeeHome: didChangeDependencies called');

    final provider = SucursalInherited.of(context);

    // Si el provider cambió o es la primera vez
    if (provider != null && provider != _sucursalProvider) {
      print('EmployeeHome: Provider disponible');
      _sucursalProvider = provider;

      // Si ya tenemos los datos del usuario con sucursal, establecerla ahora
      if (_userData != null && _userData!['sucursal'] != null) {
        _setupEmployeeSucursal(_userData!['sucursal']);
      }
    }
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
                // Limpiar sucursal del provider
                _sucursalProvider?.clearSucursal();
                // Limpiar SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('jwt');
                await prefs.remove('user');
                await prefs.remove('userType');
                await prefs.remove('selectedSucursalId');
                await prefs.remove('selectedSucursalName');
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
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
    final textTheme = Theme.of(context).textTheme;

    if (_isLoadingUser) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    final username = _userData?['username'] ?? 'Empleado';
    final sucursalNombre = _userData?['sucursal']?['nombreSucursal'] ?? 'Sin sucursal asignada';
    final hasSucursal = _userData?['sucursal'] != null;

    // Mostrar pantalla de advertencia si no tiene sucursal
    if (!hasSucursal) {
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
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tu cuenta de empleado no tiene una sucursal asignada. Por favor, contacta al administrador para que te asigne una sucursal.',
                  style: textTheme.bodyLarge?.copyWith(
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

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.store, color: colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sucursalNombre,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Empleado',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.surface,
                        child: Icon(
                          Icons.person,
                          size: 28,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Empleado',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimary.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  // Selector de sucursal BLOQUEADO para empleados
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.onPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: colorScheme.onPrimary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sucursalNombre,
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
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
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
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: colorScheme.error),
              title: Text(
                'Cerrar Sesión',
                style: TextStyle(color: colorScheme.error),
              ),
              onTap: _logout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      body: _getScreens()[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                // Obtener user id desde prefs y pasarlo a NewTicketScreen
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
                  // Intentar invocar fetchTickets en la pantalla de tickets
                  try {
                    final state = _ticketsKey.currentState;
                    if (state != null) {
                      (state as dynamic).fetchTickets();
                    } else {
                      setState(() {});
                    }
                  } catch (e) {
                    setState(() {});
                  }
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Ticket'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            )
          : _selectedIndex == 1
            ? FloatingActionButton.extended(
                onPressed: () async {
                  if (_sucursalProvider?.selectedSucursalId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No hay sucursal asignada. Contacte al administrador.'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final result = await CreateClientDialog.show(context, _sucursalProvider!.selectedSucursalId!);

                  if (result != null) {
                    // Refrescar clientes - simplemente rebuild todo
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Nuevo Cliente'),
                backgroundColor: Theme.of(context).colorScheme.primary,
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
