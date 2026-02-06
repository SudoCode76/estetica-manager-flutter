import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import '../../repositories/report_repository.dart';
import '../../providers/sucursal_provider.dart';
import '../../widgets/report_chart.dart';

class ReporteVentasScreen extends StatefulWidget {
  const ReporteVentasScreen({super.key});

  @override
  State<ReporteVentasScreen> createState() => _ReporteVentasScreenState();
}

class _ReporteVentasScreenState extends State<ReporteVentasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ReportRepository _reportRepo;

  Map<String, dynamic>? _dailyReport;
  List<dynamic> _recentTransactions = [];
  bool _loadingDaily = false;
  String? _dailyError;
  String? _dailyDate;

  Map<String, dynamic>? _monthlyReport;
  List<dynamic> _debtList = [];
  bool _loadingMonthly = false;
  String? _monthlyError;
  String? _monthStart;
  String? _monthEnd;

  SucursalProvider? _sucursalProvider;
  int? _selectedSucursalId;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es');
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    final now = DateTime.now();
    _dailyDate = DateFormat('yyyy-MM-dd').format(now);
    
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    _monthStart = DateFormat('yyyy-MM-dd').format(monthStart);
    _monthEnd = DateFormat('yyyy-MM-dd').format(monthEnd);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reportRepo = Provider.of<ReportRepository>(context, listen: false);
    final provider = SucursalInherited.of(context);
    if (provider != _sucursalProvider) {
      _sucursalProvider?.removeListener(_onSucursalChanged);
      _sucursalProvider = provider;
      _sucursalProvider?.addListener(_onSucursalChanged);
      setState(() {
        _selectedSucursalId = _sucursalProvider?.selectedSucursalId;
      });
      _fetchCurrentTab();
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _fetchCurrentTab();
    }
  }

  void _onSucursalChanged() {
    setState(() {
      _selectedSucursalId = _sucursalProvider?.selectedSucursalId;
    });
    _fetchCurrentTab();
  }

  void _fetchCurrentTab() {
    if (_tabController.index == 0) {
      _fetchDailyReport();
    } else {
      _fetchMonthlyReport();
    }
  }

  Future<void> _fetchDailyReport() async {
    setState(() {
      _loadingDaily = true;
      _dailyError = null;
    });
    try {
      final report = await _reportRepo.getDailyReport(
        start: _dailyDate,
        end: _dailyDate,
        sucursalId: _selectedSucursalId,
      );
      
      setState(() {
        _dailyReport = report;
        _recentTransactions = []; // Por ahora vacío, se puede implementar después
      });
    } catch (e) {
      setState(() {
        _dailyError = e.toString();
      });
    } finally {
      setState(() {
        _loadingDaily = false;
      });
    }
  }

  Future<void> _fetchMonthlyReport() async {
    setState(() {
      _loadingMonthly = true;
      _monthlyError = null;
    });
    try {
      final report = await _reportRepo.getDailyReport(
        start: _monthStart,
        end: _monthEnd,
        sucursalId: _selectedSucursalId,
      );
      
      final debtReport = await _reportRepo.getDebtReport(sucursalId: _selectedSucursalId);

      setState(() {
        _monthlyReport = report;
        _debtList = debtReport.take(5).toList();
      });
    } catch (e) {
      setState(() {
        _monthlyError = e.toString();
      });
    } finally {
      setState(() {
        _loadingMonthly = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_dailyDate!),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _dailyDate = DateFormat('yyyy-MM-dd').format(picked);
      });
      _fetchDailyReport();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sucursalProvider?.removeListener(_onSucursalChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Ventas'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _tabController.index == 0 ? _selectDate : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(28),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(28),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: colorScheme.onPrimary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
              tabs: const [
                Tab(text: 'Diario'),
                Tab(text: 'Mensual'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDailyTab(theme, colorScheme),
                _buildMonthlyTab(theme, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTab(ThemeData theme, ColorScheme colorScheme) {
    if (_loadingDaily) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_dailyError != null) {
      return Center(child: Text('Error: $_dailyError'));
    }

    final byDayList = List<Map<String, dynamic>>.from((_dailyReport?['byDay'] as List?) ?? []);
    final totalPayments = _dailyReport?['totalPayments'] ?? 0.0;
    final pendingDebt = _dailyReport?['pendingDebt'] ?? 0.0;

    return RefreshIndicator(
      onRefresh: _fetchDailyReport,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Resumen General',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Hoy, ${DateFormat('d MMM', 'es').format(DateTime.parse(_dailyDate!))}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Total Ventas (Ticket)',
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${_formatNumber(totalPayments)}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme,
                    colorScheme,
                    'Total Cobrado',
                    '\$${_formatNumber(totalPayments - pendingDebt)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    theme,
                    colorScheme,
                    'Deuda Pendiente',
                    '\$${_formatNumber(pendingDebt)}',
                    Icons.warning_amber_rounded,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Tendencia de Ingresos',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            byDayList.isEmpty
                ? Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: Text('No hay datos', style: theme.textTheme.bodyMedium),
                  )
                : ReportChart(data: byDayList, isBar: false),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transacciones Recientes',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _recentTransactions.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    child: Text('No hay transacciones', style: theme.textTheme.bodyMedium),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentTransactions.length,
                    itemBuilder: (context, index) {
                      final pago = _recentTransactions[index];
                      return _buildTransactionCard(theme, colorScheme, pago);
                    },
                  ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTab(ThemeData theme, ColorScheme colorScheme) {
    if (_loadingMonthly) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_monthlyError != null) {
      return Center(child: Text('Error: $_monthlyError'));
    }

    final byDayList = List<Map<String, dynamic>>.from((_monthlyReport?['byDay'] as List?) ?? []);
    final totalPayments = _monthlyReport?['totalPayments'] ?? 0.0;
    final pendingDebt = _monthlyReport?['pendingDebt'] ?? 0.0;
    final totalCobrado = totalPayments - pendingDebt;

    final monthDate = DateTime.parse(_monthStart!);
    final monthName = DateFormat('MMMM yyyy', 'es').format(monthDate).toUpperCase();

    return RefreshIndicator(
      onRefresh: _fetchMonthlyReport,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Acumulado del Mes',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    monthName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long, size: 24, color: colorScheme.onPrimary),
                      const SizedBox(width: 8),
                      Text(
                        'TOTAL VENTAS',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\$${_formatNumber(totalPayments)}',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCardMonthly(
                    theme,
                    colorScheme,
                    'COBRADO',
                    '\$${_formatNumber(totalCobrado)}',
                    Icons.monetization_on,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCardMonthly(
                    theme,
                    colorScheme,
                    'DEUDA',
                    '\$${_formatNumber(pendingDebt)}',
                    Icons.warning_amber_rounded,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Comparativo por Semanas',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            byDayList.isEmpty
                ? Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: Text('No hay datos', style: theme.textTheme.bodyMedium),
                  )
                : ReportChart(data: _groupByWeeks(byDayList), isBar: true),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mayor Deuda Acumulada',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Icon(Icons.arrow_forward, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 12),
            _debtList.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    child: Text('No hay deudas', style: theme.textTheme.bodyMedium),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _debtList.length,
                    itemBuilder: (context, index) {
                      final debtItem = _debtList[index];
                      return _buildDebtCard(theme, colorScheme, debtItem);
                    },
                  ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _groupByWeeks(List<Map<String, dynamic>> data) {
    final Map<int, Map<String, dynamic>> weeks = {};
    
    for (final item in data) {
      final date = DateTime.parse(item['date']);
      final weekNumber = ((date.day - 1) ~/ 7) + 1;
      
      if (!weeks.containsKey(weekNumber)) {
        weeks[weekNumber] = {
          'date': 'SEM $weekNumber',
          'payments': 0.0,
          'pendingDebt': 0.0,
        };
      }
      
      weeks[weekNumber]!['payments'] = (weeks[weekNumber]!['payments'] as double) + 
        ((item['payments'] is String) ? double.tryParse(item['payments']) ?? 0.0 : (item['payments'] ?? 0.0));
      weeks[weekNumber]!['pendingDebt'] = (weeks[weekNumber]!['pendingDebt'] as double) + 
        ((item['pendingDebt'] is String) ? double.tryParse(item['pendingDebt']) ?? 0.0 : (item['pendingDebt'] ?? 0.0));
    }
    
    return weeks.values.toList();
  }

  Widget _buildStatCard(ThemeData theme, ColorScheme colorScheme, String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: iconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardMonthly(ThemeData theme, ColorScheme colorScheme, String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: iconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(ThemeData theme, ColorScheme colorScheme, Map<String, dynamic> pago) {
    final ticket = pago['ticket'];
    final cliente = ticket?['cliente'];
    final clientName = cliente != null ? '${cliente['nombreCliente'] ?? ''} ${cliente['apellidoCliente'] ?? ''}' : 'Cliente Invitado';
    
    final montoPagado = (pago['montoPagado'] is String) 
        ? double.tryParse(pago['montoPagado']) ?? 0.0 
        : (pago['montoPagado'] ?? 0.0);
    
    final saldoPendiente = ticket != null 
        ? ((ticket['saldoPendiente'] is String) 
            ? double.tryParse(ticket['saldoPendiente']) ?? 0.0 
            : (ticket['saldoPendiente'] ?? 0.0))
        : 0.0;
    
    final cuota = ticket != null 
        ? ((ticket['cuota'] is String) 
            ? double.tryParse(ticket['cuota']) ?? 0.0 
            : (ticket['cuota'] ?? 0.0))
        : montoPagado;
    
    final createdAt = pago['createdAt'] ?? pago['fechaPago'];
    final time = createdAt != null ? DateFormat('h:mm a').format(DateTime.parse(createdAt)) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(Icons.person, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Servicio • $time',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Pagado: \$${montoPagado.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (saldoPendiente > 0) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Pendiente: \$${saldoPendiente.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${cuota.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Ticket Total',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(ThemeData theme, ColorScheme colorScheme, Map<String, dynamic> debtItem) {
    final client = debtItem['client'];
    final clientName = client != null ? '${client['nombreCliente'] ?? ''} ${client['apellidoCliente'] ?? ''}' : 'Cliente';
    final deudaTotal = debtItem['deudaTotal'] ?? 0.0;
    final tickets = debtItem['tickets'] as List? ?? [];
    final serviciosCount = tickets.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.3),
            child: Icon(Icons.person, color: colorScheme.error, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$serviciosCount servicio${serviciosCount != 1 ? 's' : ''} • Estética Facial',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Debe: \$${deudaTotal.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${deudaTotal.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'TOTAL MES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
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
