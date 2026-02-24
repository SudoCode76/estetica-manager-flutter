import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Barra de navegación de fechas para reportes históricos.
///
/// Permite al usuario:
/// - Avanzar / retroceder un día.
/// - Abrir el selector de calendario (día único).
/// - Abrir el selector de rango de fechas.
///
/// Callbacks:
/// - [onDateChanged] — se llama con el nuevo [DateTime] cuando el usuario
///   navega por días o selecciona una fecha en el calendario.
/// - [onRangeChanged] — se llama con el [DateTimeRange] cuando el usuario
///   selecciona un rango.
class DateNavBar extends StatelessWidget {
  const DateNavBar({
    super.key,
    required this.selectedDate,
    required this.selectedRange,
    required this.isRangeMode,
    required this.onDateChanged,
    required this.onRangeChanged,
  });

  /// Fecha activa cuando [isRangeMode] es `false`.
  final DateTime selectedDate;

  /// Rango activo cuando [isRangeMode] es `true`.
  final DateTimeRange? selectedRange;

  /// Si `true`, muestra el label del rango; si `false`, muestra el día.
  final bool isRangeMode;

  /// Callback para día único / navegación prev-next.
  final ValueChanged<DateTime> onDateChanged;

  /// Callback para rango de fechas.
  final ValueChanged<DateTimeRange> onRangeChanged;

  // ── helpers ──────────────────────────────────────────────────────────────

  bool get _isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  bool get _canGoForward {
    // No permitir ir más allá de hoy.
    if (isRangeMode) {
      final rangeEnd = selectedRange?.end;
      if (rangeEnd == null) return false;
      final now = DateTime.now();
      return rangeEnd.isBefore(DateTime(now.year, now.month, now.day));
    }
    return !_isToday;
  }

  String _buildLabel(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    if (isRangeMode && selectedRange != null) {
      final fmt = DateFormat('dd MMM', locale);
      final fmtYear = DateFormat('dd MMM yyyy', locale);
      final s = selectedRange!.start;
      final e = selectedRange!.end;
      if (s.year == e.year) {
        return '${fmt.format(s)} – ${fmtYear.format(e)}';
      }
      return '${fmtYear.format(s)} – ${fmtYear.format(e)}';
    }

    // Día único
    final now = DateTime.now();
    if (selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day) {
      return 'Hoy';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (selectedDate.year == yesterday.year &&
        selectedDate.month == yesterday.month &&
        selectedDate.day == yesterday.day) {
      return 'Ayer';
    }
    return DateFormat('EEE, dd MMM yyyy', 'es').format(selectedDate);
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
          // ← Prev
          _NavIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Día anterior',
            onPressed: isRangeMode
                ? null
                : () => onDateChanged(
                    selectedDate.subtract(const Duration(days: 1)),
                  ),
          ),

          // Label + calendario
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDate(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isRangeMode
                        ? Icons.date_range_rounded
                        : Icons.calendar_today_rounded,
                    size: 15,
                    color: cs.primary,
                  ),
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

          // Botón rango
          _NavIconButton(
            icon: Icons.date_range_rounded,
            tooltip: 'Seleccionar rango',
            color: isRangeMode ? cs.primary : null,
            onPressed: () => _pickRange(context),
          ),

          // → Next
          _NavIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Día siguiente',
            onPressed: _canGoForward && !isRangeMode
                ? () => onDateChanged(selectedDate.add(const Duration(days: 1)))
                : null,
          ),
        ],
      ),
    );
  }

  // ── pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: isRangeMode ? today : selectedDate,
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
        selectedRange ??
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            appBarTheme: AppBarTheme(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onRangeChanged(picked);
    }
  }
}

// ── Widget auxiliar ──────────────────────────────────────────────────────────

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor =
        color ??
        (onPressed != null ? cs.onSurface : cs.onSurface.withAlpha(60));
    return IconButton(
      icon: Icon(icon, color: effectiveColor, size: 22),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      splashRadius: 20,
    );
  }
}
