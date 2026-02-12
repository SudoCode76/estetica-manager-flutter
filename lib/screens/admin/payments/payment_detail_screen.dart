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

  // Calcula cuánto se va a pagar basado en la selección O en el input manual
  double get _montoTotalSeleccionado {
    double total = 0;
    _selectedTickets.forEach((id, selected) {
      if (selected) {
        final ticket = _ticketsConDeuda.firstWhere((t) => t['id'] == id, orElse: () => null);
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
    // Escuchar cambios en el input para actualizar UI si fuera necesario
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

      // Usamos las nuevas funciones optimizadas del repositorio
      final tickets = await repo.obtenerTicketsDeudaPorCliente(clientId);
      final pagos = await repo.obtenerHistorialPagosCliente(clientId);

      setState(() {
        _ticketsConDeuda = tickets;
        _historialPagos = pagos;
        // Reiniciar selección
        _selectedTickets.clear();
        _montoController.clear();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _onTicketTap(int id, double saldo) {
    setState(() {
      final isSelected = _selectedTickets[id] ?? false;
      _selectedTickets[id] = !isSelected;

      // Actualizar el texto del input con la suma de lo seleccionado
      _montoController.text = _montoTotalSeleccionado.toStringAsFixed(2);
    });
  }

  Future<void> _registrarPago() async {
    final montoIngresado = double.tryParse(_montoController.text) ?? 0.0;

    if (montoIngresado <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese un monto válido')));
      return;
    }

    if (montoIngresado > _totalDeudaGlobal + 1) { // +1 margen de error por decimales
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El monto excede la deuda total')));
       return;
    }

    setState(() => _loading = true);

    try {
      final repo = Provider.of<TicketRepository>(context, listen: false);
      double montoRestante = montoIngresado;

      // Lógica de distribución de pago:
      // 1. Si hay tickets seleccionados explícitamente, pagamos esos primero.
      // 2. Si no, pagamos los más antiguos primero (orden por defecto de la lista).

      List<dynamic> ticketsAPagar = [];

      // Verificar si hay selección manual
      final tieneSeleccion = _selectedTickets.containsValue(true);

      if (tieneSeleccion) {
        // Filtrar solo los seleccionados
        ticketsAPagar = _ticketsConDeuda.where((t) => _selectedTickets[t['id']] == true).toList();
      } else {
        // Usar todos (la lógica de bucle se detendrá cuando se acabe el dinero)
        ticketsAPagar = List.from(_ticketsConDeuda);
      }

      for (var ticket in ticketsAPagar) {
        if (montoRestante <= 0.01) break; // Terminar si se acaba el saldo

        final ticketId = ticket['id'].toString();
        final saldoTicket = (ticket['saldo_pendiente'] as num).toDouble();

        // Cuánto pagamos a este ticket: lo que queda del dinero O el saldo total del ticket
        double aPagar = (montoRestante >= saldoTicket) ? saldoTicket : montoRestante;

        await repo.registrarAbono(
          ticketId: ticketId,
          montoAbono: aPagar,
        );

        montoRestante -= aPagar;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago registrado correctamente'), backgroundColor: Colors.green));
        // Recargar datos en esta misma pantalla y limpiar selección para actualizar la UI in-place
        await _loadData();
        // Asegurar que el input y selección queden limpios
        _selectedTickets.clear();
        _montoController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al pagar: $e'), backgroundColor: Colors.red));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nombreCliente = '${widget.cliente['nombreCliente'] ?? ''} ${widget.cliente['apellidoCliente'] ?? ''}'.trim();

    return Scaffold(
      backgroundColor: colorScheme.surface, // Fondo limpio
      appBar: AppBar(
        title: const Text("Detalle de Cliente"),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TARJETA DE CLIENTE Y DEUDA TOTAL
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CLIENTE', style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(
                          nombreCliente,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),
                        Text('Total Adeudado', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(
                          'Bs ${_totalDeudaGlobal.toStringAsFixed(2)}',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary, // Color morado/primary
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. LISTA DE TICKETS CON DEUDA
                  if (_ticketsConDeuda.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline, size: 60, color: Colors.green.withValues(alpha: 0.5)),
                            const SizedBox(height: 10),
                            Text("Este cliente no tiene deudas pendientes", style: theme.textTheme.bodyLarge),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tickets con deuda', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text('${_ticketsConDeuda.length}', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Lista de tickets seleccionables
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _ticketsConDeuda.length,
                      itemBuilder: (context, index) {
                        final t = _ticketsConDeuda[index];
                        final id = t['id'];
                        final saldo = (t['saldo_pendiente'] as num).toDouble();
                        final isSelected = _selectedTickets[id] ?? false;

                        // Formatear info extra (tratamientos)
                        final sesiones = t['sesiones'] as List<dynamic>? ?? [];
                        String info = sesiones.isNotEmpty
                            ? sesiones.map((s) => s['tratamiento']?['nombretratamiento'] ?? '').join(', ')
                            : 'Ticket #$id';

                        if (info.length > 30) info = '${info.substring(0, 30)}...';

                        return GestureDetector(
                          onTap: () => _onTicketTap(id, saldo),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? colorScheme.primary.withValues(alpha: 0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? colorScheme.primary : Colors.transparent,
                                width: 2
                              ),
                              boxShadow: isSelected ? [] : [
                                BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(info, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                      Text('ID: $id', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Bs ${saldo.toStringAsFixed(2)}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // 3. INPUT DE MONTO A PAGAR
                    Text('Monto a pagar', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _montoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: theme.textTheme.headlineSmall,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.all(16),
                        hintText: '0.00',
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 4. BOTÓN DE REGISTRAR PAGO
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: FilledButton.icon(
                        onPressed: _registrarPago,
                        icon: const Icon(Icons.wallet),
                        label: const Text('Registrar Pago', style: TextStyle(fontSize: 18)),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // 5. HISTORIAL DE PAGOS (Acordeón)
                  ExpansionTile(
                    title: Text('Historial de pagos', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    shape: const Border(), // Quitar bordes por defecto
                    children: [
                      if (_historialPagos.isEmpty)
                        const Padding(padding: EdgeInsets.all(16), child: Text("Sin historial de pagos"))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _historialPagos.length,
                          itemBuilder: (context, index) {
                            final p = _historialPagos[index];
                            final monto = (p['monto'] as num?)?.toDouble() ?? 0.0;
                            final fecha = p['fecha_pago'] != null
                                ? DateFormat('dd MMM yyyy').format(DateTime.parse(p['fecha_pago']))
                                : '-';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey.shade200,
                                child: const Icon(Icons.history, color: Colors.grey, size: 20),
                              ),
                              title: Text('Pago de Bs ${monto.toStringAsFixed(2)}'),
                              subtitle: Text(fecha),
                              trailing: Text('Ticket #${p['ticket_id']}', style: const TextStyle(fontSize: 12)),
                            );
                          },
                        )
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
