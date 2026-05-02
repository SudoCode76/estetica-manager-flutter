import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:app_estetica/providers/finance_provider.dart';
import 'package:app_estetica/providers/reports_provider.dart';

class FinanceDateNavBar extends StatelessWidget {
  const FinanceDateNavBar({
    super.key,
    required this.provider,
    required this.onDateChanged,
    required this.onRangeChanged,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  final FinanceProvider provider;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<DateTimeRange> onRangeChanged;
  final void Function(int year, int month) onMonthChanged;
  final ValueChanged<int> onYearChanged;

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
    if (_isYearMode && provider.selectedYear != null) {
      return 'Año ${provider.selectedYear}';
    }
    if (_isMonthMode && provider.selectedMonth != null) {
      return DateFormat('MMMM yyyy', 'es').format(provider.selectedMonth!);
    }
    if (_isRangeMode && provider.selectedRange != null) {
      final locale = Localizations.localeOf(context).toString();
      final fmt = DateFormat('dd MMM', locale);
      final fmtYear = DateFormat('dd MMM yyyy', locale);
      final s = provider.selectedRange!.start;
      final e = provider.selectedRange!.end;
      return s.year == e.year
          ? '${fmt.format(s)} - ${fmtYear.format(e)}'
          : '${fmtYear.format(s)} - ${fmtYear.format(e)}';
    }

    final now = DateTime.now();
    final d = provider.selectedDate;
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Hoy';
    }

    return DateFormat('EEE, dd MMM yyyy', 'es').format(d);
  }

  IconData get _modeIcon {
    if (_isYearMode) return Icons.event_repeat_rounded;
    if (_isMonthMode) return Icons.calendar_view_month_rounded;
    if (_isRangeMode) return Icons.date_range_rounded;
    return Icons.calendar_today_rounded;
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
        children: [
          _FinanceNavIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Día anterior',
            onPressed: _isDayMode
                ? () => onDateChanged(
                    provider.selectedDate.subtract(const Duration(days: 1)),
                  )
                : null,
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
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _FinanceModeMenuButton(
            activeMode: provider.dateMode,
            onPickDay: () => _pickDay(context),
            onPickRange: () => _pickRange(context),
            onPickMonth: () => _pickMonth(context),
            onPickYear: () => _pickYear(context),
          ),
          _FinanceNavIconButton(
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
        final selectedDate = DateTime(initialYear);
        return AlertDialog(
          title: const Text('Seleccionar año'),
          content: SizedBox(
            width: 280,
            height: 220,
            child: YearPicker(
              firstDate: DateTime(2020),
              lastDate: now,
              selectedDate: selectedDate,
              onChanged: (dt) => Navigator.of(ctx).pop(dt.year),
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

enum _FinanceDateMode { day, range, month, year }

class _FinanceModeMenuButton extends StatelessWidget {
  const _FinanceModeMenuButton({
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

    return PopupMenuButton<_FinanceDateMode>(
      icon: Icon(Icons.tune_rounded, size: 20, color: cs.primary),
      onSelected: (mode) {
        switch (mode) {
          case _FinanceDateMode.day:
            onPickDay();
          case _FinanceDateMode.range:
            onPickRange();
          case _FinanceDateMode.month:
            onPickMonth();
          case _FinanceDateMode.year:
            onPickYear();
        }
      },
      itemBuilder: (_) => [
        _menuItem(
          context,
          value: _FinanceDateMode.day,
          icon: Icons.calendar_today_rounded,
          label: 'Seleccionar día',
          active: activeMode == ReportDateMode.singleDay,
        ),
        _menuItem(
          context,
          value: _FinanceDateMode.range,
          icon: Icons.date_range_rounded,
          label: 'Seleccionar rango',
          active: activeMode == ReportDateMode.dateRange,
        ),
        _menuItem(
          context,
          value: _FinanceDateMode.month,
          icon: Icons.calendar_view_month_rounded,
          label: 'Seleccionar mes',
          active: activeMode == ReportDateMode.monthPick,
        ),
        _menuItem(
          context,
          value: _FinanceDateMode.year,
          icon: Icons.event_repeat_rounded,
          label: 'Seleccionar año',
          active: activeMode == ReportDateMode.yearPick,
        ),
      ],
    );
  }

  PopupMenuItem<_FinanceDateMode> _menuItem(
    BuildContext context, {
    required _FinanceDateMode value,
    required IconData icon,
    required String label,
    required bool active,
  }) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuItem<_FinanceDateMode>(
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? cs.primary : cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceNavIconButton extends StatelessWidget {
  const _FinanceNavIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      visualDensity: VisualDensity.compact,
    );
  }
}
