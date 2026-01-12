import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_estetica/screens/admin/ticket_detail_screen.dart';
import 'package:app_estetica/services/api_service.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';

class AllTicketsScreen extends StatefulWidget {
  const AllTicketsScreen({super.key});

  @override
  State<AllTicketsScreen> createState() => _AllTicketsScreenState();
}

class _AllTicketsScreenState extends State<AllTicketsScreen> {
  final ApiService api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> tickets = [];
  List<dynamic> filteredTickets = [];
  bool isLoading = true;
  String search = '';
  String? errorMsg;
  bool showAtendidos = false; // false = pendientes, true = atendidos
  bool sortAscending = true; // true = antiguo→nuevo, false = nuevo→antiguo
  SucursalProvider? _sucursalProvider;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = SucursalInherited.of(context);
    if (provider != _sucursalProvider) {
      _sucursalProvider?.removeListener(_onSucursalChanged);
      _sucursalProvider = provider;
      _sucursalProvider?.addListener(_onSucursalChanged);
      fetchTickets();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sucursalProvider?.removeListener(_onSucursalChanged);
    super.dispose();
  }

  void _onSucursalChanged() {
    fetchTickets();
  }

  Future<void> fetchTickets() async {
    if (_sucursalProvider?.selectedSucursalId == null) return;

    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      final data = await api.getTickets(
        sucursalId: _sucursalProvider!.selectedSucursalId,
        estadoTicket: showAtendidos,
      );
      tickets = data;

      // Aplicar filtro de búsqueda actual (sin filtro de fecha)
      if (search.isEmpty) {
        filteredTickets = tickets;
      } else {
        filteredTickets = tickets.where((t) {
          final cliente = t['cliente']?['nombreCliente'] ?? '';
          final apellido = t['cliente']?['apellidoCliente'] ?? '';
          final tratamientos = t['tratamientos'] as List<dynamic>? ?? [];
          final tratamientosMatch = tratamientos.any((tr) =>
            (tr['nombreTratamiento'] ?? '').toLowerCase().contains(search.toLowerCase())
          );
          return cliente.toLowerCase().contains(search.toLowerCase()) ||
              apellido.toLowerCase().contains(search.toLowerCase()) ||
              tratamientosMatch;
        }).toList();
      }
      sortTickets();
    } catch (e) {
      errorMsg = 'No se pudo conectar al servidor.';
    }
    setState(() {
      isLoading = false;
    });
  }

  void sortTickets() {
    filteredTickets.sort((a, b) {
      final dateA = a['fecha'] != null ? DateTime.parse(a['fecha']) : DateTime.now();
      final dateB = b['fecha'] != null ? DateTime.parse(b['fecha']) : DateTime.now();
      return sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });
  }

  void filterTickets(String value) {
    setState(() {
      search = value;
      filteredTickets = tickets.where((t) {
        final cliente = t['cliente']?['nombreCliente'] ?? '';
        final apellido = t['cliente']?['apellidoCliente'] ?? '';
        final tratamientos = t['tratamientos'] as List<dynamic>? ?? [];
        final tratamientosMatch = tratamientos.any((tr) =>
          (tr['nombreTratamiento'] ?? '').toLowerCase().contains(value.toLowerCase())
        );
        return cliente.toLowerCase().contains(value.toLowerCase()) ||
            apellido.toLowerCase().contains(value.toLowerCase()) ||
            tratamientosMatch;
      }).toList();
      sortTickets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Histórico de Tickets'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 3,
      ),
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
                          controller: _searchController,
                          hintText: 'Buscar por cliente o tratamiento',
                          leading: const Icon(Icons.search),
                          trailing: search.isNotEmpty
                              ? [
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      filterTickets('');
                                    },
                                  ),
                                ]
                              : null,
                          onChanged: filterTickets,
                          elevation: const WidgetStatePropertyAll(1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botón de ordenamiento
                      IconButton.filledTonal(
                        onPressed: () {
                          setState(() {
                            sortAscending = !sortAscending;
                            sortTickets();
                          });
                        },
                        icon: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                        tooltip: sortAscending ? 'Ordenar: Más antiguo primero' : 'Ordenar: Más nuevo primero',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(56, 56),
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 12),
                  // Indicador de que se muestran todos los tickets
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: Icon(
                        Icons.history,
                        size: 18,
                        color: colorScheme.secondary,
                      ),
                      label: Text(
                        'Mostrando todos los tickets',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.secondary,
                        ),
                      ),
                      backgroundColor: colorScheme.secondaryContainer,
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
                                  Icon(
                                    showAtendidos ? Icons.check_circle_outline : Icons.pending_actions_outlined,
                                    size: 64,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    showAtendidos ? 'No hay tickets atendidos' : 'No hay tickets pendientes',
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
                                final fechaDateTime = t['fecha'] != null ? DateTime.parse(t['fecha']) : null;
                                final hora = fechaDateTime != null ? DateFormat('HH:mm').format(fechaDateTime) : '-';
                                final fecha = fechaDateTime != null ? DateFormat('dd/MM/yyyy').format(fechaDateTime) : '-';
                                final cliente = t['cliente'] != null
                                    ? ((t['cliente']['apellidoCliente'] ?? '').isNotEmpty
                                        ? '${t['cliente']['nombreCliente'] ?? '-'} ${t['cliente']['apellidoCliente'] ?? ''}'
                                        : t['cliente']['nombreCliente'] ?? '-')
                                    : '-';
                                final tratamientos = t['tratamientos'] as List<dynamic>? ?? [];
                                final tratamientoTexto = tratamientos.isEmpty
                                    ? 'Sin tratamientos'
                                    : tratamientos.length == 1
                                        ? tratamientos[0]['nombreTratamiento'] ?? '-'
                                        : '${tratamientos.length} tratamientos';
                                final saldoPendiente = t['saldoPendiente']?.toDouble() ?? 0.0;
                                final tieneSaldo = saldoPendiente > 0;
                                final estadoTicket = t['estadoTicket'] == true;

                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.06),
                                            blurRadius: 20,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08)),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => TicketDetailScreen(ticket: t),
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
                                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                                  child: Text(
                                                    cliente.isNotEmpty ? cliente[0].toUpperCase() : '?',
                                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        cliente,
                                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        tratamientoTexto,
                                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                          color: Theme.of(context).colorScheme.primary,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.access_time,
                                                            size: 16,
                                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            '$fecha - $hora',
                                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (tieneSaldo) ...[
                                                        const SizedBox(height: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: Theme.of(context).colorScheme.errorContainer,
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(
                                                                Icons.warning_amber,
                                                                size: 14,
                                                                color: Theme.of(context).colorScheme.onErrorContainer,
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                'Saldo: Bs ${saldoPendiente.toStringAsFixed(2)}',
                                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                // Botón check mejorado
                                                if (!estadoTicket)
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 12.0),
                                                    child: _AttendButton(
                                                      onPressed: () async {
                                                        final documentId = t['documentId'];
                                                        final success = await api.actualizarEstadoTicket(documentId, true);
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
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
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

class _AttendButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AttendButton({required this.onPressed});

  @override
  State<_AttendButton> createState() => __AttendButtonState();
}

class __AttendButtonState extends State<_AttendButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ScaleTransition(
      scale: _animation,
      child: GestureDetector(
        onTapDown: (_) {
          _controller.forward();
        },
        onTapUp: (_) {
          _controller.reverse();
        },
        onTapCancel: () {
          _controller.reverse();
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.check, color: Colors.white, size: 28),
            onPressed: () {
              widget.onPressed();
              _controller.forward().then((_) => _controller.reverse());
            },
            splashRadius: 28,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

