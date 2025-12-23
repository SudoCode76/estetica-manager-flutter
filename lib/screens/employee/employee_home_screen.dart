import 'package:flutter/material.dart';
import 'package:app_estetica/screens/employee/clients_screen.dart';
import 'package:app_estetica/screens/employee/tickets_screen.dart';
import 'package:app_estetica/screens/employee/treatments_screen.dart';
import 'package:app_estetica/screens/login/login_screen.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _selectedIndex = 0;
  final SucursalProvider _sucursalProvider = SucursalProvider();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = [
    const EmployeeTicketsScreen(),
    const EmployeeClientsScreen(),
    const EmployeeTreatmentsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // TODO: Cargar la sucursal del empleado desde el backend
    // Por ahora se dejará para que el empleado vea su sucursal asignada
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
                    const SizedBox(height: 0),
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
          child: _screens[_selectedIndex],
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
