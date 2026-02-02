import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_estetica/screens/admin/ticket_detail_screen.dart';
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
  bool sortAscending = true; // true = antiguo→nuevo, false = nuevo→antiguo
  bool showOnlyToday = true; // Siempre true - solo mostrar tickets de hoy
  SucursalProvider? _sucursalProvider;
  bool _isFirstLoad = true; // Flag para controlar la primera carga
  Timer? _debounce; // debounce for search
  List<dynamic>? _searchResults; // when searching across history
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _showHistoryMode = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = SucursalInherited.of(context);

    // Detectar si el provider cambió
    final providerChanged = provider != _sucursalProvider;

    if (providerChanged) {
      // Remover listener anterior si existe
      _sucursalProvider?.removeListener(_onSucursalChanged);
      _sucursalProvider = provider;
      // Agregar nuevo listener
      _sucursalProvider?.addListener(_onSucursalChanged);
    }

    // Cargar tickets en la primera vez o cuando cambia el provider
    if (_isFirstLoad || providerChanged) {
      _isFirstLoad = false;
      // Usar addPostFrameCallback para evitar llamar durante el build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _reloadTicketsForCurrentFilters();
        }
      });
    }
  }

  Future<void> _reloadTicketsForCurrentFilters() async {
    if (!mounted) return;

    try {
      final ticketProvider = context.read<TicketProvider>();
      // Cargar tickets del día actual
      await ticketProvider.fetchTickets(
        sucursalId: _sucursalProvider?.selectedSucursalId,
      );
    } catch (e) {
      // Registrar pero no interrumpir UI
      print('TicketsScreen: Error recargando tickets: $e');
      if (mounted) {
        setState(() {
          errorMsg = 'Error al cargar tickets: $e';
        });
      }
    }
  }

  void _onRefreshPressed() async {
    if (!mounted) return;

    setState(() {
      errorMsg = null; // Limpiar error anterior
    });

    _reloadTicketsForCurrentFilters();
  }

  void _onSucursalChanged() {
    // Cuando cambia la sucursal en el provider, recargar tickets
    if (mounted) {
      _reloadTicketsForCurrentFilters();
    }
  }

  void filterTicketsBySearch(String value) {
    setState(() {
      search = value;
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // If empty, clear and reload today's tickets
      if (search.trim().isEmpty) {
        setState(() {
          _searchResults = null;
        });
        _reloadTicketsForCurrentFilters();
        return;
      }

      // Quick local match on already-loaded provider tickets
      try {
        final providerTickets = context.read<TicketProvider>().tickets;
        if (providerTickets.isNotEmpty && search.trim().isNotEmpty) {
          final term = _normalize(search);
          final localMatches = providerTickets.where((t) {
            final clienteObj = t['cliente'] ?? t['cliente_id'];
            String nombre = '';
            String apellido = '';
            if (clienteObj is Map) {
              nombre = (clienteObj['nombrecliente'] ?? clienteObj['nombreCliente'] ?? clienteObj['nombre'] ?? '').toString();
              apellido = (clienteObj['apellidocliente'] ?? clienteObj['apellidoCliente'] ?? clienteObj['apellido'] ?? '').toString();
            } else if (clienteObj is List && clienteObj.isNotEmpty && clienteObj.first is Map) {
              final c0 = clienteObj.first;
              nombre = (c0['nombrecliente'] ?? c0['nombreCliente'] ?? c0['nombre'] ?? '').toString();
              apellido = (c0['apellidocliente'] ?? c0['apellidoCliente'] ?? c0['apellido'] ?? '').toString();
            }
            final combined = _normalize('$nombre $apellido');
            return combined.contains(term);
          }).toList();
          if (localMatches.isNotEmpty) {
            setState(() {
              _searchResults = localMatches;
            });
            // still fetch server results to ensure completeness, but show local instantly
          }
        }
      } catch (_) {}

      // Server-side search (paginated)
      try {
        if (_sucursalProvider?.selectedSucursalId == null) return;
        final resp = await api.searchTickets(query: search.trim(), sucursalId: _sucursalProvider!.selectedSucursalId!, page: 1, pageSize: 50);
        final items = resp['items'] as List<dynamic>? ?? [];
        setState(() {
          _searchResults = items;
        });
      } catch (e) {
        // ignore errors silently in search
      }
    });
  }

  String _normalize(String s) {
    var str = s.toLowerCase();
    const accents = {
      'á':'a','à':'a','ä':'a','â':'a','ã':'a',
      'é':'e','è':'e','ë':'e','ê':'e',
      'í':'i','ì':'i','ï':'i','î':'i',
      'ó':'o','ò':'o','ö':'o','ô':'o','õ':'o',
      'ú':'u','ù':'u','ü':'u','û':'u','ñ':'n','ç':'c'
    };
    accents.forEach((k,v) { str = str.replaceAll(k, v); });
    str = str.replaceAll(RegExp(r"[^a-z0-9\s]"), ' ');
    return str.replaceAll(RegExp(r"\s+"), ' ').trim();
  }

  List<dynamic> _computeFilteredTickets(List<dynamic> tickets) {
    // Decide data source: if _searchResults is present (user searching), use it; else use provider tickets
    final source = (_searchResults != null) ? _searchResults! : tickets;

    // Filtrar por fecha de hoy si showOnlyToday is true AND not in history/search mode
    List<dynamic> dateFilteredTickets = source;
    if (showOnlyToday && !_showHistoryMode && _searchResults == null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      dateFilteredTickets = source.where((t) {
        if (t['created_at'] == null) return false;
        final ticketDate = DateTime.parse(t['created_at']);
        return ticketDate.isAfter(today.subtract(const Duration(seconds: 1))) && ticketDate.isBefore(tomorrow);
      }).toList();
    }

    // Aplicar filtro de búsqueda actual (si hay texto)
    List<dynamic> filtered;
    if (search.trim().isEmpty) {
      filtered = dateFilteredTickets;
    } else {
      final term = _normalize(search);
      filtered = dateFilteredTickets.where((t) {
        // Buscar en múltiples claves y formatos
        String nombre = '';
        String apellido = '';
        String telefono = '';
        String email = '';
        // cliente puede ser Map o Map under different keys or List
        final clienteObj = t['cliente'] ?? t['cliente_id'];
        if (clienteObj is List && clienteObj.isNotEmpty) {
          final c0 = clienteObj.first;
          if (c0 is Map) {
            nombre = (c0['nombrecliente'] ?? c0['nombreCliente'] ?? c0['nombre'] ?? '').toString();
            apellido = (c0['apellidocliente'] ?? c0['apellidoCliente'] ?? c0['apellido'] ?? '').toString();
            telefono = (c0['telefono'] ?? c0['phone'] ?? '').toString();
            email = (c0['email'] ?? '').toString();
          }
        } else if (clienteObj is Map) {
          nombre = (clienteObj['nombrecliente'] ?? clienteObj['nombreCliente'] ?? clienteObj['nombre'] ?? '').toString();
          apellido = (clienteObj['apellidocliente'] ?? clienteObj['apellidoCliente'] ?? clienteObj['apellido'] ?? '').toString();
          telefono = (clienteObj['telefono'] ?? clienteObj['phone'] ?? '').toString();
          email = (clienteObj['email'] ?? '').toString();
        }

        final nNorm = _normalize(nombre);
        final aNorm = _normalize(apellido);
        final tNorm = _normalize(telefono);
        final eNorm = _normalize(email);

        // revisar tratamientos en sesiones o en 'tratamientos'
        final sesiones = (t['sesiones'] as List<dynamic>?) ?? (t['tratamientos'] as List<dynamic>?) ?? [];
        final tratamientosMatch = sesiones.any((s) {
          try {
            final trat = s is Map ? (s['tratamiento'] ?? s['tratamiento_id'] ?? s) : s;
            String nombreTrat = '';
            if (trat is Map) nombreTrat = (trat['nombretratamiento'] ?? trat['nombreTratamiento'] ?? trat['nombre'] ?? '').toString();
            else if (s is Map) nombreTrat = (s['nombreTratamiento'] ?? s['nombre'] ?? '').toString();
            return _normalize(nombreTrat).contains(term);
          } catch (e) {
            return false;
          }
        });

        if (nNorm.contains(term) || aNorm.contains(term) || tNorm.contains(term) || eNorm.contains(term) || tratamientosMatch) return true;
        final clienteFull = _normalize('$nombre $apellido');
        if (clienteFull.contains(term)) return true;
        return false;
      }).toList();
    }

    // Ordenar
    filtered.sort((a, b) {
      final dateA = a['created_at'] != null ? DateTime.parse(a['created_at']) : DateTime.now(); // ✅
      final dateB = b['created_at'] != null ? DateTime.parse(b['created_at']) : DateTime.now(); // ✅
      return sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });

    return filtered;
  }

  void _onShowTodayPressed() async {
    setState(() {
      _showHistoryMode = false;
      _rangeStart = null;
      _rangeEnd = null;
    });
    _reloadTicketsForCurrentFilters();
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _rangeStart != null && _rangeEnd != null ? DateTimeRange(start: _rangeStart!, end: _rangeEnd!) : null,
    );

    if (picked == null) return;

    // Asegurarnos que start <= end
    DateTime start = picked.start;
    DateTime end = picked.end;
    if (start.isAfter(end)) {
      final tmp = start;
      start = end;
      end = tmp;
    }

    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      _showHistoryMode = true;
      errorMsg = null;
    });

    try {
      if (_sucursalProvider?.selectedSucursalId == null) {
        setState(() => errorMsg = 'Seleccione una sucursal primero');
        return;
      }

      await context.read<TicketProvider>().fetchTicketsByRange(
        start: _rangeStart!,
        end: _rangeEnd!,
        sucursalId: _sucursalProvider!.selectedSucursalId!,
      );
    } catch (e) {
      setState(() => errorMsg = 'Error al cargar historial: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sucursalProvider?.removeListener(_onSucursalChanged);
    _debounce?.cancel();
    super.dispose();
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

              const SizedBox(height: 12),

              // Controles de Historial
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _selectDateRange,
                      child: Text(_rangeStart == null || _rangeEnd == null
                          ? 'Seleccionar rango'
                          : '${DateFormat('dd/MM/yyyy').format(_rangeStart!)} - ${DateFormat('dd/MM/yyyy').format(_rangeEnd!)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _onShowTodayPressed,
                    child: const Text('Hoy'),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),

        // Lista de tickets
        Expanded(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Cargando tickets...',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : providerError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                              const SizedBox(height: 16),
                              Text(
                                'Error al cargar tickets',
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                providerError,
                                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: () {
                                  // Forzar recarga
                                  context.read<TicketProvider>().clearError();
                                  _onRefreshPressed();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredTickets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_busy,
                                  size: 64,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _showHistoryMode ? 'No hay tickets en ese rango' : 'No hay tickets para hoy',
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
                              final fechaDateTime = t['created_at'] != null ? DateTime.parse(t['created_at']) : null;                              final hora = fechaDateTime != null ? DateFormat('HH:mm').format(fechaDateTime) : '-';
                              final fecha = fechaDateTime != null ? DateFormat('dd/MM/yyyy').format(fechaDateTime) : '-';
                              final clienteObj = t['cliente'];
                              String cliente = '-';
                              if (clienteObj != null) {
                                cliente = '${clienteObj['nombrecliente'] ?? ''} ${clienteObj['apellidocliente'] ?? ''}'.trim();
                                if (cliente.isEmpty) cliente = '-';
                              }

                              final sesiones = t['sesiones'] as List<dynamic>? ?? [];
                              final List<String> nombresTratamientos = [];

                              for (var s in sesiones) {
                                if (s['tratamiento'] != null) {
                                  nombresTratamientos.add(s['tratamiento']['nombretratamiento'] ?? '');
                                }
                              }

                              final tratamientoTexto = nombresTratamientos.isEmpty
                                  ? 'Sin tratamientos'
                                  : nombresTratamientos.length == 1
                                  ? nombresTratamientos.first
                                  : '${nombresTratamientos.length} tratamientos';

                              final saldoPendiente = (t['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;                              final tieneSaldo = saldoPendiente > 0;
                              // final estadoTicket = t['estadoTicket'] == true; // variable no usada, eliminada

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
                                          _reloadTicketsForCurrentFilters();
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
