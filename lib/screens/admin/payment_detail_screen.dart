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

    final TextEditingController montoCtrl = TextEditingController(text: defaultAmount.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar pago'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: montoCtrl,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monto a pagar'),
            validator: (v) {
              final val = double.tryParse(v ?? '0') ?? 0;
              if (val <= 0) return 'Ingresa un monto válido';
              if (val > defaultAmount) return 'El monto no puede ser mayor al total de los tickets seleccionados';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(context, true);
            final monto = double.tryParse(montoCtrl.text.trim()) ?? 0;
            await _processPaymentOnTickets(monto, targetTickets);
          }, child: const Text('Pagar')),
        ],
      ),
    );

    if (result == true) {
      await _loadTickets();
      // indicar al screen padre que hubo cambios
      Navigator.pop(context, true);
    }
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
        // Crear pago con payload mínimo: algunos backends no esperan relaciones en el content-type 'pagos'
        final pagoPayload = {
          'montoPagado': apply,
          'fechaPago': DateTime.now().toIso8601String(),
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
          await _api.updateTicket(t['documentId'] ?? t['id'].toString(), ticketPayload);
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pago registrado pero error al actualizar ticket: $e')));
        }

        remaining -= apply;
      }

      // refresh pagos list
      try {
        final refreshedPagos = await _api.getPagos();
        setState(() { _pagos = refreshedPagos.where((p) {
          final pc = p['cliente'] is Map ? p['cliente']['id'] : p['cliente'];
          if (pc != null && pc == widget.cliente['id']) return true;
          final pt = p['ticket'] is Map ? p['ticket']['id'] : p['ticket'];
          if (pt != null) return _tickets.any((t) => t['id'] == pt);
          return false;
        }).toList(); });
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
    return Scaffold(
      appBar: AppBar(title: Text('${widget.cliente['nombreCliente'] ?? ''} ${widget.cliente['apellidoCliente'] ?? ''}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Text('Deuda total: Bs ${_totalDeuda.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  // Controls: select all, pay selected
                  Row(
                    children: [
                      Checkbox(
                        value: _tickets.isNotEmpty && _selected.values.every((v) => v),
                        onChanged: (v) {
                          setState(() {
                            for (final k in _selected.keys) _selected[k] = v == true;
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      const Text('Seleccionar todos'),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _tickets.where((t) => _selected[t['id']] == true).isEmpty ? null : () => _makePaymentForSelected(),
                        icon: const Icon(Icons.payments),
                        label: const Text('Pagar seleccionados'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: _tickets.isEmpty
                        ? Center(child: Text('No hay tickets con deuda', style: Theme.of(context).textTheme.bodyLarge))
                        : ListView.separated(
                            itemCount: _tickets.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final t = _tickets[index];
                              final saldo = double.tryParse(t['saldoPendiente']?.toString() ?? '0') ?? 0;
                              final tid = t['id'] as int;
                              return ListTile(
                                leading: Checkbox(
                                  value: _selected[tid] ?? false,
                                  onChanged: (v) => setState(() => _selected[tid] = v == true),
                                ),
                                title: Text('Ticket ${t['documentId'] ?? t['id']} - Fecha: ${t['fecha'] ?? ''}'),
                                subtitle: Text('Saldo pendiente: Bs ${saldo.toStringAsFixed(2)}'),
                                trailing: FilledButton(onPressed: () => _makePaymentForSelected(singleTicketId: tid), child: const Text('Pagar')),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 12),
                  // Historial de pagos
                  Align(alignment: Alignment.centerLeft, child: Text('Historial de pagos', style: Theme.of(context).textTheme.titleMedium)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _pagos.isEmpty
                        ? Center(child: Text('No hay registros de pago', style: Theme.of(context).textTheme.bodyLarge))
                        : ListView.separated(
                            itemCount: _pagos.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final p = _pagos[index];
                              final monto = double.tryParse(p['montoPagado']?.toString() ?? '0') ?? 0;
                              final fecha = p['fechaPago'] ?? p['createdAt'] ?? '';
                              return ListTile(
                                title: Text('Bs ${monto.toStringAsFixed(2)}'),
                                subtitle: Text('Fecha: ${fecha.toString()}'),
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

