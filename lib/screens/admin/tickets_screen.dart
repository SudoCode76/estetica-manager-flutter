import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_estetica/screens/admin/ticket_detail_screen.dart';
import 'package:app_estetica/screens/admin/all_tickets_screen.dart';
import 'package:app_estetica/services/api_service.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:provider/provider.dart';
import 'package:app_estetica/providers/ticket_provider.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final ApiService api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  String search = '';
  String? errorMsg;
  bool showAtendidos = false; // false = pendientes, true = atendidos
  bool sortAscending = true; // true = antiguo→nuevo, false = nuevo→antiguo
  bool showOnlyToday = true; // true = solo hoy, false = todos los tickets
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
      _sucursalProvider = provider;
      // Al cambiar la sucursal, pedir al TicketProvider que recargue
      _reloadTicketsForCurrentFilters();
    }
  }

  Future<void> _reloadTicketsForCurrentFilters() async {
    try {
      final ticketProvider = context.read<TicketProvider>();
      await ticketProvider.fetchTickets(sucursalId: _sucursalProvider?.selectedSucursalId, estadoTicket: showAtendidos);
    } catch (e) {
      // Registrar pero no interrumpir UI
      print('TicketsScreen: Error recargando tickets en didChangeDependencies: $e');
    }
  }

  void _onRefreshPressed() async {
    final ticketProvider = context.read<TicketProvider>();
    await ticketProvider.fetchTickets(sucursalId: _sucursalProvider?.selectedSucursalId, estadoTicket: showAtendidos);
  }

  void filterTicketsBySearch(String value) {
    setState(() {
      search = value;
    });
  }

  List<dynamic> _computeFilteredTickets(List<dynamic> tickets) {
    // Filtrar por fecha de hoy si showOnlyToday es true
    List<dynamic> dateFilteredTickets = tickets;
    if (showOnlyToday) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      dateFilteredTickets = tickets.where((t) {
        if (t['fecha'] == null) return false;
        final ticketDate = DateTime.parse(t['fecha']);
        return ticketDate.isAfter(today.subtract(const Duration(seconds: 1))) &&
            ticketDate.isBefore(tomorrow);
      }).toList();
    }

    // Aplicar filtro de búsqueda actual
    List<dynamic> filtered;
    if (search.isEmpty) {
      filtered = dateFilteredTickets;
    } else {
      filtered = dateFilteredTickets.where((t) {
        final cliente = t['cliente']?['nombreCliente'] ?? '';
        final apellido = t['cliente']?['apellidoCliente'] ?? '';
        final tratamientos = t['tratamientos'] as List<dynamic>? ?? [];
        final tratamientosMatch = tratamientos.any((tr) => (tr['nombreTratamiento'] ?? '').toLowerCase().contains(search.toLowerCase()));
        return cliente.toLowerCase().contains(search.toLowerCase()) ||
            apellido.toLowerCase().contains(search.toLowerCase()) ||
            tratamientosMatch;
      }).toList();
    }

    // Ordenar
    filtered.sort((a, b) {
      final dateA = a['fecha'] != null ? DateTime.parse(a['fecha']) : DateTime.now();
      final dateB = b['fecha'] != null ? DateTime.parse(b['fecha']) : DateTime.now();
      return sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });

    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sucursalProvider?.removeListener(_onSucursalChanged);
    super.dispose();
  }

  void _onSucursalChanged() {
    // Cuando cambia la sucursal en el provider, recargar tickets
    _reloadTicketsForCurrentFilters();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final ticketProvider = context.watch<TicketProvider>();
    final providerTickets = ticketProvider.tickets;
    final isLoading = ticketProvider.isLoading;
    final providerError = ticketProvider.error;

    final filteredTickets = _computeFilteredTickets(providerTickets);

    return SafeArea(
      child: Column(
        children: [
          // Barra local removida: el header global ahora vive en AdminHomeScreen
          // Barra de búsqueda y acciones
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                                    filterTicketsBySearch('');
                                  },
                                ),
                              ]
                            : null,
                        onChanged: filterTicketsBySearch,
                        elevation: const WidgetStatePropertyAll(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Botón de ordenamiento
                    IconButton.filledTonal(
                      onPressed: () {
                        setState(() {
                          sortAscending = !sortAscending;
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
                      onPressed: _onRefreshPressed,
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
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<bool>(
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
                          await context.read<TicketProvider>().fetchTickets(sucursalId: _sucursalProvider?.selectedSucursalId, estadoTicket: showAtendidos);
                        },
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.comfortable,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Indicador de filtro por fecha y botón para ver histórico
                Row(
                  children: [
                    Chip(
                      avatar: Icon(
                        Icons.today,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      label: Text(
                        'Solo hoy',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                      backgroundColor: colorScheme.primaryContainer,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AllTicketsScreen(),
                          ),
                        ).then((_) => context.read<TicketProvider>().fetchTickets(sucursalId: _sucursalProvider?.selectedSucursalId, estadoTicket: showAtendidos));
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('Ver todos'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                : providerError != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                            const SizedBox(height: 16),
                            Text(
                              providerError,
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
                                          await context.read<TicketProvider>().fetchTickets(sucursalId: _sucursalProvider?.selectedSucursalId, estadoTicket: showAtendidos);
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
                                                    onPressedAsync: () async {
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
                                                        await context.read<TicketProvider>().fetchTickets(sucursalId: _sucursalProvider?.selectedSucursalId, estadoTicket: showAtendidos);
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
                              ); // ✅ SOLO UNO (aquí estaba el extra)
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _AttendButton extends StatefulWidget {
  // Ahora recibe una función asíncrona que realizará la acción (API call + refresh)
  final Future<void> Function()? onPressedAsync;

  const _AttendButton({required this.onPressedAsync});

  @override
  State<_AttendButton> createState() => __AttendButtonState();
}

class __AttendButtonState extends State<_AttendButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _isLoading = false;

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
            // Mostrar loader cuando está procesando
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : const Icon(Icons.check, color: Colors.white, size: 28),
            onPressed: (_isLoading || widget.onPressedAsync == null)
                ? null
                : () async {
                    setState(() { _isLoading = true; });
                    try {
                      await widget.onPressedAsync!();
                    } catch (e) {
                      // El callback debería manejar errores y mostrar snackbars; aquí solo aseguramos que se quite el loader
                      print('AttendButton: error en onPressedAsync: $e');
                    } finally {
                      if (mounted) setState(() { _isLoading = false; });
                      _controller.forward().then((_) => _controller.reverse());
                    }
                  },
            splashRadius: 28,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
