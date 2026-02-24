import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:app_estetica/providers/reports_provider.dart';

/// Barra de navegación de fechas para reportes históricos.
///
/// Permite al usuario elegir:
/// - Un día (prev/next o calendario),
/// - Un rango de fechas,
/// - Un mes completo (month_picker_dialog),
/// - Un año completo (DatePicker en modo año).
class DateNavBar extends StatelessWidget {
  const DateNavBar({
    super.key,
    required this.provider,
    required this.onDateChanged,
    required this.onRangeChanged,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  /// Provider para leer el estado de fecha actual.
  final ReportsProvider provider;

  /// Callback: día único seleccionado.
  final ValueChanged<DateTime> onDateChanged;

  /// Callback: rango seleccionado.
  final ValueChanged<DateTimeRange> onRangeChanged;

  /// Callback: mes seleccionado (año, mes).
  final void Function(int year, int month) onMonthChanged;

  /// Callback: año seleccionado.
  final ValueChanged<int> onYearChanged;

  // ── helpers ──────────────────────────────────────────────────────────────

  bool get _isRangeMode => provider.dateMode == ReportDateMode.dateRange;
  bool get _isMonthMode => provider.dateMode == ReportDateMode.monthPick;
  bool get _isYearMode => provider.dateMode == ReportDateMode.yearPick;
  bool get _isDayMode =>
      provider.dateMode == ReportDateMode.singleDay ||
      provider.dateMode == ReportDateMode.period;

  bool get _canGoForward {
    if (!_isDayMode) return false;
    final now = DateTime.now();
    final d = provider.selectedDate;
    return !(d.year == now.year && d.month == now.month && d.day == now.day);
  }

  String _buildLabel(BuildContext context) {
    // Año
    if (_isYearMode && provider.selectedYear != null) {
      return 'Año ${provider.selectedYear}';
    }
    // Mes
    if (_isMonthMode && provider.selectedMonth != null) {
      return DateFormat('MMMM yyyy', 'es').format(provider.selectedMonth!);
    }
    // Rango
    if (_isRangeMode && provider.selectedRange != null) {
      final locale = Localizations.localeOf(context).toString();
      final fmt = DateFormat('dd MMM', locale);
      final fmtYear = DateFormat('dd MMM yyyy', locale);
      final s = provider.selectedRange!.start;
      final e = provider.selectedRange!.end;
      return s.year == e.year
          ? '${fmt.format(s)} – ${fmtYear.format(e)}'
          : '${fmtYear.format(s)} – ${fmtYear.format(e)}';
    }
    // Día único
    final now = DateTime.now();
    final d = provider.selectedDate;
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Hoy';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Ayer';
    }
    return DateFormat('EEE, dd MMM yyyy', 'es').format(d);
  }

  IconData get _modeIcon {
    if (_isYearMode) return Icons.event_repeat_rounded;
    if (_isMonthMode) return Icons.calendar_view_month_rounded;
    if (_isRangeMode) return Icons.date_range_rounded;
    return Icons.calendar_today_rounded;
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withAlpha(120)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ← Prev (solo en modo día)
          _NavIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Día anterior',
            onPressed: _isDayMode
                ? () => onDateChanged(
                    provider.selectedDate.subtract(const Duration(days: 1)),
                  )
                : null,
          ),

          // Label central — tap = seleccionar día
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDay(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_modeIcon, size: 15, color: cs.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _buildLabel(context),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Menú de opciones de modo
          _ModeMenuButton(
            activeMode: provider.dateMode,
            onPickDay: () => _pickDay(context),
            onPickRange: () => _pickRange(context),
            onPickMonth: () => _pickMonth(context),
            onPickYear: () => _pickYear(context),
          ),

          // → Next (solo en modo día y si no es hoy)
          _NavIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Día siguiente',
            onPressed: _canGoForward
                ? () => onDateChanged(
                    provider.selectedDate.add(const Duration(days: 1)),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  // ── pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickDay(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _isDayMode ? provider.selectedDate : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(today) ? today : initial,
      firstDate: DateTime(2020),
      lastDate: today,
      locale: const Locale('es'),
    );
    if (picked != null) {
      onDateChanged(picked);
    }
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialRange =
        provider.selectedRange ??
        DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: today,
      locale: const Locale('es'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          appBarTheme: AppBarTheme(
            backgroundColor: Theme.of(ctx).colorScheme.primary,
            foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      onRangeChanged(picked);
    }
  }

  Future<void> _pickMonth(BuildContext context) async {
    final now = DateTime.now();
    final initial = provider.selectedMonth ?? DateTime(now.year, now.month);

    final picked = await showMonthPicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month),
    );
    if (picked != null) {
      onMonthChanged(picked.year, picked.month);
    }
  }

  Future<void> _pickYear(BuildContext context) async {
    final now = DateTime.now();
    final initialYear = provider.selectedYear ?? now.year;

    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        DateTime selectedDt = DateTime(initialYear);
        return AlertDialog(
          title: const Text('Seleccionar año'),
          contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
          content: SizedBox(
            width: 280,
            height: 220,
            child: StatefulBuilder(
              builder: (ctx, setState) => YearPicker(
                firstDate: DateTime(2020),
                lastDate: now,
                selectedDate: selectedDt,
                onChanged: (dt) {
                  Navigator.of(ctx).pop(dt.year);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      onYearChanged(picked);
    }
  }
}

// ── Menú de selección de modo ─────────────────────────────────────────────────

enum _DateMode { day, range, month, year }

class _ModeMenuButton extends StatelessWidget {
  const _ModeMenuButton({
    required this.activeMode,
    required this.onPickDay,
    required this.onPickRange,
    required this.onPickMonth,
    required this.onPickYear,
  });

  final ReportDateMode activeMode;
  final VoidCallback onPickDay;
  final VoidCallback onPickRange;
  final VoidCallback onPickMonth;
  final VoidCallback onPickYear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<_DateMode>(
      icon: Icon(Icons.tune_rounded, size: 20, color: cs.primary),
      tooltip: 'Cambiar tipo de período',
      onSelected: (mode) {
        switch (mode) {
          case _DateMode.day:
            onPickDay();
          case _DateMode.range:
            onPickRange();
          case _DateMode.month:
            onPickMonth();
          case _DateMode.year:
            onPickYear();
        }
      },
      itemBuilder: (_) => [
        _menuItem(
          context,
          value: _DateMode.day,
          icon: Icons.calendar_today_rounded,
          label: 'Seleccionar día',
          active: activeMode == ReportDateMode.singleDay,
        ),
        _menuItem(
          context,
          value: _DateMode.range,
          icon: Icons.date_range_rounded,
          label: 'Seleccionar rango',
          active: activeMode == ReportDateMode.dateRange,
        ),
        _menuItem(
          context,
          value: _DateMode.month,
          icon: Icons.calendar_view_month_rounded,
          label: 'Seleccionar mes',
          active: activeMode == ReportDateMode.monthPick,
        ),
        _menuItem(
          context,
          value: _DateMode.year,
          icon: Icons.event_repeat_rounded,
          label: 'Seleccionar año',
          active: activeMode == ReportDateMode.yearPick,
        ),
      ],
    );
  }

  PopupMenuItem<_DateMode> _menuItem(
    BuildContext context, {
    required _DateMode value,
    required IconData icon,
    required String label,
    required bool active,
  }) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuItem<_DateMode>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? cs.primary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: active ? cs.primary : cs.onSurface,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (active) ...[
            const Spacer(),
            Icon(Icons.check_rounded, size: 16, color: cs.primary),
          ],
        ],
      ),
    );
  }
}

// ── Botón icono de navegación ─────────────────────────────────────────────────

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = onPressed != null ? cs.onSurface : cs.onSurface.withAlpha(60);
    return IconButton(
      icon: Icon(icon, color: color, size: 22),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      splashRadius: 20,
    );
  }
}
