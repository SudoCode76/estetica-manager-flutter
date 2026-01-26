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
  bool sortAscending = false; // false = nuevo→antiguo (más reciente primero)
  SucursalProvider? _sucursalProvider;
  DateTimeRange? _selectedDateRange; // Para filtrar por rango de fechas

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
      // Obtener TODOS los tickets de la sucursal (sin filtro de fecha)
      final sucursalId = _sucursalProvider!.selectedSucursalId!;

      // Usar query directa a Supabase para obtener todos los tickets
      final data = await api.getAllTickets(sucursalId: sucursalId);
      tickets = data;

      // Aplicar filtros
      applyFilters();
    } catch (e) {
      print('Error fetching tickets: $e');
      errorMsg = 'No se pudo conectar al servidor: $e';
    }
    setState(() {
      isLoading = false;
    });
  }

  void applyFilters() {
    filteredTickets = tickets.where((t) {
      // Filtro por búsqueda de texto
      if (search.isNotEmpty) {
        final cliente = t['cliente'];
        final nombreCliente = (cliente?['nombrecliente'] ?? '').toLowerCase();
        final apellidoCliente = (cliente?['apellidocliente'] ?? '').toLowerCase();
        final sesiones = t['sesiones'] as List<dynamic>? ?? [];

        final tratamientosMatch = sesiones.any((sesion) {
          final tratamiento = sesion['tratamiento'];
          return tratamiento != null &&
                 (tratamiento['nombretratamiento'] ?? '').toLowerCase().contains(search.toLowerCase());
        });

        final matchesSearch = nombreCliente.contains(search.toLowerCase()) ||
            apellidoCliente.contains(search.toLowerCase()) ||
            tratamientosMatch;

        if (!matchesSearch) return false;
      }

      // Filtro por rango de fechas
      if (_selectedDateRange != null) {
        final createdAt = t['created_at'] != null ? DateTime.parse(t['created_at']) : null;
        if (createdAt == null) return false;

        return createdAt.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
               createdAt.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }

      return true;
    }).toList();

    sortTickets();
  }

  void sortTickets() {
    filteredTickets.sort((a, b) {
      final dateA = a['created_at'] != null ? DateTime.parse(a['created_at']) : DateTime.now();
      final dateB = b['created_at'] != null ? DateTime.parse(b['created_at']) : DateTime.now();
      return sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });
  }

  void filterTickets(String value) {
    setState(() {
      search = value;
      applyFilters();
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange,
      locale: const Locale('es'),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        applyFilters();
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDateRange = null;
      applyFilters();
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
                // Filtro de fecha
                if (_selectedDateRange != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Chip(
                      avatar: Icon(
                        Icons.date_range,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      label: Text(
                        '${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                      onDeleted: _clearDateFilter,
                      backgroundColor: colorScheme.primaryContainer,
                    ),
                  ),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_selectedDateRange == null ? 'Filtrar por fecha' : 'Cambiar fecha'),
                    ),
                    const Spacer(),
                    Text(
                      '${filteredTickets.length} ${filteredTickets.length == 1 ? 'ticket' : 'tickets'}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
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
                                    Icons.search_off,
                                    size: 64,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    search.isNotEmpty || _selectedDateRange != null
                                        ? 'No se encontraron tickets'
                                        : 'No hay tickets registrados',
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
                                final createdAt = t['created_at'] != null ? DateTime.parse(t['created_at']) : null;
                                final hora = createdAt != null ? DateFormat('HH:mm').format(createdAt) : '-';
                                final fecha = createdAt != null ? DateFormat('dd/MM/yyyy').format(createdAt) : '-';

                                final clienteData = t['cliente'];
                                final nombreCliente = clienteData?['nombrecliente'] ?? '';
                                final apellidoCliente = clienteData?['apellidocliente'] ?? '';
                                final cliente = nombreCliente.isNotEmpty
                                    ? (apellidoCliente.isNotEmpty ? '$nombreCliente $apellidoCliente' : nombreCliente)
                                    : '-';

                                final sesiones = t['sesiones'] as List<dynamic>? ?? [];

                                // Extraer tratamientos únicos
                                final Set<String> tratamientosNombres = {};
                                for (var sesion in sesiones) {
                                  final tratamiento = sesion['tratamiento'];
                                  if (tratamiento != null) {
                                    tratamientosNombres.add(tratamiento['nombretratamiento'] ?? '');
                                  }
                                }

                                final tratamientoTexto = tratamientosNombres.isEmpty
                                    ? 'Sin tratamientos'
                                    : tratamientosNombres.length == 1
                                        ? tratamientosNombres.first
                                        : '${tratamientosNombres.length} tratamientos';

                                final saldoPendiente = (t['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;
                                final tieneSaldo = saldoPendiente > 0;

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

