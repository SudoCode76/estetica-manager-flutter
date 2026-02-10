import 'package:flutter/material.dart';
import 'package:app_estetica/config/responsive.dart';
import 'package:provider/provider.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/providers/reports_provider.dart';
import 'reports/financial_report.dart';
import 'reports/clients_report.dart';
import 'reports/services_report.dart';
import 'reports/report_period.dart';
import 'package:flutter/foundation.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.month; // Por defecto Mes
  int _currentTab = 0; // 0=Financiero,1=Clientes,2=Servicios
  bool _pointerEnabled = false; // Bloquea pointers hasta que la pantalla haya renderizado

  // Variable para evitar recargas infinitas si el ID no cambia
  int? _loadedSucursalId;

  @override
  void initState() {
    super.initState();
    // Habilitar punteros después de un par de frames para evitar hit-tests prematuros
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _pointerEnabled = true);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Escuchar cambios en la sucursal (ej: carga inicial o cambio en el menú)
    SucursalProvider? sucursalProvider;
    try {
      sucursalProvider = Provider.of<SucursalProvider>(context, listen: false);
    } catch (_) {
      // Si Provider no está disponible (ej: hot-reload sin restart), usamos el InheritedWidget como fallback
      sucursalProvider = SucursalInherited.of(context);
    }
    final currentId = sucursalProvider?.selectedSucursalId;

    // Solo cargar si tenemos ID y es diferente al último cargado (o si nunca cargamos)
    if (currentId != null && currentId != _loadedSucursalId) {
      _loadedSucursalId = currentId;
      // Usamos addPostFrameCallback para evitar errores de build durante la actualización
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData(currentId);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _setPeriod(ReportPeriod p) {
    setState(() => _period = p);
    if (_loadedSucursalId != null) {
      _loadData(_loadedSucursalId!);
    }
  }

  void _loadData(int sucursalId) {
    debugPrint('ReportsScreen: Cargando datos para sucursal $sucursalId, periodo: $_period');
    // Llamada segura al provider: si no está disponible por alguna razón usamos el InheritedWidget
    try {
      Provider.of<ReportsProvider>(context, listen: false).loadReports(sucursalId, _period);
    } catch (_) {
      final repoProvider = Provider.of<ReportsProvider?>(context, listen: false);
      if (repoProvider != null) {
        repoProvider.loadReports(sucursalId, _period);
      } else {
        // último recurso: nada que hacer, mostramos log
        debugPrint('ReportsScreen._loadData: ReportsProvider no disponible');
      }
    }
  }

  // Botón para reintentar manual en caso de fallo
  void _retryLoad() {
    SucursalProvider? sucursalProvider;
    try {
      sucursalProvider = Provider.of<SucursalProvider>(context, listen: false);
    } catch (_) {
      sucursalProvider = SucursalInherited.of(context);
    }

    final sucursalId = sucursalProvider?.selectedSucursalId;
    if (sucursalId != null) {
      _loadData(sucursalId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay sucursal seleccionada')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = Responsive.isSmallScreen(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA), // Fondo gris muy suave (tipo dashboard)
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
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            // Verificar si hay datos (chequeamos si al menos el mapa existe,
            // las funciones RPC siempre devuelven la estructura JSON aunque tenga 0s)
            // Si financialData tiene keys, significa que la consulta fue exitosa (aunque sean 0s).
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
                    const SizedBox(height: 8),
                    const Text(
                      'Verifica tu conexión o selecciona\nuna sucursal diferente',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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

            // En web, no renderizamos el contenido hasta que el primer frame complete el layout
            if (kIsWeb && !_pointerEnabled) {
              return const Center(child: CircularProgressIndicator());
            }

            // En web, usamos una vista simplificada y no interactiva para evitar problemas de hit-test
            if (kIsWeb) {
              return _buildSimpleWebReports(provider.financialData, provider.clientsData, provider.servicesData);
            }

            // Mostrar solo la pestaña activa usando IndexedStack para evitar PageView/Sliver hit-test issues
            final tabs = [
              FinancialReport(period: _period, data: provider.financialData),
              ClientsReport(period: _period, data: provider.clientsData),
              ServicesReport(period: _period, data: provider.servicesData),
            ];

            Widget content = IndexedStack(index: _currentTab, children: tabs);

            // En web/desktop: bloquear eventos de puntero hasta que la pantalla termine su primer frame
            if (kIsWeb) {
              content = IgnorePointer(ignoring: !_pointerEnabled, child: content);
            }

            return content;
          },
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final selected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Bloqueamos punteros mientras el nuevo contenido se construye
          if (mounted) setState(() => _pointerEnabled = false);
          // Cambiamos la pestaña
          setState(() {
            _currentTab = index;
          });
          // Habilitamos punteros en dos frames para dar tiempo a que los hijos completen layout
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _pointerEnabled = true);
            });
          });
        },
        child: Container(
          height: 37,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF7B61FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey.shade700, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _buildSimpleWebReports(Map<String, dynamic> fin, Map<String, dynamic> clients, Map<String, dynamic> services) {
    final ingresos = (fin['ingresos'] as num?)?.toDouble() ?? 0.0;
    final atendidos = (clients['atendidos'] as num?)?.toInt() ?? 0;
    final completados = (services['completados'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(context), vertical: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Resumen Financiero', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Ingresos: Bs ${ingresos.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Clientes', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Atendidos: $atendidos', style: const TextStyle(fontSize: 18)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Servicios', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Completados: $completados', style: const TextStyle(fontSize: 18)),
            ]),
          ),
        ),
      ]),
    );
  }
}
