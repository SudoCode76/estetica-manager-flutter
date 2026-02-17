import 'package:flutter/material.dart';
import 'package:app_estetica/screens/about_screen.dart';

class MainDrawer extends StatelessWidget {
  final String username;
  final String rolLabel;
  final bool isEmployee;
  final bool isLoadingSucursales;
  final String? employeeSucursalName;
  final List<dynamic> sucursales;
  final int? selectedSucursalId;
  final int selectedIndex;
  final Function(int id, String name) onSucursalChanged;
  final VoidCallback onRetryLoadSucursales;
  final Function(int index) onIndexChanged;
  final VoidCallback onLogout;

  const MainDrawer({
    super.key,
    required this.username,
    required this.rolLabel,
    required this.isEmployee,
    required this.isLoadingSucursales,
    this.employeeSucursalName,
    required this.sucursales,
    this.selectedSucursalId,
    required this.selectedIndex,
    required this.onSucursalChanged,
    required this.onRetryLoadSucursales,
    required this.onIndexChanged,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
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
                    // Selector de sucursal
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 8 : 12,
                        vertical: isSmall ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isLoadingSucursales
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
                          : isEmployee
                              // Para empleados: mostrar sucursal bloqueada
                              ? Row(
                                  children: [
                                    Icon(Icons.location_on, color: colorScheme.onPrimary, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        employeeSucursalName ?? 'Sin sucursal',
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
                                      child: sucursales.isEmpty
                                          ? Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'No hay sucursales disponibles',
                                                    style: TextStyle(
                                                        color: colorScheme.onPrimary.withValues(alpha: 0.9),
                                                        fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: onRetryLoadSucursales,
                                                  icon: Icon(Icons.refresh, color: colorScheme.onPrimary),
                                                  tooltip: 'Reintentar',
                                                ),
                                              ],
                                            )
                                          : DropdownButtonHideUnderline(
                                              child: Builder(
                                                builder: (context) {
                                                  final currentId = selectedSucursalId;
                                                  final validValue = currentId != null &&
                                                          sucursales.any((s) => s['id'] == currentId)
                                                      ? currentId
                                                      : null;

                                                  return DropdownButton<int>(
                                                    value: validValue,
                                                    isExpanded: true,
                                                    dropdownColor: colorScheme.surface,
                                                    icon: Icon(Icons.arrow_drop_down,
                                                        color: colorScheme.onSurfaceVariant),
                                                    style: TextStyle(
                                                      color: colorScheme.onSurface,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    hint: Text(
                                                      'Seleccionar sucursal',
                                                      style: TextStyle(
                                                          color: colorScheme.onPrimary.withValues(alpha: 0.7)),
                                                    ),
                                                    items: sucursales.map((s) {
                                                      return DropdownMenuItem<int>(
                                                        value: s['id'],
                                                        child: Text(s['nombreSucursal'] ?? '-'),
                                                      );
                                                    }).toList(),
                                                    onChanged: (value) {
                                                      if (value != null) {
                                                        final sucursal =
                                                            sucursales.firstWhere((s) => s['id'] == value);
                                                        onSucursalChanged(value, sucursal['nombreSucursal']);
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
                  selected: selectedIndex == 0,
                  onTap: () {
                    onIndexChanged(0);
                    Navigator.pop(context);
                  },
                ),
                // Agenda de Sesiones - disponible para todos
                _DrawerItem(
                  icon: Icons.event_note_outlined,
                  selectedIcon: Icons.event_note,
                  label: 'Agenda de Sesiones',
                  selected: selectedIndex == 1,
                  onTap: () {
                    onIndexChanged(1);
                    Navigator.pop(context);
                  },
                ),
                // Clientes - disponible para todos
                _DrawerItem(
                  icon: Icons.people_outline,
                  selectedIcon: Icons.people,
                  label: 'Clientes',
                  selected: selectedIndex == 2,
                  onTap: () {
                    onIndexChanged(2);
                    Navigator.pop(context);
                  },
                ),
                // Las siguientes opciones SOLO para admin
                if (!isEmployee) ...[
                  _DrawerItem(
                    icon: Icons.spa,
                    selectedIcon: Icons.spa,
                    label: 'Tratamientos',
                    selected: selectedIndex == 3,
                    onTap: () {
                      onIndexChanged(3);
                      Navigator.pop(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.payments,
                    selectedIcon: Icons.payments_outlined,
                    label: 'Pagos',
                    selected: selectedIndex == 4,
                    onTap: () {
                      onIndexChanged(4);
                      Navigator.pop(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.insights_outlined,
                    selectedIcon: Icons.bar_chart,
                    label: 'Reportes',
                    selected: selectedIndex == 5,
                    onTap: () {
                      onIndexChanged(5);
                      Navigator.pop(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.people_outline_rounded,
                    selectedIcon: Icons.people_rounded,
                    label: 'Empleados',
                    selected: selectedIndex == 6,
                    onTap: () {
                      onIndexChanged(6);
                      Navigator.pop(context);
                    },
                  ),
                ],


                // Acerca de - colocado justo después de Tickets para máxima visibilidad
                _DrawerItem(
                  icon: Icons.info_outline,
                  selectedIcon: Icons.info,
                  label: 'Acerca de',
                  selected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                  },
                ),

                // Botón de reintento para cargar sucursales
                if (!isEmployee) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton.icon(
                      onPressed: onRetryLoadSucursales,
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
          // AQUI ELIMINE EL BLOQUE "Acerca de (persistente)"

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
                  onLogout();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
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
          color: selected ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: Icon(
            selected ? selectedIcon : icon,
            color: selected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
            size: 24,
          ),
          title: Text(
            label,
            style: textTheme.bodyLarge?.copyWith(
              color: selected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
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
