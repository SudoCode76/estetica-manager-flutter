import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Asegúrate de tener este import para formatear moneda/fechas
import 'package:app_estetica/repositories/cliente_repository.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/screens/admin/payments/payment_detail_screen.dart';
import 'package:provider/provider.dart';

class PaymentsHistoryScreen extends StatefulWidget {
  const PaymentsHistoryScreen({super.key});

  @override
  State<PaymentsHistoryScreen> createState() => _PaymentsHistoryScreenState();
}

class _PaymentsHistoryScreenState extends State<PaymentsHistoryScreen> {
  late ClienteRepository _clienteRepo;

  bool _loading = true;
  String? _error;
  List<dynamic> _clients = [];
  List<dynamic> _filteredClients = [];
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
        final nombre =
            '${c['nombrecliente'] ?? ''} ${c['apellidocliente'] ?? ''}'
                .toString()
                .toLowerCase();
        return nombre.contains(q);
      }).toList();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sucursalProvider == null) {
      _sucursalProvider = SucursalInherited.of(context);
      _clienteRepo = Provider.of<ClienteRepository>(context, listen: false);
      _loadClientsHistory();
    }
  }

  Future<void> _loadClientsHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sucursalId = _sucursalProvider?.selectedSucursalId;

      // Llamada optimizada a la vista SQL
      final data = await _clienteRepo.obtenerHistorialClientes(
        sucursalId: sucursalId,
      );

      setState(() {
        _clients = data;
        _filteredClients = List<dynamic>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Calcular total global
    final totalHistorico = _clients.fold<double>(
      0.0,
      (sum, c) => sum + ((c['total_pagado'] as num?)?.toDouble() ?? 0.0),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Clientes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 8),
                  Text('Error: $_error'),
                  TextButton(
                    onPressed: _loadClientsHistory,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // HEADER CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL DE CLIENTES',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          '${_clients.length}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'TOTAL HISTÓRICO COBRADO',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          'Bs ${NumberFormat('#,##0.00', 'es_BO').format(totalHistorico)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // SEARCH
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // LISTA
                  Expanded(
                    child: _filteredClients.isEmpty
                        ? Center(
                            child: Text(
                              'No hay registros',
                              style: theme.textTheme.bodyLarge,
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredClients.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final c = _filteredClients[i];
                              final nombre =
                                  '${c['nombrecliente'] ?? ''} ${c['apellidocliente'] ?? ''}'
                                      .trim();
                              final totalPagado =
                                  (c['total_pagado'] as num?)?.toDouble() ??
                                  0.0;
                              final tieneDeuda =
                                  (((c['tickets_con_deuda'] as int?) ?? 0) > 0);
                              final ultimaVisitaRaw = c['ultima_visita'];

                              String fechaVisita = '-';
                              if (ultimaVisitaRaw != null) {
                                fechaVisita = DateFormat(
                                  'd MMM yyyy',
                                  'es',
                                ).format(DateTime.parse(ultimaVisitaRaw));
                              }

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    // Navegar al detalle pasando los datos normalizados para PaymentDetailScreen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PaymentDetailScreen(
                                          cliente: {
                                            'id': c['id'],
                                            'nombreCliente': c['nombrecliente'],
                                            'apellidoCliente':
                                                c['apellidocliente'],
                                            // Agrega teléfono si lo necesitas y está en la vista
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                nombre,
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Última visita: $fechaVisita',
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                              const SizedBox(height: 8),
                                              if (tieneDeuda)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: cs.tertiaryContainer
                                                        .withValues(alpha: 0.4),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'Tiene deuda',
                                                    style: TextStyle(
                                                      color: cs.tertiary,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                )
                                              else
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: cs.primaryContainer
                                                        .withValues(alpha: 0.5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'Al día',
                                                    style: TextStyle(
                                                      color: cs.primary,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          'Bs ${NumberFormat('#,##0.00', 'es_BO').format(totalPagado)}',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(width: 8),
                                         Icon(
                                          Icons.chevron_right,
                                          color: cs.onSurfaceVariant,
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
