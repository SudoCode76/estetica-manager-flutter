import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_estetica/screens/admin/new_ticket_screen.dart';
import 'package:app_estetica/services/api_service.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final ApiService api = ApiService();
  List<dynamic> tickets = [];
  List<dynamic> filteredTickets = [];
  List<dynamic> sucursales = [];
  int? selectedSucursalId;
  bool isLoading = true;
  String search = '';
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    fetchSucursalesAndTickets();
  }

  Future<void> fetchSucursalesAndTickets() async {
    setState(() { isLoading = true; errorMsg = null; });
    try {
      sucursales = await api.getSucursales();
      if (sucursales.isNotEmpty) {
        selectedSucursalId = sucursales.first['id'];
      }
      await fetchTickets();
    } catch (e) {
      errorMsg = 'No se pudo conectar al servidor.';
      setState(() { isLoading = false; });
    }
  }

  Future<void> fetchTickets() async {
    setState(() { isLoading = true; errorMsg = null; });
    try {
      final data = await api.getTickets(sucursalId: selectedSucursalId);
      tickets = data;
      filteredTickets = tickets;
    } catch (e) {
      errorMsg = 'No se pudo conectar al servidor.';
    }
    setState(() { isLoading = false; });
  }

  void filterTickets(String value) {
    setState(() {
      search = value;
      filteredTickets = tickets.where((t) {
        final cliente = t['cliente']?['nombreCliente'] ?? '';
        final tratamiento = t['tratamiento']?['nombreTratamiento'] ?? '';
        return cliente.toLowerCase().contains(value.toLowerCase()) ||
               tratamiento.toLowerCase().contains(value.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Barra de búsqueda y acciones
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SearchBar(
                          hintText: 'Buscar por cliente o tratamiento',
                          leading: const Icon(Icons.search),
                          onChanged: filterTickets,
                          elevation: const WidgetStatePropertyAll(1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: fetchTickets,
                        icon: const Icon(Icons.refresh),
                        label: const Text(''),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(56, 56),
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Filtro de sucursal
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sucursal:',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedSucursalId,
                              isExpanded: true,
                              icon: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                              style: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              items: sucursales.map((s) {
                                return DropdownMenuItem<int>(
                                  value: s['id'],
                                  child: Text(s['nombreSucursal'] ?? '-'),
                                );
                              }).toList(),
                              onChanged: (value) async {
                                setState(() { selectedSucursalId = value; });
                                await fetchTickets();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Lista de tickets
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                  : errorMsg != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                              const SizedBox(height: 16),
                              Text(
                                errorMsg!,
                                style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
                              ),
                            ],
                          ),
                        )
                      : filteredTickets.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 64, color: colorScheme.onSurfaceVariant),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No hay tickets registrados',
                                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredTickets.length,
                              itemBuilder: (context, i) {
                                final t = filteredTickets[i];
                                final fecha = t['fecha'] != null
                                    ? DateFormat('dd/MM/yyyy').format(DateTime.parse(t['fecha']))
                                    : '-';
                                final cliente = t['cliente'] != null
                                    ? ((t['cliente']['apellidoCliente'] ?? '').isNotEmpty
                                        ? '${t['cliente']['nombreCliente'] ?? '-'} ${t['cliente']['apellidoCliente'] ?? ''}'
                                        : t['cliente']['nombreCliente'] ?? '-')
                                    : '-';
                                final tratamiento = t['tratamiento']?['nombreTratamiento'] ?? '-';
                                final cuota = t['cuota']?.toString() ?? '-';
                                final saldo = t['saldoPendiente']?.toString() ?? '-';
                                final estadoPago = t['estadoPago'] ?? '-';
                                final estadoTicket = t['estadoTicket'] == true;
                                final sucursalNombre = t['sucursal']?['nombreSucursal'] ?? '-';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 1,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      // TODO: Ver detalles del ticket
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Header
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: estadoTicket
                                                      ? colorScheme.primaryContainer
                                                      : colorScheme.errorContainer,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  estadoTicket ? Icons.check_circle : Icons.cancel,
                                                  color: estadoTicket
                                                      ? colorScheme.onPrimaryContainer
                                                      : colorScheme.onErrorContainer,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      cliente,
                                                      style: textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      tratamiento,
                                                      style: textTheme.bodyMedium?.copyWith(
                                                        color: colorScheme.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton.filledTonal(
                                                onPressed: () {
                                                  // TODO: Editar ticket
                                                },
                                                icon: const Icon(Icons.edit_outlined),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          const Divider(),
                                          const SizedBox(height: 12),
                                          // Información
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _InfoChip(
                                                  icon: Icons.location_on_outlined,
                                                  label: 'Sucursal',
                                                  value: sucursalNombre,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _InfoChip(
                                                  icon: Icons.calendar_today_outlined,
                                                  label: 'Fecha',
                                                  value: fecha,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _InfoChip(
                                                  icon: Icons.payments_outlined,
                                                  label: 'Cuota',
                                                  value: 'Bs $cuota',
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _InfoChip(
                                                  icon: Icons.account_balance_wallet_outlined,
                                                  label: 'Saldo',
                                                  value: 'Bs $saldo',
                                                  valueColor: saldo != '0' ? colorScheme.error : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          // Estado de pago
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: estadoPago == 'Completo'
                                                  ? colorScheme.primaryContainer
                                                  : colorScheme.errorContainer,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  estadoPago == 'Completo'
                                                      ? Icons.check_circle_outline
                                                      : Icons.warning_amber_outlined,
                                                  size: 18,
                                                  color: estadoPago == 'Completo'
                                                      ? colorScheme.onPrimaryContainer
                                                      : colorScheme.onErrorContainer,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Estado: $estadoPago',
                                                  style: textTheme.labelMedium?.copyWith(
                                                    color: estadoPago == 'Completo'
                                                        ? colorScheme.onPrimaryContainer
                                                        : colorScheme.onErrorContainer,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewTicketScreen()),
          );
          if (result == true) fetchTickets();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Ticket'),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            color: valueColor ?? colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

