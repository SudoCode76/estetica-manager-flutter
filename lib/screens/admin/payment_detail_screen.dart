import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_estetica/repositories/ticket_repository.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';


class PaymentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> cliente;
  const PaymentDetailScreen({super.key, required this.cliente});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  List<dynamic> _tickets = [];
  Map<int, bool> _selected = {};
  bool _loading = true;
  double _totalDeuda = 0;
  List<dynamic> _pagos = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _loading = true);
    try {
      final sucursalId = SucursalInherited.of(context)?.selectedSucursalId;
      final repo = Provider.of<TicketRepository>(context, listen: false);
      final allTickets = await repo.getTickets(sucursalId: sucursalId);
      final cid = widget.cliente['id'];

      // Tickets con deuda (solo para mostrar en la columna de tickets)
      final List<dynamic> deudaTickets = allTickets.where((t) {
        final tclient = t['cliente'] is Map ? t['cliente']['id'] : t['cliente'];
        final saldo = double.tryParse(t['saldoPendiente']?.toString() ?? '0') ?? 0;
        return tclient == cid && saldo > 0;
      }).toList();

      // Todos los tickets del cliente (para relacionar pagos históricos aunque el ticket ya no tenga deuda)
      final List<dynamic> allClientTickets = allTickets.where((t) {
        final tclient = t['cliente'] is Map ? t['cliente']['id'] : t['cliente'];
        return tclient == cid;
      }).toList();

      double total = 0;
      for (final t in deudaTickets) {
        total += double.tryParse(t['saldoPendiente']?.toString() ?? '0') ?? 0;
      }

      // Cargar historial de pagos del cliente usando la nueva arquitectura
      // Obtener pagos de cada ticket del cliente
      List<dynamic> pagosCliente = [];
      for (final ticket in allClientTickets) {
        try {
          final ticketId = ticket['id']?.toString();
          if (ticketId != null && ticketId.isNotEmpty) {
            final pagosTicket = await repo.obtenerPagosTicket(ticketId);
            pagosCliente.addAll(pagosTicket);
          }
        } catch (e) {
          debugPrint('Error obteniendo pagos de ticket ${ticket['id']}: ${e.toString()}');
        }
      }

      setState(() {
        _tickets = deudaTickets;
        _totalDeuda = total;
        _loading = false;
        _pagos = pagosCliente;
        _selected = { for (var t in deudaTickets) (t['id'] as int): false };
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando tickets: $e')));
    }
  }

  // Pago para tickets seleccionados o para un único ticket
  Future<void> _makePaymentForSelected({int? singleTicketId}) async {
    // monto por defecto = suma de saldos seleccionados o saldo del ticket
    double defaultAmount = 0;
    List<dynamic> targetTickets;
    if (singleTicketId != null) {
      targetTickets = _tickets.where((t) => t['id'] == singleTicketId).toList();
    } else {
      targetTickets = _tickets.where((t) => _selected[t['id']] == true).toList();
    }
    for (final t in targetTickets) {
      defaultAmount += double.tryParse(t['saldoPendiente']?.toString() ?? '0') ?? 0;
    }

    if (targetTickets.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay tickets seleccionados')));
      return;
    }

    // Mostrar modal centrado personalizado
    final didPay = await _showPaymentDialog(targetTickets, defaultAmount);
    if (didPay == true) {
      await _loadTickets();
      // indicar al screen padre que hubo cambios
      Navigator.pop(context, true);
    }
  }

  // Dialog centered personalizado para registrar pagos
  Future<bool?> _showPaymentDialog(List<dynamic> tickets, double defaultAmount) async {
    final montoCtrl = TextEditingController(text: defaultAmount.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final screenW = MediaQuery.of(context).size.width;
        final isNarrow = screenW < 420;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isNarrow ? screenW - 32 : 640),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Crear pago', style: theme.textTheme.titleLarge)),
                      IconButton(onPressed: () => Navigator.of(context).pop(false), icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withAlpha(160))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Form(
                    key: formKey,
                    child: Column(children: [
                      TextFormField(
                        controller: montoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Monto a pagar',
                          prefixIcon: Icon(Icons.attach_money, color: theme.colorScheme.primary),
                        ),
                        validator: (v) {
                          final val = double.tryParse(v ?? '0') ?? 0;
                          if (val <= 0) return 'Ingresa un monto válido';
                          if (val > defaultAmount) return 'El monto no puede ser mayor al total de los tickets seleccionados';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerLeft, child: Text('Tickets a aplicar', style: theme.textTheme.titleMedium)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: tickets.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final t = tickets[i];
                            final saldo = double.tryParse(t['saldoPendiente']?.toString() ?? '0') ?? 0;
                            return Chip(
                              avatar: Icon(Icons.receipt_long, size: 18, color: theme.colorScheme.onPrimary),
                              label: Text('${t['documentId'] ?? t['id']} | Bs ${saldo.toStringAsFixed(0)}'),
                              backgroundColor: theme.colorScheme.primary.withAlpha(20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: isNarrow ? 140 : 180,
                          child: FilledButton(
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final monto = double.tryParse(montoCtrl.text.trim()) ?? 0;
                              Navigator.of(context).pop(true);
                              await _processPaymentOnTickets(monto, tickets);
                            },
                            child: const Text('Pagar'),
                          ),
                        ),
                      ])
                    ]),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _processPaymentOnTickets(double monto, List<dynamic> ticketsToApply) async {
    setState(() => _loading = true);
    try {
      double remaining = monto;
      // Ordenar tickets por fecha ascendente (si tienen fecha)
      final ticketsSorted = List<dynamic>.from(ticketsToApply)..sort((a, b) {
        final fa = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
        final fb = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
        return fa.compareTo(fb);
      });

      final repo = Provider.of<TicketRepository>(context, listen: false);
      for (final t in ticketsSorted) {
        final tid = t['id']?.toString();
        final saldo = double.tryParse(t['saldoPendiente']?.toString() ?? '0') ?? 0;
        final pago = (saldo <= remaining) ? saldo : remaining;
        if (pago <= 0) break;
        // registrarAbono registra un pago para un ticket dado
        await repo.registrarAbono(ticketId: tid!, montoAbono: pago);
        remaining -= pago;
      }

      // Recargar tickets después de procesar pagos
      await _loadTickets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pago(s) registrado(s) exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error procesando pagos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.cliente['nombreCliente'] ?? ''} ${widget.cliente['apellidoCliente'] ?? ''}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final screenW = constraints.maxWidth;
              final isNarrow = screenW < 420;
              final isWide = screenW > 700;

              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12.0 : 20.0, vertical: isNarrow ? 10.0 : 14.0),
                        child: Row(
                          children: [
                            Expanded(child: Text('Deuda total', style: theme.textTheme.titleMedium)),
                            Text('Bs ${_totalDeuda.toStringAsFixed(2)}', style: theme.textTheme.titleLarge),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Controls responsive
                    if (isNarrow) ...[
                      Row(children: [
                        Checkbox(
                          value: _tickets.isNotEmpty && _selected.values.every((v) => v),
                          onChanged: (v) {
                            setState(() {
                              for (final k in _selected.keys) _selected[k] = v == true;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text('Seleccionar todos'),
                      ]),

                      const SizedBox(height: 8),

                      FilledButton.icon(
                        onPressed: _tickets.where((t) => _selected[t['id']] == true).isEmpty ? null : () => _makePaymentForSelected(),
                        icon: const Icon(Icons.payments),
                        label: const Text('Pagar seleccionados'),
                      ),

                      const SizedBox(height: 8),

                      OutlinedButton.icon(
                        onPressed: () async {
                          setState(() => _loading = true);
                          await _loadTickets();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refrescar'),
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Checkbox(
                              value: _tickets.isNotEmpty && _selected.values.every((v) => v),
                              onChanged: (v) {
                                setState(() {
                                  for (final k in _selected.keys) _selected[k] = v == true;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text('Seleccionar todos'),
                          ]),

                          FilledButton.icon(
                            onPressed: _tickets.where((t) => _selected[t['id']] == true).isEmpty ? null : () => _makePaymentForSelected(),
                            icon: const Icon(Icons.payments),
                            label: const Text('Pagar seleccionados'),
                          ),

                          OutlinedButton.icon(
                            onPressed: () async {
                              setState(() => _loading = true);
                              await _loadTickets();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refrescar'),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Main content
                    Expanded(
                      child: isWide
                          ? Row(
                              children: [
                                Expanded(child: _buildTicketsCard(context)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildPagosCard(context)),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(child: _buildTicketsCard(context)),
                                const SizedBox(height: 12),
                                Expanded(child: _buildPagosCard(context)),
                              ],
                            ),
                    ),
                  ],
                ),
              );
            }),
    );
  }

  Widget _buildTicketsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tickets con deuda', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: _tickets.isEmpty
                  ? Center(child: Text('No hay tickets con deuda', style: Theme.of(context).textTheme.bodyLarge))
                  : ListView.separated(
                      itemCount: _tickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final t = _tickets[index];
                        final saldo = double.tryParse(t['saldoPendiente']?.toString() ?? '0') ?? 0;
                        final tid = t['id'] as int;
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                            child: Row(
                              children: [
                                Checkbox(value: _selected[tid] ?? false, onChanged: (v) => setState(() => _selected[tid] = v == true)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${t['documentId'] ?? t['id']}  •  ${t['fecha'] ?? ''}', style: Theme.of(context).textTheme.titleSmall),
                                    const SizedBox(height: 6),
                                    Text('Saldo pendiente: Bs ${saldo.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyMedium),
                                  ]),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  onPressed: () => _makePaymentForSelected(singleTicketId: tid),
                                  child: const Text('Pagar'),
                                ),
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

  Widget _buildPagosCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Historial de pagos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: _pagos.isEmpty
                ? Center(child: Text('No hay registros de pago', style: Theme.of(context).textTheme.bodyLarge))
                : ListView.separated(
                    itemCount: _pagos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = _pagos[index];
                      final monto = double.tryParse(p['montoPagado']?.toString() ?? '0') ?? 0;
                      final fecha = p['fechaPago'] ?? p['createdAt'] ?? '';
                      final ticket = p['ticket'] is Map ? (p['ticket']['documentId'] ?? p['ticket']['id']) : p['ticket'];
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        child: ListTile(
                          title: Text('Bs ${monto.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleSmall),
                          subtitle: Text('Fecha: ${fecha.toString()}\nTicket: ${ticket ?? '-'}', style: Theme.of(context).textTheme.bodySmall),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
