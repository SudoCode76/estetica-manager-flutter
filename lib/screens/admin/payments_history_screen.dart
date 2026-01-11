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
  List<dynamic> _clients = []; // all clients with history
  List<dynamic> _filteredClients = []; // clients after search
  SucursalProvider? _sucursalProvider;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredClients = List<dynamic>.from(_clients));
      return;
    }
    setState(() {
      _filteredClients = _clients.where((c) {
        final nombre = '${c['nombreCliente'] ?? ''} ${c['apellidoCliente'] ?? ''}'.toString().toLowerCase();
        final doc = (c['documentId'] ?? '').toString().toLowerCase();
        return nombre.contains(q) || doc.contains(q);
      }).toList();
    });
  }

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
      final tickets = await _api.getTickets(sucursalId: sucursalId);
      final clients = await _api.getClientes(sucursalId: sucursalId);

      // Map clientId -> totalPaid and flags/counters
      final Map<int, double> paidMap = {};
      final Map<int, int> historicoCount = {}; // tickets that had cuota > 0
      final Map<int, int> currentDebtCount = {}; // tickets with saldo > 0

      for (final t in tickets) {
        final cid = t['cliente'] is Map ? t['cliente']['id'] : t['cliente'];
        if (cid == null) continue;
        final totalTicket = double.tryParse(t['cuota']?.toString() ?? '0') ?? 0;
        final saldo = double.tryParse(t['saldoPendiente']?.toString() ?? '0') ?? 0;
        final paid = (totalTicket - saldo) > 0 ? (totalTicket - saldo) : 0;
        paidMap[cid] = (paidMap[cid] ?? 0) + paid;
        if (totalTicket > 0) historicoCount[cid] = (historicoCount[cid] ?? 0) + 1;
        if (saldo > 0) currentDebtCount[cid] = (currentDebtCount[cid] ?? 0) + 1;
      }

      final List<dynamic> result = [];
      for (final c in clients) {
        final id = c['id'];
        if ((historicoCount[id] ?? 0) > 0) {
          final copy = Map<String, dynamic>.from(c);
          copy['totalPagado'] = paidMap[id] ?? 0;
          copy['ticketsHistoricosCount'] = historicoCount[id] ?? 0;
          copy['ticketsConDeudaActualCount'] = currentDebtCount[id] ?? 0;
          result.add(copy);
        }
      }

      // Order desc by totalPagado
      result.sort((a, b) => (b['totalPagado'] as double).compareTo(a['totalPagado'] as double));

      setState(() {
        _clients = result;
        _filteredClients = List<dynamic>.from(result);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando historial: $e')));
    }
  }

  Future<void> _showClientPaymentsModal(Map<String, dynamic> client) async {
    setState(() => _loading = true);
    try {
      final sucursalId = _sucursalProvider?.selectedSucursalId;
      final allTickets = await _api.getTickets(sucursalId: sucursalId);
      final clientId = client['id'];
      final clientTickets = allTickets.where((t) {
        final tclient = t['cliente'] is Map ? t['cliente']['id'] : t['cliente'];
        return tclient == clientId;
      }).toList();

      final allPagos = await _api.getPagos(sucursalId: sucursalId);
      final pagosCliente = allPagos.where((p) {
        final pc = p['cliente'] is Map ? p['cliente']['id'] : p['cliente'];
        if (pc != null && pc == clientId) return true;
        final pt = p['ticket'] is Map ? p['ticket']['id'] : p['ticket'];
        if (pt != null) {
          return clientTickets.any((t) => t['id'] == pt || (t['documentId'] ?? '').toString() == pt.toString());
        }
        return false;
      }).toList();

      setState(() => _loading = false);

      // Mostrar modal con historial (estilizado)
      await showDialog(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 520),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('${client['nombreCliente'] ?? ''} ${client['apellidoCliente'] ?? ''}', style: theme.textTheme.titleLarge)),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withAlpha(160)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Chip(
                        avatar: Icon(Icons.receipt_long, size: 18, color: theme.colorScheme.onPrimary),
                        label: Text('${client['ticketsHistoricosCount'] ?? 0} tickets'),
                        backgroundColor: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        avatar: Icon(Icons.account_balance_wallet, size: 18, color: Colors.white),
                        label: Text('Pagos: ${pagosCliente.length}'),
                        backgroundColor: theme.colorScheme.secondary,
                      ),
                      const Spacer(),
                    ]),
                    const SizedBox(height: 12),
                    Expanded(
                      child: pagosCliente.isEmpty
                          ? Center(child: Text('No hay registros de pago', style: theme.textTheme.bodyLarge))
                          : ListView.separated(
                              itemCount: pagosCliente.length,
                              separatorBuilder: (_, __) => const Divider(height: 8),
                              itemBuilder: (context, i) {
                                final p = pagosCliente[i];
                                final monto = double.tryParse(p['montoPagado']?.toString() ?? '0') ?? 0;
                                final fecha = p['fechaPago'] ?? p['createdAt'] ?? '';
                                final ticket = p['ticket'] is Map ? (p['ticket']['documentId'] ?? p['ticket']['id']) : p['ticket'];
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(backgroundColor: theme.colorScheme.primary.withAlpha(30), child: Icon(Icons.monetization_on, color: theme.colorScheme.primary)),
                                  title: Text('Bs ${monto.toStringAsFixed(2)}', style: theme.textTheme.titleSmall),
                                  subtitle: Text('Fecha: ${fecha.toString()}\nTicket: ${ticket ?? '-'}', style: theme.textTheme.bodySmall),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando pagos del cliente: $e')));
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
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente...',
                      prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface.withAlpha(140)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: theme.colorScheme.onSurface.withAlpha(140)),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // List
                  Expanded(
                    child: _filteredClients.isEmpty
                        ? Center(child: Text('No hay clientes con historial', style: theme.textTheme.bodyLarge))
                        : LayoutBuilder(builder: (context, constraints) {
                            final screenW = constraints.maxWidth;
                            final isNarrow = screenW < 420;
                            return ListView.separated(
                              itemCount: _filteredClients.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final c = _filteredClients[i];
                                final nombre = '${c['nombreCliente'] ?? ''} ${c['apellidoCliente'] ?? ''}'.trim();
                                final totalPagado = (c['totalPagado'] as double).toStringAsFixed(2);
                                final historicoCount = c['ticketsHistoricosCount'] ?? 0;
                                final currentCount = c['ticketsConDeudaActualCount'] ?? 0;
                                final avatarRadius = isNarrow ? 18.0 : 20.0;
                                final titleStyle = isNarrow ? theme.textTheme.titleSmall : theme.textTheme.titleMedium;
                                final subtitleStyle = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160));

                                return Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10.0 : 12.0, vertical: isNarrow ? 8.0 : 10.0),
                                    child: Row(children: [
                                      CircleAvatar(radius: avatarRadius, backgroundColor: theme.colorScheme.primary.withAlpha(30), child: Icon(Icons.person, color: theme.colorScheme.primary, size: avatarRadius)),
                                      const SizedBox(width: 12),

                                      // Main info
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(nombre, style: titleStyle, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text('Total pagado: Bs $totalPagado', style: subtitleStyle),
                                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(8)), child: Text('$historicoCount históricos', style: theme.textTheme.bodySmall)),
                                              if (currentCount > 0)
                                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: theme.colorScheme.error.withAlpha(20), borderRadius: BorderRadius.circular(8)), child: Text('$currentCount con deuda', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error))),
                                            ],
                                          ),
                                        ]),
                                      ),

                                      // Actions
                                      const SizedBox(width: 8),
                                      Column(mainAxisSize: MainAxisSize.min, children: [
                                        IconButton(
                                          onPressed: () => _showClientPaymentsModal(c),
                                          icon: Icon(Icons.receipt_long, color: theme.colorScheme.primary),
                                          tooltip: 'Ver historial rápido',
                                        ),
                                        const SizedBox(height: 4),
                                        IconButton(
                                          onPressed: () async {
                                            await Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentDetailScreen(cliente: c)));
                                            await _loadClientsHistory();
                                          },
                                          icon: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withAlpha(160)),
                                          tooltip: 'Abrir detalle',
                                        ),
                                      ]),
                                    ]),
                                  ),
                                );
                              },
                            );
                          }),
                  ),
                ],
              ),
            ),
    );
  }
}

