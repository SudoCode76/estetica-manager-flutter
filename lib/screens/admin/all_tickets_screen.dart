import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:app_estetica/screens/admin/ticket_detail_screen.dart';
import 'package:app_estetica/repositories/ticket_repository.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:provider/provider.dart';

class AllTicketsScreen extends StatefulWidget {
  const AllTicketsScreen({super.key});

  @override
  State<AllTicketsScreen> createState() => _AllTicketsScreenState();
}

class _AllTicketsScreenState extends State<AllTicketsScreen> {
  late TicketRepository api;
  final TextEditingController _searchController = TextEditingController();

  // Datos
  List<dynamic> tickets = [];        // Datos recibidos (página actual o lista completa)
  List<dynamic> filteredTickets = []; // Lista para mostrar cuando no hay búsqueda

  bool isLoading = true;
  String search = '';
  String? errorMsg;
  bool sortAscending = false;
  SucursalProvider? _sucursalProvider;
  Timer? _debounce; // Timer para debounce del buscador

  // PAGINACIÓN para searchTickets
  int _page = 1;
  int _pageSize = 20;
  int _totalPages = 1;
  int _totalItems = 0;

  // Rango de fechas (Inicializado en HOY)
  DateTimeRange? _selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  final List<int> _pageSizeOptions = [10, 20, 50, 100];

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
      // obtener repo inyectado
      api = Provider.of<TicketRepository>(context, listen: false);
      _page = 1;
      fetchTickets();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _sucursalProvider?.removeListener(_onSucursalChanged);
    super.dispose();
  }

  void _onSucursalChanged() {
    _page = 1;
    fetchTickets();
  }

  Future<void> fetchTickets() async {
    if (_sucursalProvider?.selectedSucursalId == null) return;

    if (mounted) {
      setState(() {
        isLoading = true;
        errorMsg = null;
      });
    }

    try {
      final sucursalId = _sucursalProvider!.selectedSucursalId!;
      List<dynamic> data = [];

      // Si hay texto en el buscador, usar searchTickets (server-side) con paginación
      if (search.trim().isNotEmpty) {
        final resp = await api.searchTickets(query: search.trim(), sucursalId: sucursalId, page: _page, pageSize: _pageSize).timeout(const Duration(seconds: 8));
        data = resp['items'] as List<dynamic>;
        final meta = resp['meta'] as Map<String, dynamic>? ?? {};
        _totalItems = (meta['total'] is int) ? meta['total'] as int : int.tryParse('${meta['total']}') ?? 0;
        _totalPages = (meta['totalPages'] is int) ? meta['totalPages'] as int : ( (_totalItems / _pageSize).ceil() );
      } else if (_selectedDateRange != null) {
        data = await api.getTicketsByRange(start: _selectedDateRange!.start, end: _selectedDateRange!.end, sucursalId: sucursalId).timeout(const Duration(seconds: 8));
        // Reseteamos paginación local cuando no hay búsqueda
        _totalItems = data.length;
        _totalPages = 1;
        _page = 1;
      } else {
        data = await api.getAllTickets(sucursalId: sucursalId).timeout(const Duration(seconds: 8));
        _totalItems = data.length;
        _totalPages = 1;
        _page = 1;
      }

      if (mounted) {
        setState(() {
          tickets = data;
          isLoading = false;
          filteredTickets = data; // cuando no hay búsqueda, mostramos toda la lista local
        });
      }
    } catch (e) {
      final msg = (e is TimeoutException) ? 'Timeout al cargar tickets (verifica conexión)' : e.toString();
      if (mounted) {
        setState(() {
          errorMsg = 'Error al cargar: $msg';
          isLoading = false;
        });
      }
    }
  }

  // Helper: normaliza texto para búsqueda (minusculas y sin acentos)
  String _normalize(String input) {
    var s = input.toLowerCase();
    const accents = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c'
    };
    accents.forEach((k, v) {
      s = s.replaceAll(k, v);
    });
    s = s.replaceAll(RegExp(r"[^a-z0-9\s]"), ' ');
    s = s.replaceAll(RegExp(r"\s+"), ' ').trim();
    return s;
  }

  void sortTickets() {
    final list = search.trim().isNotEmpty ? tickets : filteredTickets;
    list.sort((a, b) {
      final dateA = a['created_at'] != null ? DateTime.parse(a['created_at']) : DateTime.now();
      final dateB = b['created_at'] != null ? DateTime.parse(b['created_at']) : DateTime.now();
      return sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });
    setState(() {});
  }

  void _onSearchChanged(String value) {
    setState(() {
      search = value;
      _page = 1; // reset page when query changes
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      fetchTickets();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
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
        if (search.isNotEmpty) {
          search = '';
          _searchController.clear();
        }
        _page = 1;
      });
      fetchTickets();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDateRange = null;
      _page = 1;
    });
    fetchTickets();
  }

  Future<void> _deleteTicket(String id) async {
    try {
      final success = await api.eliminarTicket(id);
      if (success) {
        setState(() {
          tickets.removeWhere((t) => t['id'].toString() == id);
          filteredTickets.removeWhere((t) => t['id'].toString() == id);
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eliminado'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) fetchTickets();
    }
  }

  // PAGINACION: siguiente pagina
  void _nextPage() {
    if (_page < _totalPages) {
      setState(() {
        _page++;
      });
      fetchTickets();
    }
  }

  // PAGINACION: pagina anterior
  void _prevPage() {
    if (_page > 1) {
      setState(() {
        _page--;
      });
      fetchTickets();
    }
  }

  // Permite saltar a una pagina concreta
  void _goToPage(int p) {
    if (p < 1 || p > _totalPages) return;
    setState(() {
      _page = p;
    });
    fetchTickets();
  }

  void _changePageSize(int newSize) {
    setState(() {
      _pageSize = newSize;
      _page = 1;
    });
    fetchTickets();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final displayList = search.trim().isNotEmpty ? tickets : filteredTickets;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Histórico de Tickets'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Buscar en todo el historial...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: search.isNotEmpty
                                ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch)
                                : null,
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withAlpha((0.5 * 255).round()),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () {
                          setState(() {
                            sortAscending = !sortAscending;
                            sortTickets();
                          });
                        },
                        icon: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: search.isNotEmpty ? null : _selectDateRange,
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: Text(
                            search.isNotEmpty
                              ? 'Buscando en todo el historial...'
                              : (_selectedDateRange == null
                                  ? 'Ver todo el historial'
                                  : '${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}'),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                        ),
                      ),
                      if (_selectedDateRange != null && search.isEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.close),
                          onPressed: _clearDateFilter,
                        )
                      ]
                    ],
                  ),
                ],
              ),
            ),

            // PAGINATOR UI: mostrar solo cuando search tiene texto (usando server-side pagination)
            if (search.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _page > 1 ? _prevPage : null,
                          icon: const Icon(Icons.arrow_back_ios_new),
                          tooltip: 'Página anterior',
                        ),
                        Text('Página $_page de $_totalPages ($_totalItems)'),
                        IconButton(
                          onPressed: _page < _totalPages ? _nextPage : null,
                          icon: const Icon(Icons.arrow_forward_ios),
                          tooltip: 'Siguiente página',
                        ),
                      ],
                    ),

                    // Selector de pageSize
                    Row(
                      children: [
                        const Text('Por página: '),
                        DropdownButton<int>(
                          value: _pageSize,
                          items: _pageSizeOptions.map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                          onChanged: (v) { if (v != null) _changePageSize(v); },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                  : errorMsg != null
                      ? Center(child: Text(errorMsg!, style: TextStyle(color: colorScheme.error)))
                      : displayList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text('No se encontraron tickets', style: textTheme.bodyLarge),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: displayList.length,
                              itemBuilder: (context, i) {
                                final t = displayList[i];
                                final createdAt = t['created_at'] != null ? DateTime.parse(t['created_at']) : null;
                                final hora = createdAt != null ? DateFormat('HH:mm').format(createdAt) : '-';
                                final fecha = createdAt != null ? DateFormat('dd/MM/yy').format(createdAt) : '-';

                                final clienteData = t['cliente'];
                                final nombreCliente = clienteData?['nombrecliente'] ?? '';
                                final apellidoCliente = clienteData?['apellidocliente'] ?? '';
                                final cliente = nombreCliente.isNotEmpty
                                    ? '$nombreCliente $apellidoCliente'
                                    : 'Cliente sin nombre';

                                final sesiones = t['sesiones'] as List<dynamic>? ?? [];
                                final tratamientoTexto = sesiones.isNotEmpty
                                    ? (sesiones.first['tratamiento']?['nombretratamiento'] ?? 'Tratamiento')
                                    : 'Sin tratamientos';
                                final countExtra = sesiones.length > 1 ? ' (+${sesiones.length - 1})' : '';
                                final saldo = (t['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;

                                return Dismissible(
                                  key: Key(t['id'].toString()),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  confirmDismiss: (d) async {
                                    _deleteTicket(t['id'].toString());
                                    return false;
                                  },
                                  child: Card(
                                    elevation: 0,
                                    color: colorScheme.surfaceContainerHighest.withAlpha((0.4 * 255).round()),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: t)),
                                        );
                                        // Si estamos en búsqueda, mantener la página actual; si no, recargar
                                        if (search.trim().isEmpty) fetchTickets();
                                      },
                                      leading: CircleAvatar(
                                        child: Text(cliente.isNotEmpty ? cliente[0].toUpperCase() : '?'),
                                      ),
                                      title: Text(cliente, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('$tratamientoTexto$countExtra\n$fecha • $hora'),
                                      trailing: saldo > 0
                                        ? Text('Debe Bs $saldo', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))
                                        : const Icon(Icons.chevron_right),
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

