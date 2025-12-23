import 'package:flutter/material.dart';
import 'package:app_estetica/screens/admin/clients_screen.dart';
import 'package:app_estetica/screens/admin/reports_screen.dart';
import 'package:app_estetica/screens/admin/settings_screen.dart';
import 'package:app_estetica/screens/admin/tickets_screen.dart';
import 'package:app_estetica/screens/admin/treatments_screen.dart';
import 'package:app_estetica/screens/login/login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({Key? key}) : super(key: key);

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const TicketsScreen(),
    const ClientsScreen(),
    const TreatmentsScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.spa_rounded, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('App Estética'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Mostrar notificaciones
            },
            tooltip: 'Notificaciones',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.logout_outlined),
              onPressed: _logout,
              tooltip: 'Cerrar sesión',
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: colorScheme.primary,
              ),
              child: Row(
                children: [
                  Icon(Icons.account_circle, size: 48, color: colorScheme.onPrimary),
                  const SizedBox(width: 12),
                  Text('App Estética', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Tickets'),
                    selected: _selectedIndex == 0,
                    onTap: () {
                      setState(() { _selectedIndex = 0; });
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Clientes'),
                    selected: _selectedIndex == 1,
                    onTap: () {
                      setState(() { _selectedIndex = 1; });
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.spa_outlined),
                    title: const Text('Tratamientos'),
                    selected: _selectedIndex == 2,
                    onTap: () {
                      setState(() { _selectedIndex = 2; });
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bar_chart_outlined),
                    title: const Text('Reportes'),
                    selected: _selectedIndex == 3,
                    onTap: () {
                      setState(() { _selectedIndex = 3; });
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Configuración'),
                    selected: _selectedIndex == 4,
                    onTap: () {
                      setState(() { _selectedIndex = 4; });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }
}
