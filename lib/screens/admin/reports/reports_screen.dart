import 'package:flutter/material.dart';
import 'package:app_estetica/config/responsive.dart';
import 'package:provider/provider.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/providers/reports_provider.dart';
import 'financial_report.dart';
import 'clients_report.dart';
import 'services_report.dart';
import 'report_period.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  ReportPeriod _period = ReportPeriod.month; // Por defecto Mes
  late TabController _tabController;
  int _currentTab = 0;

  // Variable para evitar recargas innecesarias
  int? _loadedSucursalId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  void _setPeriod(ReportPeriod p) {
    setState(() => _period = p);
    if (_loadedSucursalId != null) {
      _loadData(_loadedSucursalId!);
    }
  }

  void _loadData(int sucursalId) {
    Provider.of<ReportsProvider>(context, listen: false).loadReports(sucursalId, _period);
  }

  Widget _buildPeriodChip(ReportPeriod p, String label) {
    final selected = _period == p;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _setPeriod(p),
        selectedColor: Theme.of(context).colorScheme.primary,
        labelStyle: TextStyle(
          color: selected ? Theme.of(context).colorScheme.onPrimary : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? Colors.transparent : Colors.grey.shade300
          )
        ),
      ),
    );
  }

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
            color: selected ? const Color(0xFF7B61FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _retryLoad() {
    final sucursalId = Provider.of<SucursalProvider>(context, listen: false).selectedSucursalId;
    if (sucursalId != null) {
      _loadData(sucursalId);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay sucursal seleccionada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = Responsive.isSmallScreen(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: AppBar(
        title: Text('Reportes', style: TextStyle(fontSize: isSmallScreen ? 18 : 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F5FA),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Período selector (Scroll horizontal)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPeriodChip(ReportPeriod.today, 'Hoy'),
                      _buildPeriodChip(ReportPeriod.week, 'Semana'),
                      _buildPeriodChip(ReportPeriod.month, 'Mes'),
                      _buildPeriodChip(ReportPeriod.year, 'Año'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tabs secundarias: Financiero | Clientes | Servicios (custom control)
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTabButton(0, 'Financiero'),
                      _buildTabButton(1, 'Clientes'),
                      _buildTabButton(2, 'Servicios'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(context)),
        child: Consumer<ReportsProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) return const Center(child: CircularProgressIndicator());

            final hasData = provider.financialData.isNotEmpty;

            if (!hasData) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 80, color: Colors.grey.shade300),
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
                        backgroundColor: const Color(0xFF7B61FF),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                      ),
                    ),
                  ],
                ),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                FinancialReport(period: _period, data: provider.financialData),
                ClientsReport(period: _period, data: provider.clientsData),
                ServicesReport(period: _period, data: provider.servicesData),
              ],
            );
          },
        ),
      ),
    );
  }
}
