import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      child: Column(
        children: [
          // ── Header con gradiente ───────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.secondary,
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(0),
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + nombre + rol
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.onPrimary.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.account_circle_rounded,
                        size: 32,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.onPrimary.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              rolLabel,
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Selector de sucursal
                _SucursalSelector(
                  isLoadingSucursales: isLoadingSucursales,
                  isEmployee: isEmployee,
                  employeeSucursalName: employeeSucursalName,
                  sucursales: sucursales,
                  selectedSucursalId: selectedSucursalId,
                  onSucursalChanged: onSucursalChanged,
                  onRetryLoadSucursales: onRetryLoadSucursales,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),

          // ── Items de navegación ────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: [
                _SectionLabel(label: 'Principal', textTheme: textTheme),
                _DrawerItem(
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long_rounded,
                  label: 'Tickets',
                  selected: selectedIndex == 0,
                  onTap: () {
                    onIndexChanged(0);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.event_note_outlined,
                  selectedIcon: Icons.event_note_rounded,
                  label: 'Agenda de Sesiones',
                  selected: selectedIndex == 1,
                  onTap: () {
                    onIndexChanged(1);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.people_outline_rounded,
                  selectedIcon: Icons.people_rounded,
                  label: 'Clientes',
                  selected: selectedIndex == 2,
                  onTap: () {
                    onIndexChanged(2);
                    Navigator.pop(context);
                  },
                ),
                if (!isEmployee) ...[
                  const SizedBox(height: 8),
                  _SectionLabel(label: 'Administración', textTheme: textTheme),
                  _DrawerItem(
                    icon: Icons.spa_outlined,
                    selectedIcon: Icons.spa_rounded,
                    label: 'Tratamientos',
                    selected: selectedIndex == 3,
                    onTap: () {
                      onIndexChanged(3);
                      Navigator.pop(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.payments_outlined,
                    selectedIcon: Icons.payments_rounded,
                    label: 'Pagos',
                    selected: selectedIndex == 4,
                    onTap: () {
                      onIndexChanged(4);
                      Navigator.pop(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.insights_outlined,
                    selectedIcon: Icons.insights_rounded,
                    label: 'Reportes',
                    selected: selectedIndex == 5,
                    onTap: () {
                      onIndexChanged(5);
                      Navigator.pop(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.badge_outlined,
                    selectedIcon: Icons.badge_rounded,
                    label: 'Empleados',
                    selected: selectedIndex == 6,
                    onTap: () {
                      onIndexChanged(6);
                      Navigator.pop(context);
                    },
                  ),
                ],
                const SizedBox(height: 8),
                _SectionLabel(label: 'Otros', textTheme: textTheme),
                _DrawerItem(
                  icon: Icons.info_outline_rounded,
                  selectedIcon: Icons.info_rounded,
                  label: 'Acerca de',
                  selected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Cerrar sesión ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(context);
                onLogout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar Sesión'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: colorScheme.errorContainer,
                foregroundColor: colorScheme.error,
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

// ── Widget: etiqueta de sección ──────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final TextTheme textTheme;

  const _SectionLabel({required this.label, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colorScheme.outline,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Widget: item de drawer ───────────────────────────────────────────────────
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected
            ? colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widget: selector de sucursal ─────────────────────────────────────────────
class _SucursalSelector extends StatelessWidget {
  final bool isLoadingSucursales;
  final bool isEmployee;
  final String? employeeSucursalName;
  final List<dynamic> sucursales;
  final int? selectedSucursalId;
  final Function(int id, String name) onSucursalChanged;
  final VoidCallback onRetryLoadSucursales;
  final ColorScheme colorScheme;

  const _SucursalSelector({
    required this.isLoadingSucursales,
    required this.isEmployee,
    this.employeeSucursalName,
    required this.sucursales,
    this.selectedSucursalId,
    required this.onSucursalChanged,
    required this.onRetryLoadSucursales,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
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
                const SizedBox(width: 10),
                Text(
                  'Cargando sucursales...',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ],
            )
          : isEmployee
          ? Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: colorScheme.onPrimary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    employeeSucursalName ?? 'Sin sucursal',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: colorScheme.onPrimary.withValues(alpha: 0.6),
                ),
              ],
            )
          : sucursales.isEmpty
          ? Row(
              children: [
                Icon(
                  Icons.location_off_rounded,
                  color: colorScheme.onPrimary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin sucursales',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: colorScheme.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRetryLoadSucursales,
                  icon: Icon(Icons.refresh_rounded, color: colorScheme.onPrimary),
                  tooltip: 'Reintentar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            )
          : Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: colorScheme.onPrimary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: Builder(
                      builder: (context) {
                        final validValue = selectedSucursalId != null &&
                                sucursales.any(
                                  (s) => s['id'] == selectedSucursalId,
                                )
                            ? selectedSucursalId
                            : null;

                        return DropdownButton<int>(
                          value: validValue,
                          isExpanded: true,
                          dropdownColor: colorScheme.surface,
                          icon: Icon(
                            Icons.arrow_drop_down_rounded,
                            color: colorScheme.onPrimary,
                          ),
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          hint: Text(
                            'Seleccionar sucursal',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: colorScheme.onPrimary.withValues(alpha: 0.8),
                            ),
                          ),
                          items: sucursales.map((s) {
                            return DropdownMenuItem<int>(
                              value: s['id'],
                              child: Text(s['nombreSucursal'] ?? '-'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              final sucursal = sucursales.firstWhere(
                                (s) => s['id'] == value,
                              );
                              onSucursalChanged(
                                value,
                                sucursal['nombreSucursal'],
                              );
                            }
                          },
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
