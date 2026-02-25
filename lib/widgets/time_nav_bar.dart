import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:app_estetica/providers/reports_provider.dart';

/// Selector de tiempo reutilizable (día / rango / mes / año) para pantallas
/// que necesitan filtrar por fechas (ej: Tickets).
class TimeNavBar extends StatefulWidget {
  const TimeNavBar({
    super.key,
    required this.mode,
    required this.selectedDate,
    this.selectedRange,
    this.selectedMonth,
    this.selectedYear,
    required this.onDateChanged,
    required this.onRangeChanged,
    required this.onMonthChanged,
    required this.onYearChanged,
    this.allowFuture = false,
  });

  final ReportDateMode mode;
  final DateTime selectedDate;
  final DateTimeRange? selectedRange;
  final DateTime? selectedMonth;
  final int? selectedYear;

  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<DateTimeRange> onRangeChanged;
  final void Function(int year, int month) onMonthChanged;
  final ValueChanged<int> onYearChanged;

  /// Si es true, los pickers permiten seleccionar fechas futuras.
  /// Útil para pantallas de sesiones/agenda donde existen citas futuras.
  final bool allowFuture;

  @override
  State<TimeNavBar> createState() => _TimeNavBarState();
}

class _TimeNavBarState extends State<TimeNavBar> {
  late ReportDateMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
  }

  bool get _isDayMode =>
      _mode == ReportDateMode.singleDay || _mode == ReportDateMode.period;

  bool get _canGoForward {
    if (!_isDayMode) return false;
    if (widget.allowFuture) return true;
    final now = DateTime.now();
    final d = widget.selectedDate;
    return !(d.year == now.year && d.month == now.month && d.day == now.day);
  }

  IconData get _modeIcon {
    if (_mode == ReportDateMode.yearPick) return Icons.event_repeat_rounded;
    if (_mode == ReportDateMode.monthPick) {
      return Icons.calendar_view_month_rounded;
    }
    if (_mode == ReportDateMode.dateRange) return Icons.date_range_rounded;
    return Icons.calendar_today_rounded;
  }

  String _buildLabel(BuildContext context) {
    if (_mode == ReportDateMode.yearPick && widget.selectedYear != null) {
      return 'Año ${widget.selectedYear}';
    }
    if (_mode == ReportDateMode.monthPick && widget.selectedMonth != null) {
      return DateFormat('MMMM yyyy', 'es').format(widget.selectedMonth!);
    }
    if (_mode == ReportDateMode.dateRange && widget.selectedRange != null) {
      final locale = Localizations.localeOf(context).toString();
      final fmt = DateFormat('dd MMM', locale);
      final fmtYear = DateFormat('dd MMM yyyy', locale);
      final s = widget.selectedRange!.start;
      final e = widget.selectedRange!.end;
      return s.year == e.year
          ? '${fmt.format(s)} – ${fmtYear.format(e)}'
          : '${fmtYear.format(s)} – ${fmtYear.format(e)}';
    }
    final now = DateTime.now();
    final d = widget.selectedDate;
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

  Future<void> _pickDay(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = widget.allowFuture
        ? DateTime(now.year + 2, 12, 31)
        : today;
    final initial = widget.selectedDate.isAfter(lastDate)
        ? lastDate
        : widget.selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      locale: const Locale('es'),
    );
    if (picked != null) widget.onDateChanged(picked);
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = widget.allowFuture
        ? DateTime(now.year + 2, 12, 31)
        : today;
    final initialRange =
        widget.selectedRange ??
        DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      locale: const Locale('es'),
    );
    if (picked != null) widget.onRangeChanged(picked);
  }

  Future<void> _pickMonth(BuildContext context) async {
    final now = DateTime.now();
    final initial = widget.selectedMonth ?? DateTime(now.year, now.month);
    final picked = await showMonthPicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month),
    );
    if (picked != null) widget.onMonthChanged(picked.year, picked.month);
  }

  Future<void> _pickYear(BuildContext context) async {
    final now = DateTime.now();
    final initialYear = widget.selectedYear ?? now.year;

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
    if (picked != null) widget.onYearChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withAlpha(120)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Prev
          IconButton(
            icon: Icon(
              Icons.chevron_left_rounded,
              color: _isDayMode ? cs.onSurface : cs.onSurface.withAlpha(60),
            ),
            onPressed: _isDayMode
                ? () => widget.onDateChanged(
                    widget.selectedDate.subtract(const Duration(days: 1)),
                  )
                : null,
            visualDensity: VisualDensity.compact,
            splashRadius: 20,
          ),
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
          PopupMenuButton<ReportDateMode>(
            icon: Icon(Icons.tune_rounded, size: 20, color: cs.primary),
            tooltip: 'Cambiar tipo de período',
            onSelected: (mode) {
              setState(() => _mode = mode);
              switch (mode) {
                case ReportDateMode.period:
                case ReportDateMode.singleDay:
                  _pickDay(context);
                  break;
                case ReportDateMode.dateRange:
                  _pickRange(context);
                  break;
                case ReportDateMode.monthPick:
                  _pickMonth(context);
                  break;
                case ReportDateMode.yearPick:
                  _pickYear(context);
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: ReportDateMode.singleDay,
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: _mode == ReportDateMode.singleDay
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Seleccionar día',
                      style: TextStyle(
                        color: _mode == ReportDateMode.singleDay
                            ? cs.primary
                            : cs.onSurface,
                      ),
                    ),
                    if (_mode == ReportDateMode.singleDay) ...[
                      const Spacer(),
                      Icon(Icons.check_rounded, size: 16),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: ReportDateMode.dateRange,
                child: Row(
                  children: [
                    Icon(
                      Icons.date_range_rounded,
                      size: 18,
                      color: _mode == ReportDateMode.dateRange
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Seleccionar rango',
                      style: TextStyle(
                        color: _mode == ReportDateMode.dateRange
                            ? cs.primary
                            : cs.onSurface,
                      ),
                    ),
                    if (_mode == ReportDateMode.dateRange) ...[
                      const Spacer(),
                      Icon(Icons.check_rounded, size: 16),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: ReportDateMode.monthPick,
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_view_month_rounded,
                      size: 18,
                      color: _mode == ReportDateMode.monthPick
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Seleccionar mes',
                      style: TextStyle(
                        color: _mode == ReportDateMode.monthPick
                            ? cs.primary
                            : cs.onSurface,
                      ),
                    ),
                    if (_mode == ReportDateMode.monthPick) ...[
                      const Spacer(),
                      Icon(Icons.check_rounded, size: 16),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: ReportDateMode.yearPick,
                child: Row(
                  children: [
                    Icon(
                      Icons.event_repeat_rounded,
                      size: 18,
                      color: _mode == ReportDateMode.yearPick
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Seleccionar año',
                      style: TextStyle(
                        color: _mode == ReportDateMode.yearPick
                            ? cs.primary
                            : cs.onSurface,
                      ),
                    ),
                    if (_mode == ReportDateMode.yearPick) ...[
                      const Spacer(),
                      Icon(Icons.check_rounded, size: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: _canGoForward ? cs.onSurface : cs.onSurface.withAlpha(60),
            ),
            onPressed: _canGoForward
                ? () => widget.onDateChanged(
                    widget.selectedDate.add(const Duration(days: 1)),
                  )
                : null,
            visualDensity: VisualDensity.compact,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
