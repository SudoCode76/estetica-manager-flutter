import 'package:flutter/material.dart';
import 'package:app_estetica/services/api_service.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/screens/admin/payment_detail_screen.dart';

class PaymentsHistoryScreen extends StatefulWidget {
  const PaymentsHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PaymentsHistoryScreen> createState() => _PaymentsHistoryScreenState();
}

class _PaymentsHistoryScreenState extends State<PaymentsHistoryScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<dynamic> _clients = [];
  SucursalProvider? _sucursalProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sucursalProvider == null) {
      _sucursalProvider = SucursalInherited.of(context);
      _loadClientsHistory();
    }
  }

  Future<void> _loadClientsHistory() async {
    setState(() => _loading = true);
    try {
      final sucursalId = _sucursalProvider?.selectedSucursalId;
      // Strategy: cargar todos los tickets de la sucursal y agrupar por cliente (incluir los que ya no tienen deuda)
      final tickets = await _api.getTickets(sucursalId: sucursalId);
      final clients = await _api.getClientes(sucursalId: sucursalId);

      // Map clientId -> totalPaid and hasEverDebt
      final Map<int, double> paidMap = {};
      final Map<int, bool> everDebt = {};

      for (final t in tickets) {
        final cid = t['cliente'] is Map ? t['cliente']['id'] : t['cliente'];
        if (cid == null) continue;
        final totalTicket = double.tryParse(t['cuota']?.toString() ?? '0') ?? 0;
        final saldo = double.tryParse(t['saldoPendiente']?.toString() ?? '0') ?? 0;
        final paid = totalTicket - saldo;
        paidMap[cid] = (paidMap[cid] ?? 0) + paid;
        if (totalTicket > 0) everDebt[cid] = true;
      }

      final List<dynamic> result = [];
      for (final c in clients) {
        final id = c['id'];
        if (everDebt[id] == true) {
          final copy = Map<String, dynamic>.from(c);
          copy['totalPagado'] = paidMap[id] ?? 0;
          result.add(copy);
        }
      }

      // Order desc by totalPagado
      result.sort((a, b) => (b['totalPagado'] as double).compareTo(a['totalPagado'] as double));

      setState(() {
        _clients = result;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando historial: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes con historial de deuda')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: _clients.isEmpty
                  ? Center(child: Text('No hay clientes con historial', style: theme.textTheme.bodyLarge))
                  : ListView.separated(
                      itemCount: _clients.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final c = _clients[i];
                        final nombre = '${c['nombreCliente'] ?? ''} ${c['apellidoCliente'] ?? ''}'.trim();
                        final totalPagado = (c['totalPagado'] as double).toStringAsFixed(2);
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentDetailScreen(cliente: c)));
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                              child: Row(children: [
                                CircleAvatar(radius: 20, backgroundColor: theme.colorScheme.primary.withAlpha(30), child: Icon(Icons.person, color: theme.colorScheme.primary, size: 20)),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(nombre, style: theme.textTheme.titleMedium), const SizedBox(height: 6), Text('Total pagado: Bs $totalPagado', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160))) ])),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withAlpha(160)),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

