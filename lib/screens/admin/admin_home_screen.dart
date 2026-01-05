import 'package:flutter/material.dart';
import 'package:app_estetica/screens/admin/clients_screen.dart';
import 'package:app_estetica/screens/admin/reports_screen.dart';
import 'package:app_estetica/screens/admin/settings_screen.dart';
import 'package:app_estetica/screens/admin/tickets_screen.dart';
import 'package:app_estetica/screens/admin/treatments_screen.dart';
import 'package:app_estetica/screens/admin/payments_screen.dart';
import 'package:app_estetica/screens/login/login_screen.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/screens/admin/new_ticket_screen.dart';
import 'package:app_estetica/services/api_service.dart';
import 'package:app_estetica/widgets/create_client_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({Key? key}) : super(key: key);

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  SucursalProvider? _sucursalProvider; // Obtener del contexto
  final ApiService _api = ApiService();
  List<dynamic> _sucursales = [];
  bool _isLoadingSucursales = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Widget> _screens = [
    const TicketsScreen(),
    const ClientsScreen(),
    const TreatmentsScreen(),
    const PaymentsScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sucursalProvider == null) {
      _sucursalProvider = SucursalInherited.of(context);
      print('AdminHomeScreen: Got provider from context: $_sucursalProvider');
      print('AdminHomeScreen: Provider has sucursalId: ${_sucursalProvider?.selectedSucursalId}');
      _loadSucursales();
    }
  }

  Future<void> _loadSucursales() async {
    print('AdminHomeScreen: _loadSucursales started');
    print('AdminHomeScreen: Provider selectedSucursalId ANTES de cargar = ${_sucursalProvider?.selectedSucursalId}');
    try {
      final sucursales = await _api.getSucursales();
      print('AdminHomeScreen: Loaded ${sucursales.length} sucursales');
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
      setState(() {
        _isLoadingSucursales = false;
      });
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
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('jwt');
                await prefs.remove('user');
                await prefs.remove('userType');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
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
    // Ya no necesitamos SucursalInherited aquí, está a nivel global
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_circle, size: 48, color: colorScheme.onPrimary),
                      const SizedBox(width: 12),
                      Text(
                        'App Estética',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Selector de sucursal
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        : Row(
                            children: [
                              Icon(Icons.location_on, color: colorScheme.onPrimary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _sucursalProvider?.selectedSucursalId,
                                    isExpanded: true,
                                    dropdownColor: colorScheme.surface,
                                    icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
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
                                  ),
                                ),
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
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Configuración',
                    selected: _selectedIndex == 5,
                    onTap: () {
                      setState(() { _selectedIndex = 5; });
                      Navigator.pop(context);
                    },
                  ),
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
        body: ScaffoldKeyInherited(
          scaffoldKey: _scaffoldKey,
          child: Column(
            children: [
              // Header global (menú + logo + título)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        fixedSize: const Size(40, 40),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.spa_rounded, color: colorScheme.primary, size: 28),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'App Estética',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              // Pantalla seleccionada
              Expanded(child: _screens[_selectedIndex]),
            ],
          ),
        ),
        floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
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
                  MaterialPageRoute(builder: (context) => NewTicketScreen(currentUserId: userIdStr)),
                );
                if (result == true) {
                  // refrescar tickets si se creó uno
                  // crear nueva instancia de TicketsScreen para forzar refresh
                  setState(() {
                    _screens[0] = const TicketsScreen();
                  });
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
                        content: Text('Selecciona una sucursal en el menú lateral antes de continuar'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  final result = await CreateClientDialog.show(context, _sucursalProvider!.selectedSucursalId!);

                  if (result != null) {
                    // refrescar clientes
                    setState(() {
                      _screens[1] = const ClientsScreen();
                    });
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
