import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_estetica/repositories/ticket_repository.dart';

class PaymentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> cliente;
  const PaymentDetailScreen({super.key, required this.cliente});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  bool _loading = true;
  List<dynamic> _ticketsConDeuda = [];
  List<dynamic> _historialPagos = [];

  // Selección para pago múltiple
  final Map<int, bool> _selectedTickets = {};

  // Controlador para monto manual
  final TextEditingController _montoController = TextEditingController();

  double get _totalDeudaGlobal {
    return _ticketsConDeuda.fold(0.0, (sum, t) {
      return sum + ((t['saldo_pendiente'] as num?)?.toDouble() ?? 0.0);
    });
  }

  // Calcula cuánto se va a pagar basado en la selección
  double get _montoTotalSeleccionado {
    double total = 0;
    _selectedTickets.forEach((id, selected) {
      if (selected) {
        final ticket = _ticketsConDeuda.firstWhere(
          (t) => t['id'] == id,
          orElse: () => null,
        );
        if (ticket != null) {
          total += (ticket['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;
        }
      }
    });
    return total;
  }

  @override
  void initState() {
    super.initState();
    _montoController.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final repo = Provider.of<TicketRepository>(context, listen: false);
      final clientId = widget.cliente['id'];

      final tickets = await repo.obtenerTicketsDeudaPorCliente(clientId);
      final pagos = await repo.obtenerHistorialPagosCliente(clientId);

      if (mounted) {
        setState(() {
          _ticketsConDeuda = tickets;
          _historialPagos = pagos;
          _selectedTickets.clear();
          _montoController.clear();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _onTicketTap(int id, double saldo) {
    setState(() {
      final isSelected = _selectedTickets[id] ?? false;

      // Si ya estaba seleccionado, lo desmarcamos
      if (isSelected) {
        _selectedTickets[id] = false;
      } else {
        // Si no estaba seleccionado, lo marcamos
        _selectedTickets[id] = true;
      }

      // Actualizar input con la suma total seleccionada
      double total = _montoTotalSeleccionado;
      if (total > 0) {
        _montoController.text = total.toStringAsFixed(2);
      } else {
        _montoController.clear();
      }
    });
  }

  Future<void> _registrarPago() async {
    final montoIngresado = double.tryParse(_montoController.text) ?? 0.0;

    if (montoIngresado <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingrese un monto válido')));
      return;
    }

    if (montoIngresado > _totalDeudaGlobal + 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto excede la deuda total')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final repo = Provider.of<TicketRepository>(context, listen: false);
      double montoRestante = montoIngresado;
      List<dynamic> ticketsAPagar = [];

      final tieneSeleccion = _selectedTickets.containsValue(true);

      if (tieneSeleccion) {
        ticketsAPagar = _ticketsConDeuda
            .where((t) => _selectedTickets[t['id']] == true)
            .toList();
      } else {
        ticketsAPagar = List.from(_ticketsConDeuda);
      }

      for (var ticket in ticketsAPagar) {
        if (montoRestante <= 0.01) break;

        final ticketId = ticket['id'].toString();
        final saldoTicket = (ticket['saldo_pendiente'] as num).toDouble();
        double aPagar = (montoRestante >= saldoTicket)
            ? saldoTicket
            : montoRestante;

        await repo.registrarAbono(ticketId: ticketId, montoAbono: aPagar);
        montoRestante -= aPagar;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pago registrado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al pagar: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  // Helper para acortar UUIDs largos (ej: "3c089a44..." -> "#3c089a44")
  String _shortId(String? id) {
    if (id == null) return '-';
    if (id.length > 8) return '#${id.substring(0, 8)}';
    return '#$id';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nombreCliente =
        '${widget.cliente['nombreCliente'] ?? ''} ${widget.cliente['apellidoCliente'] ?? ''}'
            .trim();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("Detalle de Cliente"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. HEADER CLIENTE
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'DEUDA TOTAL',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bs ${_totalDeudaGlobal.toStringAsFixed(2)}',
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                              fontSize: 40,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            nombreCliente,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 2. TICKETS CON DEUDA (Sin circulitos, estilo tarjeta seleccionable)
                    if (_ticketsConDeuda.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.green.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "¡Todo al día!",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Selecciona tickets a pagar',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _ticketsConDeuda.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final t = _ticketsConDeuda[index];
                          final id = t['id'];
                          final saldo = (t['saldo_pendiente'] as num)
                              .toDouble();
                          final isSelected = _selectedTickets[id] ?? false;

                          final sesiones =
                              t['sesiones'] as List<dynamic>? ?? [];
                          String info = sesiones.isNotEmpty
                              ? sesiones
                                    .map(
                                      (s) =>
                                          s['tratamiento']?['nombretratamiento'] ??
                                          '',
                                    )
                                    .join(', ')
                              : 'Ticket sin detalle';

                          return GestureDetector(
                            onTap: () => _onTicketTap(id, saldo),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primaryContainer
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          info,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? colorScheme.primary
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Ticket ${_shortId(id.toString())}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isSelected
                                                ? colorScheme.primary
                                                      .withOpacity(0.7)
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Pendiente',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        'Bs ${saldo.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: isSelected
                                              ? colorScheme.primary
                                              : colorScheme.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // 3. INPUT Y BOTÓN
                      Text(
                        'Registrar Pago',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: _montoController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Monto (Bs)',
                                prefixIcon: const Icon(Icons.attach_money),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 5,
                            child: SizedBox(
                              height: 56,
                              child: FilledButton(
                                onPressed: _registrarPago,
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  elevation: 2,
                                ),
                                child: const Text(
                                  'CONFIRMAR',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 40),

                    // 5. HISTORIAL DE PAGOS (ARREGLADO)
                    if (_historialPagos.isNotEmpty) ...[
                      Text(
                        'Historial reciente',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _historialPagos.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final p = _historialPagos[index];
                          final monto = (p['monto'] as num?)?.toDouble() ?? 0.0;

                          String fechaStr = '-';
                          try {
                            final rawDate = p['fecha_pago'];
                            final date = rawDate is DateTime
                                ? rawDate
                                : DateTime.tryParse(rawDate.toString());
                            if (date != null) {
                              fechaStr = DateFormat(
                                'dd MMM, HH:mm',
                                'es',
                              ).format(date);
                            }
                          } catch (_) {}

                          // Obtenemos ID y lo cortamos
                          final fullId =
                              p['ticket_id']?.toString() ??
                              (p['ticket']?['id']?.toString());
                          final shortTicketId = _shortId(fullId);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.grey.shade100,
                              child: const Icon(
                                Icons.receipt,
                                color: Colors.grey,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              'Pago de Bs ${monto.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              fechaStr,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            // Usamos trailing para el ID del ticket, bien alineado a la derecha
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                shortTicketId,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                  fontFamily: 'Monospace',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
