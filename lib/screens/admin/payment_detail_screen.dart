import 'package:flutter/material.dart';
import 'package:app_estetica/services/api_service.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';

class PaymentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> cliente;
  const PaymentDetailScreen({Key? key, required this.cliente}) : super(key: key);

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  final ApiService _api = ApiService();
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
      final allTickets = await _api.getTickets(sucursalId: sucursalId);
      final cid = widget.cliente['id'];
      final List<dynamic> deudaTickets = allTickets.where((t) {
        final tclient = t['cliente'] is Map ? t['cliente']['id'] : t['cliente'];
        final saldo = double.tryParse(t['saldoPendiente']?.toString() ?? '0') ?? 0;
        return tclient == cid && saldo > 0;
      }).toList();

      double total = 0;
      for (final t in deudaTickets) {
        total += double.tryParse(t['saldoPendiente']?.toString() ?? '0') ?? 0;
      }

      // Cargar historial de pagos del cliente (si el modelo contiene cliente o ticket, lo relacionamos)
      final allPagos = await _api.getPagos();
      final pagosCliente = allPagos.where((p) {
        final pc = p['cliente'] is Map ? p['cliente']['id'] : p['cliente'];
        if (pc != null && pc == cid) return true;
        final pt = p['ticket'] is Map ? p['ticket']['id'] : p['ticket'];
        if (pt != null) {
          // si el pago referencia un ticket, comprobar que ese ticket pertenece al cliente actual
          return deudaTickets.any((t) => t['id'] == pt);
        }
        return false;
      }).toList();

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

    // Mostrar modal bottom sheet custom
    final didPay = await _showPaymentModal(targetTickets, defaultAmount);
    if (didPay == true) {
      await _loadTickets();
      // indicar al screen padre que hubo cambios
      Navigator.pop(context, true);
    }
  }

  // Modal bottom sheet personalizado para registrar pagos
  Future<bool?> _showPaymentModal(List<dynamic> tickets, double defaultAmount) async {
    final montoCtrl = TextEditingController(text: defaultAmount.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();
    final screenW = MediaQuery.of(context).size.width;
    final isNarrow = screenW < 420;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Crear pago', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Form(
                key: formKey,
                child: Column(children: [
                  TextFormField(
                    controller: montoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monto a pagar',
                      prefixIcon: Icon(Icons.attach_money, color: Theme.of(context).colorScheme.primary),
                    ),
                    validator: (v) {
                      final val = double.tryParse(v ?? '0') ?? 0;
                      if (val <= 0) return 'Ingresa un monto válido';
                      if (val > defaultAmount) return 'El monto no puede ser mayor al total de los tickets seleccionados';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Resumen de tickets incluidos (compacto)
                  Align(alignment: Alignment.centerLeft, child: Text('Tickets a aplicar', style: Theme.of(context).textTheme.titleMedium)),
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
                          avatar: const Icon(Icons.receipt_long, size: 18),
                          label: Text('${t['documentId'] ?? t['id']} | Bs ${saldo.toStringAsFixed(0)}'),
                          backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(20),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: isNarrow ? 140 : 180,
                      child: FilledButton(
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
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processPaymentOnTickets(double monto, List<dynamic> ticketsToApply) async {
    setState(() => _loading = true);
    try {
      double remaining = monto;
      // Ordenar tickets por fecha ascendente
      final ticketsSorted = List<dynamic>.from(ticketsToApply)..sort((a, b) {
        final fa = DateTime.tryParse(a['fecha'] ?? '') ?? DateTime.now();
        final fb = DateTime.tryParse(b['fecha'] ?? '') ?? DateTime.now();
        return fa.compareTo(fb);
      });

      for (final t in ticketsSorted) {
        if (remaining <= 0) break;
        final saldo = double.tryParse(t['saldoPendiente']?.toString() ?? '0') ?? 0;
        if (saldo <= 0) continue;
        final apply = remaining >= saldo ? saldo : remaining;
        // Crear pago incluyendo relación a ticket. Usamos documentId si está disponible (algunos backends esperan documentId)
        final ticketRef = t['documentId'] ?? t['id'];
        final pagoPayload = {
          'montoPagado': apply,
          'fechaPago': DateTime.now().toIso8601String(),
          'ticket': ticketRef,
        };
        try {
          await _api.crearPago(pagoPayload);
        } catch (e) {
          // Mostrar error detallado y detener el proceso
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear pago: $e')));
          break;
        }

        final newSaldo = (double.parse(saldo.toString()) - apply);
        final nuevoEstado = newSaldo <= 0 ? 'Completo' : 'Incompleto';
        final ticketPayload = {
          'saldoPendiente': newSaldo,
          'cuota': (double.tryParse(t['cuota']?.toString() ?? '0') ?? 0) - apply,
          'estadoPago': nuevoEstado,
        };
        try {
          await (_api as dynamic).updateTicket(t['documentId'] ?? t['id'].toString(), ticketPayload);
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pago registrado pero error al actualizar ticket: $e')));
        }

        remaining -= apply;
      }

      // refresh pagos list
      try {
        final refreshedPagos = await _api.getPagos();
        setState(() {
          _pagos = refreshedPagos.where((p) {
            // Some payments may include a 'ticket' relation as Map with 'id' or 'documentId', or as primitive
            final ptRaw = p['ticket'];
            if (ptRaw == null) return false;
            if (ptRaw is Map) {
              final tid = ptRaw['id'];
              final tdoc = ptRaw['documentId'];
              if (tid != null && _tickets.any((t) => t['id'] == tid)) return true;
              if (tdoc != null && _tickets.any((t) => (t['documentId'] ?? '').toString() == tdoc.toString())) return true;
            } else {
              // primitive: could be numeric id or documentId string
              if (_tickets.any((t) => t['id'] == ptRaw || (t['documentId'] ?? '').toString() == ptRaw.toString())) return true;
            }
            return false;
          }).toList();
        });
      } catch (_) {}
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago registrado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error registrando pago: $e')));
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
