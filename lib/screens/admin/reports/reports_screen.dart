import 'package:flutter/material.dart';
import 'package:app_estetica/config/responsive.dart';
import 'package:provider/provider.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/providers/reports_provider.dart';
import 'package:app_estetica/widgets/date_nav_bar.dart';
import 'financial_report.dart';
import 'clients_report.dart';
// services_report.dart removed — feature deleted
import 'report_period.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  /// Período clásico seleccionado. `null` cuando se usa DateNavBar.
  ReportPeriod? _period = ReportPeriod.month;

  late TabController _tabController;
  int _currentTab = 0;

  // Variable para evitar recargas innecesarias
  int? _loadedSucursalId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      setState(() => _currentTab = _tabController.index);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sucursalProvider = Provider.of<SucursalProvider>(context);
    final currentId = sucursalProvider.selectedSucursalId;

    if (currentId != null && currentId != _loadedSucursalId) {
      _loadedSucursalId = currentId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData(currentId);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Carga de datos ────────────────────────────────────────────────────────

  void _loadData(int sucursalId) {
    final provider = Provider.of<ReportsProvider>(context, listen: false);
    if (_period != null) {
      provider.loadReports(sucursalId, _period!);
    }
  }

  // Nota: _setPeriod se removió porque el selector clásico fue eliminado.

  /// Llamado por DateNavBar cuando el usuario elige un día.
  void _onDateChanged(DateTime date) {
    setState(() => _period = null); // deseleccionar chip
    final sucursalId = _loadedSucursalId;
    if (sucursalId == null) return;
    Provider.of<ReportsProvider>(
      context,
      listen: false,
    ).fetchReportForDate(sucursalId, date);
  }

  /// Llamado por DateNavBar cuando el usuario elige un rango.
  void _onRangeChanged(DateTimeRange range) {
    setState(() => _period = null);
    final sucursalId = _loadedSucursalId;
    if (sucursalId == null) return;
    Provider.of<ReportsProvider>(
      context,
      listen: false,
    ).fetchReportForRange(sucursalId, range);
  }

  /// Llamado por DateNavBar cuando el usuario elige un mes.
  void _onMonthChanged(int year, int month) {
    setState(() => _period = null);
    final sucursalId = _loadedSucursalId;
    if (sucursalId == null) return;
    Provider.of<ReportsProvider>(
      context,
      listen: false,
    ).fetchReportForMonth(sucursalId, year, month);
  }

  /// Llamado por DateNavBar cuando el usuario elige un año.
  void _onYearChanged(int year) {
    setState(() => _period = null);
    final sucursalId = _loadedSucursalId;
    if (sucursalId == null) return;
    Provider.of<ReportsProvider>(
      context,
      listen: false,
    ).fetchReportForYear(sucursalId, year);
  }

  void _retryLoad() {
    final sucursalId = Provider.of<SucursalProvider>(
      context,
      listen: false,
    ).selectedSucursalId;
    if (sucursalId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay sucursal seleccionada')),
        );
      }
      return;
    }
    final provider = Provider.of<ReportsProvider>(context, listen: false);
    switch (provider.dateMode) {
      case ReportDateMode.period:
        if (_period != null) _loadData(sucursalId);
      case ReportDateMode.singleDay:
        provider.fetchReportForDate(sucursalId, provider.selectedDate);
      case ReportDateMode.dateRange:
        if (provider.selectedRange != null) {
          provider.fetchReportForRange(sucursalId, provider.selectedRange!);
        }
      case ReportDateMode.monthPick:
        if (provider.selectedMonth != null) {
          provider.fetchReportForMonth(
            sucursalId,
            provider.selectedMonth!.year,
            provider.selectedMonth!.month,
          );
        }
      case ReportDateMode.yearPick:
        if (provider.selectedYear != null) {
          provider.fetchReportForYear(sucursalId, provider.selectedYear!);
        }
    }
  }

  // ── Builders de UI ────────────────────────────────────────────────────────

  // Nota: el selector clásico de períodos (chips) fue removido en favor de DateNavBar.

  Widget _buildTabButton(int index, String label) {
    final selected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _currentTab = index);
          _tabController.animateTo(index);
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(82),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // (Se removió el selector clásico de Períodos — se usa DateNavBar)

                // DateNavBar — navegación histórica
                Consumer<ReportsProvider>(
                  builder: (context, provider, _) {
                    return DateNavBar(
                      provider: provider,
                      onDateChanged: _onDateChanged,
                      onRangeChanged: _onRangeChanged,
                      onMonthChanged: _onMonthChanged,
                      onYearChanged: _onYearChanged,
                    );
                  },
                ),

                const SizedBox(height: 8),

                // Tabs secundarias: Financiero | Clientes
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withAlpha(
                      (0.6 * 255).toInt(),
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTabButton(0, 'Financiero'),
                      _buildTabButton(1, 'Clientes'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.horizontalPadding(context),
        ),
        child: Consumer<ReportsProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final hasData = provider.financialData.isNotEmpty;

            if (!hasData) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 80,
                      color: cs.onSurface.withAlpha((0.2 * 255).toInt()),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No hay datos disponibles\npara el periodo seleccionado',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    FilledButton.icon(
                      onPressed: _retryLoad,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                FinancialReport(
                  period: _period,
                  dateMode: provider.dateMode,
                  chartGranularity: provider.chartGranularity,
                  data: provider.financialData,
                ),
                ClientsReport(
                  period: _period ?? ReportPeriod.month,
                  data: provider.clientsData,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
