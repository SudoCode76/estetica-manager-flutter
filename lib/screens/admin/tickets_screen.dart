import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_estetica/screens/admin/new_ticket_screen.dart';
import 'package:app_estetica/screens/admin/ticket_detail_screen.dart';
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
  bool showAtendidos = false; // false = pendientes, true = atendidos

  @override
  void initState() {
    super.initState();
    fetchSucursalesAndTickets();
  }

  Future<void> fetchSucursalesAndTickets() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      sucursales = await api.getSucursales();
      if (sucursales.isNotEmpty) {
        selectedSucursalId = sucursales.first['id'];
      }
      await fetchTickets();
    } catch (e) {
      errorMsg = 'No se pudo conectar al servidor.';
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchTickets() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      final data = await api.getTickets(
        sucursalId: selectedSucursalId,
        estadoTicket: showAtendidos,
      );
      tickets = data;
      filteredTickets = tickets;
    } catch (e) {
      errorMsg = 'No se pudo conectar al servidor.';
    }
    setState(() {
      isLoading = false;
    });
  }

  void filterTickets(String value) {
    setState(() {
      search = value;
      filteredTickets = tickets.where((t) {
        final cliente = t['cliente']?['nombreCliente'] ?? '';
        final apellido = t['cliente']?['apellidoCliente'] ?? '';
        final tratamiento = t['tratamiento']?['nombreTratamiento'] ?? '';
        return cliente.toLowerCase().contains(value.toLowerCase()) ||
            apellido.toLowerCase().contains(value.toLowerCase()) ||
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
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              icon: Icon(Icons.arrow_drop_down,
                                  color: colorScheme.primary),
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
                                setState(() {
                                  selectedSucursalId = value;
                                });
                                await fetchTickets();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filtro de estado (Pendientes / Atendidos)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Pendientes'),
                        icon: Icon(Icons.pending_actions),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Atendidos'),
                        icon: Icon(Icons.check_circle),
                      ),
                    ],
                    selected: {showAtendidos},
                    onSelectionChanged: (Set<bool> newSelection) async {
                      setState(() {
                        showAtendidos = newSelection.first;
                      });
                      await fetchTickets();
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.comfortable,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de tickets
            Expanded(
              child: isLoading
                  ? Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                ),
              )
                  : errorMsg != null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      errorMsg!,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: colorScheme.error),
                    ),
                  ],
                ),
              )
                  : filteredTickets.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      showAtendidos
                          ? Icons.check_circle_outline
                          : Icons.pending_actions_outlined,
                      size: 64,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      showAtendidos
                          ? 'No hay tickets atendidos'
                          : 'No hay tickets pendientes',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: filteredTickets.length,
                itemBuilder: (context, i) {
                  final t = filteredTickets[i];

                  final fechaDateTime = t['fecha'] != null
                      ? DateTime.parse(t['fecha'])
                      : null;
                  final hora = fechaDateTime != null
                      ? DateFormat('HH:mm').format(fechaDateTime)
                      : '-';
                  final fecha = fechaDateTime != null
                      ? DateFormat('dd/MM/yyyy')
                      .format(fechaDateTime)
                      : '-';

                  final cliente = t['cliente'] != null
                      ? ((t['cliente']['apellidoCliente'] ?? '')
                      .isNotEmpty
                      ? '${t['cliente']['nombreCliente'] ?? '-'} ${t['cliente']['apellidoCliente'] ?? ''}'
                      : t['cliente']['nombreCliente'] ?? '-')
                      : '-';

                  final tratamiento =
                      t['tratamiento']?['nombreTratamiento'] ??
                          '-';

                  final saldoPendiente =
                      t['saldoPendiente']?.toDouble() ?? 0.0;
                  final tieneSaldo = saldoPendiente > 0;
                  final estadoTicket = t['estadoTicket'] == true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TicketDetailScreen(ticket: t),
                          ),
                        );
                        await fetchTickets();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Text(
                                cliente.isNotEmpty
                                    ? cliente[0].toUpperCase()
                                    : '?',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cliente,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                      fontWeight:
                                      FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tratamiento,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$fecha - $hora',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                          color: Theme.of(
                                              context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (tieneSaldo) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .errorContainer,
                                        borderRadius:
                                        BorderRadius.circular(
                                            6),
                                      ),
                                      child: Row(
                                        mainAxisSize:
                                        MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.warning_amber,
                                            size: 14,
                                            color:
                                            Theme.of(context)
                                                .colorScheme
                                                .onErrorContainer,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Saldo: Bs ${saldoPendiente.toStringAsFixed(2)}',
                                            style:
                                            Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                              color: Theme.of(
                                                  context)
                                                  .colorScheme
                                                  .onErrorContainer,
                                              fontWeight:
                                              FontWeight
                                                  .bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Reemplazar IconButton y flecha por un botón más notorio y profesional
                            if (!estadoTicket)
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  shape: const CircleBorder(),
                                  backgroundColor: colorScheme.primary,
                                  padding: const EdgeInsets.all(12),
                                  elevation: 2,
                                ),
                                onPressed: () async {
                                  final documentId = t['documentId'];
                                  final success =
                                  await api.actualizarEstadoTicket(documentId, true);
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle, color: Colors.white),
                                            const SizedBox(width: 8),
                                            const Text('Ticket marcado como atendido'),
                                          ],
                                        ),
                                        backgroundColor: colorScheme.primary,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    await fetchTickets();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.error, color: Colors.white),
                                            const SizedBox(width: 8),
                                            const Text('Error al actualizar el ticket'),
                                          ],
                                        ),
                                        backgroundColor: colorScheme.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                                child: const Icon(Icons.check, color: Colors.white, size: 28),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ); // ✅ SOLO UNO (aquí estaba el extra)
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
