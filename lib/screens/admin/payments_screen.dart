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
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Text('Pagos', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _loadClientsWithDebt,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refrescar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                ),
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
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final c = _clients[index];
                            final nombre = '${c['nombreCliente'] ?? ''} ${c['apellidoCliente'] ?? ''}'.trim();
                            final deuda = (c['deudaTotal'] as double).toStringAsFixed(2);
                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => pd.PaymentDetailScreen(cliente: c)));
                                  if (res == true) await _loadClientsWithDebt();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: theme.colorScheme.primary.withAlpha(30),
                                        child: Icon(Icons.person, color: theme.colorScheme.primary, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(nombre, style: theme.textTheme.titleMedium),
                                            const SizedBox(height: 6),
                                            Text('Deuda: Bs $deuda', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160))),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: IconButton(
                                          onPressed: () async {
                                            final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => pd.PaymentDetailScreen(cliente: c)));
                                            if (res == true) await _loadClientsWithDebt();
                                          },
                                          icon: const Icon(Icons.chevron_right, color: Colors.white),
                                          splashRadius: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
