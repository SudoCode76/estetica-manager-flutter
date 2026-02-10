import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_estetica/repositories/ticket_repository.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/screens/admin/payment_detail_screen.dart' as pd;
import 'package:app_estetica/screens/admin/payments_history_screen.dart';



class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late TicketRepository _api;
  List<dynamic> _clients = [];
  List<dynamic> _filteredClients = [];
  bool _loading = true;
  String? _error;
  SucursalProvider? _sucursalProvider;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sucursalProvider == null) {
      _sucursalProvider = SucursalInherited.of(context);
      _api = Provider.of<TicketRepository>(context, listen: false);
      _loadClientsWithDebt();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    // Debounce to avoid excessive rebuilds
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final query = q.trim().toLowerCase();
      if (query.isEmpty) {
        setState(() {
          _filteredClients = List<dynamic>.from(_clients);
        });
        return;
      }

      final filtered = _clients.where((c) {
        final nombre = ((c['nombreCliente'] ?? '') as String).toLowerCase();
        final apellido = ((c['apellidoCliente'] ?? '') as String).toLowerCase();
        final full = ('$nombre $apellido').trim();
        return nombre.contains(query) || apellido.contains(query) || full.contains(query);
      }).toList();

      setState(() {
        _filteredClients = filtered;
      });
    });
  }

  Future<void> _loadClientsWithDebt() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sucursalId = _sucursalProvider?.selectedSucursalId;

      // Usar la nueva arquitectura: obtener tickets pendientes/parciales directamente con timeout
      final ticketsPendientes = await _api.obtenerTicketsPendientes(sucursalId: sucursalId).timeout(const Duration(seconds: 8));

      // Map clientId -> total debt
      final Map<int, double> debtMap = {};
      final Map<int, Map<String, dynamic>> clientMap = {};

      for (final t in ticketsPendientes) {
        // Extraer info del cliente (viene incluida en la consulta)
        final cliente = t['cliente'];
        if (cliente != null && cliente is Map) {
          final clienteId = cliente['id'];
          final saldo = (t['saldo_pendiente'] is num)
              ? (t['saldo_pendiente'] as num).toDouble()
              : 0.0;

          if (clienteId != null && saldo > 0) {
            debtMap[clienteId] = (debtMap[clienteId] ?? 0) + saldo;
            clientMap[clienteId] = {
              'id': clienteId,
              'nombreCliente': cliente['nombrecliente'] ?? '',
              'apellidoCliente': cliente['apellidocliente'] ?? '',
              'telefono': cliente['telefono'],
            };
          }
        }
      }

      // Build list of clients with debt
      final List<dynamic> withDebt = [];
      for (final entry in clientMap.entries) {
        final clientData = entry.value;
        clientData['deudaTotal'] = debtMap[entry.key] ?? 0;
        withDebt.add(clientData);
      }

      // Order descending by deudaTotal
      withDebt.sort((a, b) => (b['deudaTotal'] as double).compareTo(a['deudaTotal'] as double));

      setState(() {
        _clients = withDebt;
        _filteredClients = List<dynamic>.from(withDebt);
        _loading = false;
      });
    } catch (e) {
      final msg = e is TimeoutException ? 'Timeout al cargar clientes con deuda (verifica conexión)' : e.toString();
      setState(() {
        _loading = false;
        _error = msg;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando clientes con deuda: $msg')));
    }
  }

  double _computeTotalDebt() {
    double total = 0;
    for (final c in _clients) {
      total += (c['deudaTotal'] as double?) ?? 0.0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = _computeTotalDebt();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: _loadClientsWithDebt,
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentsHistoryScreen()));
                    await _loadClientsWithDebt();
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Historial'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    backgroundColor: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top card with total
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colorScheme.primaryContainer, colorScheme.surfaceContainerHighest.withAlpha((0.9*255).round())]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL POR COBRAR', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text('Bs ${total.toStringAsFixed(2)}', style: theme.textTheme.displaySmall?.copyWith(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.account_balance_wallet, color: colorScheme.primary, size: 26),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Search bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withAlpha((0.6*255).round()),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: colorScheme.primary.withAlpha((0.8*255).round())),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Buscar cliente...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_error != null)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.error_outline, size: 56, color: Theme.of(context).colorScheme.error),
                              const SizedBox(height: 12),
                              Text('Error al cargar clientes con deuda', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
                              const SizedBox(height: 8),
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton.icon(onPressed: _loadClientsWithDebt, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
                            ]),
                          ),
                        )
                      : _filteredClients.isEmpty
                          ? Center(child: Text('No hay clientes con deuda', style: theme.textTheme.bodyLarge))
                          : ListView.separated(
                              itemCount: _filteredClients.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final c = _filteredClients[index];
                                final nombre = '${c['nombreCliente'] ?? ''} ${c['apellidoCliente'] ?? ''}'.trim();
                                final deuda = (c['deudaTotal'] as double).toStringAsFixed(2);

                                // Pill style row
                                return InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => pd.PaymentDetailScreen(cliente: c)));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [BoxShadow(color: colorScheme.shadow.withAlpha((0.04*255).round()), blurRadius: 6, offset: const Offset(0, 2))],
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(nombre, style: theme.textTheme.titleMedium)),
                                        const SizedBox(width: 12),
                                        Text('Bs $deuda', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                                      ],
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
