import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../providers/sucursal_provider.dart';
import 'package:app_estetica/navigation/route_observer.dart';
import 'package:app_estetica/widgets/report_chart.dart';

class ReporteRangoScreen extends StatefulWidget {
  const ReporteRangoScreen({Key? key}) : super(key: key);

  @override
  State<ReporteRangoScreen> createState() => _ReporteRangoScreenState();
}

class _ReporteRangoScreenState extends State<ReporteRangoScreen> with RouteAware {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;

  String? _start;
  String? _end;

  SucursalProvider? _sucursalProvider;
  int? _sucursalId;

  bool _routeSubscribed = false;

  @override
  void initState() {
    super.initState();
    // Default: current month
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));
    _start = '${start.year.toString().padLeft(4,'0')}-${start.month.toString().padLeft(2,'0')}-${start.day.toString().padLeft(2,'0')}';
    _end = '${end.year.toString().padLeft(4,'0')}-${end.month.toString().padLeft(2,'0')}-${end.day.toString().padLeft(2,'0')}';

    // No iniciamos un timer periódico: la pantalla se refrescará solo al entrar
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

    // Subscribe to route observer to refresh when returning to this route
    if (!_routeSubscribed) {
      final modal = ModalRoute.of(context);
      if (modal != null) {
        routeObserver.subscribe(this, modal);
        _routeSubscribed = true;
      }
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
    if (_routeSubscribed) {
      routeObserver.unsubscribe(this);
      _routeSubscribed = false;
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    // When returning to this screen, refetch current report
    _fetch();
  }

  @override
  void didPushNext() {}

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
                          : ReportChart(data: byDayList, isBar: true),
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

