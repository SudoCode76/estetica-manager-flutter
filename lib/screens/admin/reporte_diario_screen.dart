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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final List<Map<String, dynamic>> byDayList = List<Map<String, dynamic>>.from((_dailyReport?['byDay'] as List?) ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Diario'),
        elevation: 0,
        surfaceTintColor: colorScheme.surfaceTint,
        backgroundColor: colorScheme.surface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                      const SizedBox(height: 16),
                      Text('Error: $_error', style: theme.textTheme.bodyLarge),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header compacto con sucursal y fecha
                      Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primaryContainer,
                              colorScheme.primaryContainer.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.store_rounded,
                                color: colorScheme.onPrimary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Sucursal',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    _sucursalProvider?.selectedSucursalName ?? '—',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today, size: 14, color: colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    _start ?? '',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tarjetas de métricas compactas
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth > 600 ? 3 : 1;
                            return GridView.count(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: crossAxisCount == 3 ? 3.5 : 5.0,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildCompactStatCard(
                                  context,
                                  'Total Ingresos Netos',
                                  'Bs ${_formatNumber(_dailyReport?['totalPayments'])}',
                                  Icons.trending_up_rounded,
                                  Colors.green,
                                ),
                                _buildCompactStatCard(
                                  context,
                                  'Deuda Pendiente',
                                  'Bs ${_formatNumber(_dailyReport?['pendingDebt'])}',
                                  Icons.warning_amber_rounded,
                                  Colors.orange,
                                ),
                                _buildCompactStatCard(
                                  context,
                                  'Total Tickets',
                                  '${_dailyReport?['totalTickets'] ?? 0}',
                                  Icons.receipt_long_rounded,
                                  colorScheme.primary,
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tarjetas de métricas compactas
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.insights_rounded,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Comparativa Ingresos vs Deuda',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Gráfico compacto
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: byDayList.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.bar_chart_rounded, size: 48, color: colorScheme.outlineVariant),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No hay datos para mostrar',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : _MiniBarChart(data: byDayList),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCompactStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
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

  Widget _buildModernStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
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
}

class _MiniBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _MiniBarChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Si no hay datos, mostrar mensaje
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No hay datos para mostrar', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),
          ],
        ),
      );
    }

    // Calcular totales
    double totalIngresos = 0;
    double totalDeuda = 0;
    int totalTickets = 0;

    for (final d in data) {
      final p = (d['payments'] is String) ? double.tryParse(d['payments']) ?? 0 : (d['payments'] ?? 0.0);
      final pd = (d['pendingDebt'] is String) ? double.tryParse(d['pendingDebt']) ?? 0 : (d['pendingDebt'] ?? 0.0);
      final t = d['tickets'] ?? 0;
      totalIngresos += p;
      totalDeuda += pd;
      totalTickets += t as int;
    }

    final maxValue = totalIngresos > totalDeuda ? totalIngresos : totalDeuda;
    if (maxValue == 0) {
      return Center(
        child: Text('No hay movimientos registrados', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 4),

          // Barra de Ingresos
          _buildBarItem(
            context: context,
            label: 'Total Ingresos',
            value: totalIngresos,
            maxValue: maxValue,
            color: Colors.green,
            icon: Icons.trending_up,
          ),

          const SizedBox(height: 12),

          // Barra de Deuda
          _buildBarItem(
            context: context,
            label: 'Total Deuda Pendiente',
            value: totalDeuda,
            maxValue: maxValue,
            color: Colors.orange,
            icon: Icons.warning_amber_rounded,
          ),

          const SizedBox(height: 12),

          // Información adicional compacta
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoChip(
                  context: context,
                  icon: Icons.receipt_long,
                  label: 'Tickets',
                  value: totalTickets.toString(),
                  color: theme.colorScheme.primary,
                ),
                Container(
                  width: 1,
                  height: 25,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                _buildInfoChip(
                  context: context,
                  icon: Icons.calendar_today,
                  label: 'Días',
                  value: data.length.toString(),
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildBarItem({
    required BuildContext context,
    required String label,
    required double value,
    required double maxValue,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final percentage = maxValue > 0 ? (value / maxValue) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label con ícono
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const Spacer(),
            Text(
              'Bs ${value.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Barra de progreso
        Container(
          height: 28,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              // Barra de color
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
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Texto centrado
              Center(
                child: Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: percentage > 0.5 ? Colors.white : Colors.grey[800],
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
