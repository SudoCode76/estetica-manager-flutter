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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte por Rango / Mensual'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text('Sucursal: $sucName')),
                        ElevatedButton.icon(onPressed: _pickRange, icon: const Icon(Icons.date_range), label: Text((_start ?? '') + ' → ' + (_end ?? '')))
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _statCard('Total Ingresos', 'Bs ${_report?['totalPayments'] ?? 0}')),
                        const SizedBox(width: 8),
                        Expanded(child: _statCard('Deuda Pendiente', 'Bs ${_report?['pendingDebt'] ?? 0}')),
                        const SizedBox(width: 8),
                        Expanded(child: _statCard('Total Tickets', '${_report?['totalTickets'] ?? 0}')),
                      ]),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        OutlinedButton.icon(onPressed: _fetch, icon: const Icon(Icons.refresh), label: const Text('Refrescar')),
                      ]),
                      const SizedBox(height: 8),
                      Expanded(
                        child: (_report?['byDay'] as List?)?.isEmpty ?? true
                            ? Center(child: Text('No hay datos para el rango seleccionado', style: Theme.of(context).textTheme.bodyLarge))
                            : ListView.separated(
                                itemCount: (_report?['byDay'] as List).length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final row = (_report?['byDay'] as List)[i] as Map<String, dynamic>;
                                  return ListTile(
                                    title: Text(row['date'] ?? ''),
                                    subtitle: Text('Ingresos: ${row['payments']} - Deuda: ${row['pendingDebt']} - Tickets: ${row['tickets']}'),
                                  );
                                },
                              ),
                      )
                    ],
                  ),
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title), const SizedBox(height: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
      ),
    );
  }
}
