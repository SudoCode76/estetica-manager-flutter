import 'package:app_estetica/providers/finance_provider.dart';
import 'package:app_estetica/providers/reports_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';

enum FinanceQuickPreset { today, week, month }

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

  FinanceQuickPreset? get _activePreset {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_isDayMode) {
      final selected = DateTime(
        provider.selectedDate.year,
        provider.selectedDate.month,
        provider.selectedDate.day,
      );
      if (selected == today) return FinanceQuickPreset.today;
    }

    if (_isRangeMode && provider.selectedRange != null) {
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final weekEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
      final range = provider.selectedRange!;
      final selectedStart = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final selectedEnd = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );
      if (selectedStart == weekStart && selectedEnd == weekEnd) {
        return FinanceQuickPreset.week;
      }
    }

    if (_isMonthMode && provider.selectedMonth != null) {
      if (provider.selectedMonth!.year == now.year &&
          provider.selectedMonth!.month == now.month) {
        return FinanceQuickPreset.month;
      }
    }

    return null;
  }

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
    final activePreset = _activePreset;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withAlpha(110)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
            const SizedBox(width: 6),
            SegmentedButton<FinanceQuickPreset>(
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              selected: activePreset != null
                  ? <FinanceQuickPreset>{activePreset}
                  : <FinanceQuickPreset>{},
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                textStyle: WidgetStateProperty.all(
                  Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: FinanceQuickPreset.today,
                  label: Text('Hoy'),
                ),
                ButtonSegment(
                  value: FinanceQuickPreset.week,
                  label: Text('Semana'),
                ),
                ButtonSegment(
                  value: FinanceQuickPreset.month,
                  label: Text('Mes'),
                ),
              ],
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                final selected = selection.first;
                final now = DateTime.now();
                switch (selected) {
                  case FinanceQuickPreset.today:
                    onDateChanged(now);
                  case FinanceQuickPreset.week:
                    final today = DateTime(now.year, now.month, now.day);
                    onRangeChanged(
                      DateTimeRange(
                        start: today.subtract(
                          Duration(days: today.weekday - 1),
                        ),
                        end: today,
                      ),
                    );
                  case FinanceQuickPreset.month:
                    onMonthChanged(now.year, now.month);
                }
              },
            ),
            const SizedBox(width: 10),
            _CompactDateLabel(
              icon: _modeIcon,
              label: _buildLabel(context),
              onTap: () {
                if (_isDayMode) {
                  _pickDay(context);
                  return;
                }
                if (_isRangeMode) {
                  _pickRange(context);
                  return;
                }
                if (_isMonthMode) {
                  _pickMonth(context);
                  return;
                }
                _pickYear(context);
              },
            ),
            const SizedBox(width: 8),
            _FinanceQuickIconButton(
              icon: Icons.calendar_today_rounded,
              tooltip: 'Elegir día',
              onPressed: () => _pickDay(context),
            ),
            const SizedBox(width: 6),
            _FinanceQuickIconButton(
              icon: Icons.date_range_rounded,
              tooltip: 'Elegir rango',
              onPressed: () => _pickRange(context),
            ),
            const SizedBox(width: 6),
            _FinanceQuickIconButton(
              icon: Icons.event_repeat_rounded,
              tooltip: 'Elegir año',
              onPressed: () => _pickYear(context),
            ),
            const SizedBox(width: 6),
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

class _CompactDateLabel extends StatelessWidget {
  const _CompactDateLabel({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 16, color: cs.primary),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      onPressed: onTap,
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

class _FinanceQuickIconButton extends StatelessWidget {
  const _FinanceQuickIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 18, color: cs.primary),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(backgroundColor: cs.secondaryContainer),
    );
  }
}
