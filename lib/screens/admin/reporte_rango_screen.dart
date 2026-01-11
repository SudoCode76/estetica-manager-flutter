import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../providers/sucursal_provider.dart';

class ReporteRangoScreen extends StatefulWidget {
  const ReporteRangoScreen({Key? key}) : super(key: key);

  @override
  State<ReporteRangoScreen> createState() => _ReporteRangoScreenState();
}

class _ReporteRangoScreenState extends State<ReporteRangoScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;

  String? _start;
  String? _end;

  SucursalProvider? _sucursalProvider;
  int? _sucursalId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Default: current month
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));
    _start = '${start.year.toString().padLeft(4,'0')}-${start.month.toString().padLeft(2,'0')}-${start.day.toString().padLeft(2,'0')}';
    _end = '${end.year.toString().padLeft(4,'0')}-${end.month.toString().padLeft(2,'0')}-${end.day.toString().padLeft(2,'0')}';

    // refrescar automáticamente cada 6 segundos para que los totales se mantengan actualizados
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (t) {
      if (mounted) _fetch();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = SucursalInherited.of(context);
    if (provider != _sucursalProvider) {
      _sucursalProvider?.removeListener(_onSucursalChanged);
      _sucursalProvider = provider;
      _sucursalProvider?.addListener(_onSucursalChanged);
      setState(() {
        _sucursalId = _sucursalProvider?.selectedSucursalId;
      });
      _fetch();
    }
  }

  void _onSucursalChanged() {
    setState(() {
      _sucursalId = _sucursalProvider?.selectedSucursalId;
    });
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.getDailyReport(start: _start, end: _end, sucursalId: _sucursalId);
      setState(() => _report = r);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initialStart = DateTime(now.year, now.month, 1);
    final initialEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );
    if (picked != null) {
      setState(() {
        _start = '${picked.start.year.toString().padLeft(4,'0')}-${picked.start.month.toString().padLeft(2,'0')}-${picked.start.day.toString().padLeft(2,'0')}';
        _end = '${picked.end.year.toString().padLeft(4,'0')}-${picked.end.month.toString().padLeft(2,'0')}-${picked.end.day.toString().padLeft(2,'0')}';
      });
      await _fetch();
    }
  }

  @override
  void dispose() {
    _sucursalProvider?.removeListener(_onSucursalChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sucName = _sucursalProvider?.selectedSucursalName ?? '—';
    final byDayList = List<Map<String, dynamic>>.from((_report?['byDay'] as List?) ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Mensual'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header compacto
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.store_rounded,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sucName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonalIcon(
                                  onPressed: _pickRange,
                                  icon: const Icon(Icons.date_range_rounded, size: 18),
                                  label: Text('${_formatDateShort(_start)} → ${_formatDateShort(_end)}'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tarjetas de resumen compactas
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return constraints.maxWidth > 600
                              ? Row(
                                  children: [
                                    Expanded(child: _compactStatCard('Total Ingresos', 'Bs ${_formatNumber(_report?['totalPayments'])}', Icons.trending_up_rounded, Colors.green)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _compactStatCard('Deuda Pendiente', 'Bs ${_formatNumber(_report?['pendingDebt'])}', Icons.warning_amber_rounded, Colors.orange)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _compactStatCard('Total Tickets', '${_report?['totalTickets'] ?? 0}', Icons.receipt_long_rounded, Theme.of(context).colorScheme.primary)),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _compactStatCard('Total Ingresos', 'Bs ${_formatNumber(_report?['totalPayments'])}', Icons.trending_up_rounded, Colors.green),
                                    const SizedBox(height: 8),
                                    _compactStatCard('Deuda Pendiente', 'Bs ${_formatNumber(_report?['pendingDebt'])}', Icons.warning_amber_rounded, Colors.orange),
                                    const SizedBox(height: 8),
                                    _compactStatCard('Total Tickets', '${_report?['totalTickets'] ?? 0}', Icons.receipt_long_rounded, Theme.of(context).colorScheme.primary),
                                  ],
                                );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Título del gráfico compacto
                      Row(
                        children: [
                          Icon(
                            Icons.bar_chart_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isMultiMonth() ? 'Comparativa por Meses' : 'Comparativa por Días',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: _fetch,
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Gráfico
                      byDayList.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bar_chart_rounded, size: 48, color: Theme.of(context).colorScheme.outlineVariant),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No hay datos para el rango seleccionado',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _RangeChart(
                              data: byDayList,
                              isMultiMonth: _isMultiMonth(),
                            ),
                    ],
                  ),
      ),
    );
  }

  bool _isMultiMonth() {
    if (_start == null || _end == null) return false;
    try {
      final startDate = DateTime.parse(_start!);
      final endDate = DateTime.parse(_end!);
      final diff = endDate.difference(startDate).inDays;
      return diff > 35; // Más de un mes
    } catch (_) {
      return false;
    }
  }

  String _formatDateShort(String? date) {
    if (date == null) return '';
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}';
      }
    } catch (_) {}
    return date;
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0.00';
    if (value is num) return value.toStringAsFixed(2);
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed?.toStringAsFixed(2) ?? '0.00';
    }
    return value.toString();
  }

  Widget _compactStatCard(String title, String value, IconData icon, Color iconColor) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// Widget de gráfico para el reporte de rango
class _RangeChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool isMultiMonth;

  const _RangeChart({
    Key? key,
    required this.data,
    required this.isMultiMonth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Agrupar datos por mes si es multi-mes, sino por día
    final groupedData = isMultiMonth ? _groupByMonth(data) : data;

    if (groupedData.isEmpty) {
      return Center(
        child: Text('No hay datos disponibles', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Leyenda
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _LegendItem(color: Colors.green, label: 'Ingresos', icon: Icons.trending_up),
              _LegendItem(color: Colors.orange, label: 'Deuda', icon: Icons.warning_amber_rounded),
            ],
          ),

          const SizedBox(height: 24),

          // Gráfico de barras
          ...groupedData.map((item) {
            final payments = (item['payments'] is String)
                ? double.tryParse(item['payments']) ?? 0
                : (item['payments'] ?? 0.0);
            final debt = (item['pendingDebt'] is String)
                ? double.tryParse(item['pendingDebt']) ?? 0
                : (item['pendingDebt'] ?? 0.0);
            final tickets = item['tickets'] ?? 0;
            final date = item['date']?.toString() ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _ChartBar(
                label: _formatLabel(date, isMultiMonth),
                ingresos: payments,
                deuda: debt,
                tickets: tickets,
              ),
            );
          }).toList(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _groupByMonth(List<Map<String, dynamic>> data) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final item in data) {
      final date = item['date']?.toString() ?? '';
      if (date.isEmpty) continue;

      try {
        final parts = date.split('-');
        if (parts.length >= 2) {
          final monthKey = '${parts[0]}-${parts[1]}'; // YYYY-MM

          if (!grouped.containsKey(monthKey)) {
            grouped[monthKey] = {
              'date': monthKey,
              'payments': 0.0,
              'pendingDebt': 0.0,
              'tickets': 0,
            };
          }

          final p = (item['payments'] is String)
              ? double.tryParse(item['payments']) ?? 0
              : (item['payments'] ?? 0.0);
          final pd = (item['pendingDebt'] is String)
              ? double.tryParse(item['pendingDebt']) ?? 0
              : (item['pendingDebt'] ?? 0.0);
          final t = item['tickets'] ?? 0;

          grouped[monthKey]!['payments'] = (grouped[monthKey]!['payments'] as double) + p;
          grouped[monthKey]!['pendingDebt'] = (grouped[monthKey]!['pendingDebt'] as double) + pd;
          grouped[monthKey]!['tickets'] = (grouped[monthKey]!['tickets'] as int) + (t as int);
        }
      } catch (_) {}
    }

    final result = grouped.values.toList();
    result.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));
    return result;
  }

  String _formatLabel(String date, bool isMonth) {
    if (date.isEmpty) return '';
    try {
      final parts = date.split('-');
      if (isMonth && parts.length >= 2) {
        // Formato: Mes Año (Ej: Enero 2026)
        final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
        final monthIdx = int.parse(parts[1]) - 1;
        return '${months[monthIdx]} ${parts[0]}';
      } else if (parts.length == 3) {
        // Formato: DD/MM
        return '${parts[2]}/${parts[1]}';
      }
    } catch (_) {}
    return date;
  }
}

class _ChartBar extends StatelessWidget {
  final String label;
  final double ingresos;
  final double deuda;
  final int tickets;

  const _ChartBar({
    Key? key,
    required this.label,
    required this.ingresos,
    required this.deuda,
    required this.tickets,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = ingresos > deuda ? ingresos : deuda;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label del período
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$tickets tickets',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Barra de Ingresos
        _buildBar(
          context: context,
          value: ingresos,
          maxValue: maxValue,
          color: Colors.green,
          icon: Icons.trending_up,
          label: 'Ingresos',
        ),

        const SizedBox(height: 8),

        // Barra de Deuda
        _buildBar(
          context: context,
          value: deuda,
          maxValue: maxValue,
          color: Colors.orange,
          icon: Icons.warning_amber_rounded,
          label: 'Deuda',
        ),
      ],
    );
  }

  Widget _buildBar({
    required BuildContext context,
    required double value,
    required double maxValue,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final percentage = maxValue > 0 ? (value / maxValue) : 0.0;

    return Row(
      children: [
        // Ícono y label
        SizedBox(
          width: 80,
          child: Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),

        // Barra
        Expanded(
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.7),
                          color,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Valor
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            'Bs ${value.toStringAsFixed(0)}',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;

  const _LegendItem({
    Key? key,
    required this.color,
    required this.label,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

