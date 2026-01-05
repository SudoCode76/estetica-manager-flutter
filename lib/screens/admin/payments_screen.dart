import 'package:flutter/material.dart';
import 'package:app_estetica/services/api_service.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/screens/admin/payment_detail_screen.dart' as pd;

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _clients = [];
  bool _loading = true;
  SucursalProvider? _sucursalProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sucursalProvider == null) {
      _sucursalProvider = SucursalInherited.of(context);
      _loadClientsWithDebt();
    }
  }

  Future<void> _loadClientsWithDebt() async {
    setState(() => _loading = true);
    try {
      final sucursalId = _sucursalProvider?.selectedSucursalId;
      final clients = await _api.getClientes(sucursalId: sucursalId);
      // Cada cliente puede tener tickets; filtramos por saldoPendiente > 0
      // Para eficiencia, podríamos llamar a /tickets con filtro por sucursal y agrupar, pero aquí simplificamos
      final tickets = await _api.getTickets(sucursalId: sucursalId);

      // Map clientId -> total debt
      final Map<int, double> debtMap = {};
      for (final t in tickets) {
        final cid = t['cliente'] is Map ? t['cliente']['id'] : t['cliente'];
        final saldo = double.tryParse(t['saldoPendiente']?.toString() ?? '0') ?? 0;
        if (cid != null && saldo > 0) {
          debtMap[cid] = (debtMap[cid] ?? 0) + saldo;
        }
      }

      // Build list of clients with debt
      final List<dynamic> withDebt = [];
      for (final c in clients) {
        final id = c['id'];
        final owed = debtMap[id] ?? 0;
        if (owed > 0) {
          final copy = Map<String, dynamic>.from(c);
          copy['deudaTotal'] = owed;
          withDebt.add(copy);
        }
      }

      // Order descending by deudaTotal
      withDebt.sort((a, b) => (b['deudaTotal'] as double).compareTo(a['deudaTotal'] as double));

      setState(() {
        _clients = withDebt;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando clientes con deuda: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
     return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Text('Pagos', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                FilledButton.icon(onPressed: _loadClientsWithDebt, icon: const Icon(Icons.refresh), label: const Text('Refrescar')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _clients.isEmpty
                      ? Center(child: Text('No hay clientes con deuda', style: Theme.of(context).textTheme.bodyLarge))
                      : ListView.separated(
                          itemCount: _clients.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final c = _clients[index];
                            return ListTile(
                              title: Text('${c['nombreCliente'] ?? ''} ${c['apellidoCliente'] ?? ''}'.trim()),
                              subtitle: Text('Deuda: Bs ${ (c['deudaTotal'] as double).toStringAsFixed(2) }'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => pd.PaymentDetailScreen(cliente: c)));
                                if (res == true) {
                                  await _loadClientsWithDebt();
                                }
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
