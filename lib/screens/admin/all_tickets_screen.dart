import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:app_estetica/screens/admin/ticket_detail_screen.dart';
import 'package:app_estetica/services/api_service.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllTicketsScreen extends StatefulWidget {
  const AllTicketsScreen({super.key});

  @override
  State<AllTicketsScreen> createState() => _AllTicketsScreenState();
}

class _AllTicketsScreenState extends State<AllTicketsScreen> {
  final ApiService api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  // Datos
  List<dynamic> tickets = [];        // Todos los datos descargados
  List<dynamic> filteredTickets = []; // Datos que se ven en pantalla

  bool isLoading = true;
  String search = '';
  String? errorMsg;
  bool sortAscending = false;
  SucursalProvider? _sucursalProvider;
  Timer? _debounce; // Timer para debounce del buscador

  // Rango de fechas (Inicializado en HOY)
  DateTimeRange? _selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

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
    _debounce?.cancel();
    _sucursalProvider?.removeListener(_onSucursalChanged);
    super.dispose();
  }

  void _onSucursalChanged() {
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
      List<dynamic> data;

      // --- LOGICA MAESTRA DE CARGA ---
      // 1. Si hay búsqueda escrita, ignoramos fecha y traemos TODO el historial
      if (search.trim().isNotEmpty) {
        data = await api.getAllTickets(sucursalId: sucursalId);
      }
      // 2. Si no hay búsqueda, respetamos el RANGO DE FECHAS seleccionado
      else if (_selectedDateRange != null) {
        data = await api.getTicketsByRange(
          start: _selectedDateRange!.start,
          end: _selectedDateRange!.end,
          sucursalId: sucursalId,
        );
      }
      // 3. Si no hay ni búsqueda ni rango, traemos todo (fallback)
      else {
        data = await api.getAllTickets(sucursalId: sucursalId);
      }

      if (mounted) {
        setState(() {
          tickets = data;
          isLoading = false;
        });
        if (kDebugMode) print('AllTicketsScreen.fetchTickets: search="$search", fetched=${tickets.length}');
        applyFilters();

        // FALLBACK: si hay búsqueda y no hubo coincidencias, intentar buscar por clientes en el servidor
        if (search.trim().isNotEmpty && (filteredTickets.isEmpty)) {
          if (kDebugMode) print('AllTicketsScreen: no matches locally, attempting server-side client search for "$search"');
          try {
            final clients = await api.getClientes(sucursalId: sucursalId, query: search.trim());
            final clientIds = <dynamic>[];
            for (var c in clients) {
              if (c == null) continue;
              // c puede venir como Map con 'id' o 'cliente_id'
              final id = c['id'] ?? c['cliente_id'] ?? c['user_id'];
              if (id != null) clientIds.add(id);
            }
            if (clientIds.isNotEmpty) {
              if (kDebugMode) print('AllTicketsScreen: found ${clientIds.length} matching clients; fetching tickets for them');
              final quoted = clientIds.map((e) => "'${e.toString()}'").join(',');
              final resp = await Supabase.instance.client
                  .from('ticket')
                  .select('''
                    *, cliente:cliente_id(nombrecliente,apellidocliente,telefono),
                    sesiones:sesion(id,numero_sesion,fecha_hora_inicio,estado_sesion,tratamiento:tratamiento_id(id,nombretratamiento,precio))
                  ''')
                  .filter('cliente_id', 'in', '($quoted)')
                  .order('created_at', ascending: false);
              final listResp = resp as List<dynamic>;
              if (listResp.isNotEmpty) {
                setState(() {
                  tickets = listResp;
                });
                applyFilters();
                if (kDebugMode) print('AllTicketsScreen: server-side client search produced ${listResp.length} tickets');
              }
            }
          } catch (e) {
            if (kDebugMode) print('AllTicketsScreen: server-side client search failed: $e');
          }
        }
      }
    } catch (e) {
      print('Error fetching tickets: $e');
      if (mounted) {
        setState(() {
          errorMsg = 'Error al cargar: $e';
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
    // eliminar caracteres no alfanumericos para comparaciones más tolerantes
    s = s.replaceAll(RegExp(r"[^a-z0-9\s]"), ' ');
    s = s.replaceAll(RegExp(r"\s+"), ' ').trim();
    return s;
  }

  // Construye una cadena con los campos relevantes del ticket para búsqueda
  String _buildSearchableString(dynamic t) {
    final buf = StringBuffer();

    try {
      final cliente = t['cliente'] ?? t['cliente_id'];
      if (cliente != null) {
        if (cliente is List && cliente.isNotEmpty) {
          final c = cliente.first;
          if (c is Map) {
            buf.write(' ');
            buf.write((c['nombrecliente'] ?? ''));
            buf.write(' ');
            buf.write((c['apellidocliente'] ?? ''));
            buf.write(' ');
            buf.write((c['email'] ?? ''));
            buf.write(' ');
            buf.write((c['telefono'] ?? ''));
            buf.write(' ');
            buf.write((c['username'] ?? ''));
          }
        } else if (cliente is Map) {
          buf.write(' ');
          buf.write((cliente['nombrecliente'] ?? ''));
          buf.write(' ');
          buf.write((cliente['apellidocliente'] ?? ''));
          buf.write(' ');
          buf.write((cliente['email'] ?? ''));
          buf.write(' ');
          buf.write((cliente['telefono'] ?? ''));
          // soportar posibles claves camelCase y username
          buf.write(' ');
          buf.write((cliente['nombreCliente'] ?? ''));
          buf.write(' ');
          buf.write((cliente['apellidoCliente'] ?? ''));
          buf.write(' ');
          buf.write((cliente['username'] ?? ''));
        } else if (cliente is String) {
          buf.write(' ');
          buf.write(cliente);
        }
      }

      // sesiones y tratamientos
      final sesiones = t['sesiones'] as List<dynamic>? ?? [];
      for (var s in sesiones) {
        if (s == null) continue;
        // tratamiento puede estar anidado o en listas
        var trat = s['tratamiento'] ?? s['tratamiento_id'] ?? s['tratamiento_id'];
        if (trat is List && trat.isNotEmpty) trat = trat.first;
        if (trat is Map) {
          buf.write(' ');
          buf.write(trat['nombretratamiento'] ?? trat['nombreTratamiento'] ?? trat['nombre'] ?? '');
        } else if (s['nombretratamiento'] != null) {
          buf.write(' ');
          buf.write(s['nombretratamiento']);
        }
         // numero_sesion
         buf.write(' ');
         buf.write(s['numero_sesion']?.toString() ?? '');
       }

      // Otros campos que puedan ayudar
      buf.write(' ');
      buf.write(t['id']?.toString() ?? '');
      buf.write(' ');
      buf.write((t['monto_total'] ?? '').toString());
      buf.write(' ');
      buf.write((t['saldo_pendiente'] ?? '').toString());
    } catch (e) {
      // si algo falla, retornamos lo que tengamos
      print('Error building searchable string: $e');
    }

    return _normalize(buf.toString());
  }

  void applyFilters() {
    final term = _normalize(search);

    setState(() {
      filteredTickets = tickets.where((t) {
        if (term.isEmpty) return true;

        final hay = _buildSearchableString(t);
        return hay.contains(term);
      }).toList();

      sortTickets();
      if (kDebugMode) print('AllTicketsScreen.applyFilters: term="$term", tickets=${tickets.length}, filtered=${filteredTickets.length}');
    });
  }

  void sortTickets() {
    filteredTickets.sort((a, b) {
      final dateA = a['created_at'] != null ? DateTime.parse(a['created_at']) : DateTime.now();
      final dateB = b['created_at'] != null ? DateTime.parse(b['created_at']) : DateTime.now();
      return sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      search = value;
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
      });
      fetchTickets();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDateRange = null;
    });
    fetchTickets();
  }

  Future<void> _deleteTicket(String id) async {
    try {
      final success = await api.eliminarTicket(id);
      if (success) {
        setState(() {
          tickets.removeWhere((t) => t['id'].toString() == id);
          applyFilters();
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eliminado'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) fetchTickets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                  : errorMsg != null
                      ? Center(child: Text(errorMsg!, style: TextStyle(color: colorScheme.error)))
                      : filteredTickets.isEmpty
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
                              itemCount: filteredTickets.length,
                              itemBuilder: (context, i) {
                                final t = filteredTickets[i];
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

