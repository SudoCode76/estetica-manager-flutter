import 'package:flutter/material.dart';
import 'package:app_estetica/screens/admin/clients_screen.dart';
import 'package:app_estetica/screens/admin/reports_screen.dart';
import 'package:app_estetica/screens/admin/settings_screen.dart';
import 'package:app_estetica/screens/admin/tickets_screen.dart';
import 'package:app_estetica/screens/admin/treatments_screen.dart';
import 'package:app_estetica/screens/login/login_screen.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/services/api_service.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({Key? key}) : super(key: key);

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  final SucursalProvider _sucursalProvider = SucursalProvider();
  final ApiService _api = ApiService();
  List<dynamic> _sucursales = [];
  bool _isLoadingSucursales = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = [
    const TicketsScreen(),
    const ClientsScreen(),
    const TreatmentsScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadSucursales();
  }

  Future<void> _loadSucursales() async {
    try {
      final sucursales = await _api.getSucursales();
      setState(() {
        _sucursales = sucursales;
        _isLoadingSucursales = false;
        if (sucursales.isNotEmpty) {
          _sucursalProvider.setSucursal(
            sucursales.first['id'],
            sucursales.first['nombreSucursal'],
          );
        }
      });
    } catch (e) {
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
              onPressed: () {
                Navigator.pop(context);
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
    return SucursalInherited(
      provider: _sucursalProvider,
      child: Scaffold(
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
                                      value: _sucursalProvider.selectedSucursalId,
                                      isExpanded: true,
                                      dropdownColor: colorScheme.primary,
                                      icon: Icon(Icons.arrow_drop_down, color: colorScheme.onPrimary),
                                      style: TextStyle(
                                        color: colorScheme.onPrimary,
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
                                            _sucursalProvider.setSucursal(value, sucursal['nombreSucursal']);
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
                      icon: Icons.spa_outlined,
                      selectedIcon: Icons.spa,
                      label: 'Tratamientos',
                      selected: _selectedIndex == 2,
                      onTap: () {
                        setState(() { _selectedIndex = 2; });
                        Navigator.pop(context);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.bar_chart_outlined,
                      selectedIcon: Icons.bar_chart,
                      label: 'Reportes',
                      selected: _selectedIndex == 3,
                      onTap: () {
                        setState(() { _selectedIndex = 3; });
                        Navigator.pop(context);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.settings_outlined,
                      selectedIcon: Icons.settings,
                      label: 'Configuración',
                      selected: _selectedIndex == 4,
                      onTap: () {
                        setState(() { _selectedIndex = 4; });
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
      ),
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
