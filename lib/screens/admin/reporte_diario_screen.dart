import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../providers/sucursal_provider.dart';

class ReporteDiarioScreen extends StatefulWidget {
  const ReporteDiarioScreen({Key? key}) : super(key: key);

  @override
  State<ReporteDiarioScreen> createState() => _ReporteDiarioScreenState();
}

class _ReporteDiarioScreenState extends State<ReporteDiarioScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _dailyReport;
  bool _isLoading = false;
  String? _error;

  // Sucursal provider
  SucursalProvider? _sucursalProvider;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Usar fecha actual del dispositivo
    _updateCurrentDate();

    // Iniciar timer que refresca reporte cada 10 segundos mientras la pantalla esté montada
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (t) {
      if (mounted) {
        _updateCurrentDate(); // Actualizar fecha por si cambia el día
        _fetchDaily();
      }
    });
  }

  void _updateCurrentDate() {
    final now = DateTime.now();
    final newDate = '${now.year.toString().padLeft(4,'0')}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    if (_start != newDate) {
      setState(() {
        _start = newDate;
        _end = newDate;
      });
    }
  }

  Future<void> _fetchDaily() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final r = await _api.getDailyReport(start: _start, end: _end, sucursalId: _selectedSucursalId);
      print('ReporteDiarioScreen: received report data: $r');
      print('ReporteDiarioScreen: totalPayments=${r['totalPayments']}, pendingDebt=${r['pendingDebt']}, totalTickets=${r['totalTickets']}');
      setState(() {
        _dailyReport = r;
      });
    } catch (e) {
      print('ReporteDiarioScreen: error fetching daily report: $e');
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() {
        _isLoading = false;
      });
    }
  }

  // Sucursales
  List<dynamic>? _sucursales;
  int? _selectedSucursalId;

  // Fecha
  String? _start;
  String? _end;

  Future<void> _loadSucursales() async {
    try {
      final s = await _api.getSucursales();
      setState(() => _sucursales = s);
    } catch (e) {
      // ignore
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // cargar sucursales una sola vez
    if (_sucursales == null) _loadSucursales();

    // Obtener provider de sucursal desde el Inherited widget y suscribirse a cambios
    final provider = SucursalInherited.of(context);
    if (provider != _sucursalProvider) {
      _sucursalProvider?.removeListener(_onSucursalChanged);
      _sucursalProvider = provider;
      _sucursalProvider?.addListener(_onSucursalChanged);
      // sincronizar filtro local con la sucursal seleccionada global por defecto
      setState(() {
        _selectedSucursalId = _sucursalProvider?.selectedSucursalId;
      });
      // refrescar reporte con la sucursal actual
      _fetchDaily();
    }
  }

  void _onSucursalChanged() {
    // Cuando cambia la sucursal desde el slidebar, sincronizar y recargar
    setState(() {
      _selectedSucursalId = _sucursalProvider?.selectedSucursalId;
    });
    _fetchDaily();
  }

  @override
  void dispose() {
    _sucursalProvider?.removeListener(_onSucursalChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Normalizar lista byDay para evitar accesos nulos
    final List<Map<String, dynamic>> byDayList = List<Map<String, dynamic>>.from((_dailyReport?['byDay'] as List?) ?? []);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Diario'),
        // Exportar removido por pedido del cliente
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mostrar sucursal y fecha (sin selector)
                      Row(children: [
                        Expanded(child: Text('Sucursal: ${_sucursalProvider?.selectedSucursalName ?? '—'}', style: Theme.of(context).textTheme.bodyLarge)),
                        const SizedBox(width: 12),
                        // Fecha (hoy)
                        ElevatedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_start ?? ''),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        )
                      ]),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildStatCard('Total Ingresos Netos (hoy)', 'Bs ${_formatNumber(_dailyReport?['totalPayments'])}')),
                          const SizedBox(width: 10),
                          Expanded(child: _buildStatCard('Deuda Pendiente (hoy)', 'Bs ${_formatNumber(_dailyReport?['pendingDebt'])}')),
                          const SizedBox(width: 10),
                          Expanded(child: _buildStatCard('Total Tickets (hoy)', '${_dailyReport?['totalTickets'] ?? 0}')),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Reemplazamos la lista "Por día" por un gráfico de barras pequeño
                      const Text('Resumen por día', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: byDayList.isEmpty
                            ? Center(child: Text('No hay datos para mostrar', style: Theme.of(context).textTheme.bodyLarge))
                            : _MiniBarChart(data: byDayList),
                      )
                    ],
                  ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0.0';
    if (value is num) return value.toStringAsFixed(2);
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed?.toStringAsFixed(2) ?? '0.0';
    }
    return value.toString();
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _MiniBarChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tomamos los últimos 7 días si hay muchos
    final list = data.length > 7 ? data.sublist(data.length - 7) : data;
    double maxVal = 0;
    for (final d in list) {
      final p = (d['payments'] is String) ? double.tryParse(d['payments']) ?? 0 : (d['payments'] ?? 0.0);
      final pd = (d['pendingDebt'] is String) ? double.tryParse(d['pendingDebt']) ?? 0 : (d['pendingDebt'] ?? 0.0);
      maxVal = [maxVal, p, pd].reduce((a, b) => a > b ? a : b);
    }
    if (maxVal <= 0) maxVal = 1;

    return LayoutBuilder(builder: (context, constraints) {
       return Row(
         crossAxisAlignment: CrossAxisAlignment.end,
         children: list.map((d) {
           final payments = (d['payments'] is String) ? double.tryParse(d['payments']) ?? 0 : (d['payments'] ?? 0.0);
           final pending = (d['pendingDebt'] is String) ? double.tryParse(d['pendingDebt']) ?? 0 : (d['pendingDebt'] ?? 0.0);
           final payH = (payments / maxVal) * (constraints.maxHeight - 40);
           final debtH = (pending / maxVal) * (constraints.maxHeight - 40);
           return Expanded(
             child: Padding(
               padding: const EdgeInsets.symmetric(horizontal: 4.0),
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   // Barras apiladas (payments arriba en color primario, deuda en secundario)
                   Stack(
                     alignment: Alignment.bottomCenter,
                     children: [
                       Container(height: debtH, width: double.infinity, decoration: BoxDecoration(color: Colors.redAccent.withAlpha(120), borderRadius: BorderRadius.circular(6))),
                       Container(height: payH, width: double.infinity, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(6))),
                     ],
                   ),
                   const SizedBox(height: 6),
                   Text(d['date']?.toString().split('-').last ?? '', style: Theme.of(context).textTheme.bodySmall),
                 ],
               ),
             ),
           );
         }).toList(),
       );
     });
   }
}
