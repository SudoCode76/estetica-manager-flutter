import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:app_estetica/providers/ticket_provider.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/models/agenda_item.dart';

class SesionesScreen extends StatefulWidget {
  const SesionesScreen({Key? key}) : super(key: key);

  @override
  State<SesionesScreen> createState() => _SesionesScreenState();
}

class _SesionesScreenState extends State<SesionesScreen> with SingleTickerProviderStateMixin {
  // Usamos un rango por defecto: hoy - hoy
  DateTimeRange _selectedRange = DateTimeRange(start: DateTime.now(), end: DateTime.now());
  SucursalProvider? _sucursalProvider;
  late TabController _tabController;
  String _filtroEstado = 'agendada'; // 'agendada' o 'realizada'
  bool _isFirstLoad = true; // Bandera para controlar primera carga

  // --- NUEVO: buscador de sesiones por nombre de cliente ---
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  Timer? _debounceSearch;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initializeLocale();

    // Inicializar listener del buscador (opcional)
    // No añadimos listener directo; usaremos onChanged con debounce

    // CARGA AUTOMÁTICA: cargar la agenda tan pronto como termine el primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAgenda();
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _filtroEstado = _tabController.index == 0 ? 'agendada' : 'realizada';
      });
      _loadAgenda();
    }
  }

  Future<void> _initializeLocale() async {
    try {
      await initializeDateFormatting('es_ES', null);
    } catch (e) {
      print('Error inicializando locale: $e');
      // Continuar de todos modos
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = SucursalInherited.of(context);
    final providerChanged = provider != _sucursalProvider;

    if (providerChanged) {
      _sucursalProvider?.removeListener(_onSucursalChanged);
      _sucursalProvider = provider;
      _sucursalProvider?.addListener(_onSucursalChanged);
    }

    // Cargar agenda en primera vez o cuando cambia el provider
    if ((_isFirstLoad || providerChanged)) {
      _isFirstLoad = false;
      // Usar addPostFrameCallback para evitar llamar durante el build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadAgenda();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sucursalProvider?.removeListener(_onSucursalChanged);
    // --- NUEVO: limpiar buscador ---
    _searchController.dispose();
    _debounceSearch?.cancel();
    super.dispose();
  }

  void _onSucursalChanged() {
    _loadAgenda();
  }

  Future<void> _loadAgenda() async {
    final sucursalId = _sucursalProvider?.selectedSucursalId;

    // Verificar que hay sucursal seleccionada
    if (sucursalId == null) {
      print('SesionesScreen: No hay sucursal seleccionada, no se puede cargar agenda');
      if (mounted) {
        setState(() {
          // El provider manejará el estado de error
        });
      }
      return;
    }

    print('SesionesScreen: Loading agenda for range=${_selectedRange.start} -> ${_selectedRange.end} and sucursal=$sucursalId, estado=$_filtroEstado');

    // Usar fetchAgendaRango para soportar rango de fechas (inicialmente hoy)
    await context.read<TicketProvider>().fetchAgendaRango(
      start: _selectedRange.start,
      end: _selectedRange.end,
      sucursalId: sucursalId,
      estadoSesion: _filtroEstado,
    );
  }

  // Selector de rango
  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _selectedRange,
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        // Asegurar que el DateRangePicker tenga MaterialLocalizations disponibles
        return Localizations.override(
          context: context,
          locale: const Locale('es', 'ES'),
          delegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Theme.of(context).colorScheme.primary,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedRange = picked;
      });
      _loadAgenda();
    }
  }

  String _getRangoTexto() {
    final start = DateFormat('d MMM', 'es_ES').format(_selectedRange.start);
    final end = DateFormat('d MMM', 'es_ES').format(_selectedRange.end);

    if (_selectedRange.start.day == _selectedRange.end.day && _selectedRange.start.month == _selectedRange.end.month && _selectedRange.start.year == _selectedRange.end.year) {
      return DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(_selectedRange.start);
    }
    return '$start - $end';
  }

  // --- NUEVAS FUNCIONES UTIL: normalizar texto y filtrar agenda ---
  String _normalize(String s) {
    var str = s.toLowerCase();
    const accents = {
      '\u00e1':'a','\u00e0':'a','\u00e4':'a','\u00e2':'a','\u00e3':'a',
      '\u00e9':'e','\u00e8':'e','\u00eb':'e','\u00ea':'e',
      '\u00ed':'i','\u00ec':'i','\u00ef':'i','\u00ee':'i',
      '\u00f3':'o','\u00f2':'o','\u00f6':'o','\u00f4':'o','\u00f5':'o',
      '\u00fa':'u','\u00f9':'u','\u00fc':'u','\u00fb':'u','\u00f1':'n','\u00e7':'c'
    };
    accents.forEach((k,v) { str = str.replaceAll(k, v); });
    str = str.replaceAll(RegExp(r"[^a-z0-9\s]"), ' ');
    return str.replaceAll(RegExp(r"\s+"), ' ').trim();
  }

  void _onSearchChanged(String value) {
    // Actualizar inmediatamente el término de búsqueda para filtrar localmente
    if (!mounted) return;
    setState(() {
      _search = value;
    });

    // Si la búsqueda quedó vacía, cancelar debounce y devolver
    if (value.trim().isEmpty) {
      if (_debounceSearch?.isActive ?? false) _debounceSearch!.cancel();
      print('Sesiones: búsqueda vacía, mostrando todas las sesiones');
      return;
    }

    // Debounce para tareas pesadas / servidor (aquí sólo usamos para log)
    if (_debounceSearch?.isActive ?? false) _debounceSearch!.cancel();
    _debounceSearch = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      // en futuras mejoras aquí se podría lanzar búsqueda en servidor
      print('Sesiones: debounce exec -> "${_search}"');
    });
  }

  List<dynamic> _computeFilteredAgenda(List<dynamic> agenda) {
    try {
      if (_search.trim().isEmpty) return agenda;
      final term = _normalize(_search);
      final filtered = <dynamic>[];

      String _extractNombreCliente(dynamic item) {
        try {
          if (item == null) return '';
          // Si ya es AgendaItem
          if (item is AgendaItem) return item.nombreCliente;

          final Map<String, dynamic> j = item is Map ? Map<String, dynamic>.from(item) : {};

          // 1. revisar si existe clave 'cliente' y puede ser Map/List o contener 'data'
          final cliente = j['cliente'] ?? j['cliente_id'] ?? j['clienteData'] ?? j['cliente_id'];
          if (cliente != null) {
            if (cliente is Map) {
              // soporte caso cliente: { data: {...} }
              final data = cliente['data'] ?? cliente;
              if (data is Map) {
                final nombre = (data['nombrecliente'] ?? data['nombreCliente'] ?? data['nombre'] ?? '').toString();
                final apellido = (data['apellidocliente'] ?? data['apellidoCliente'] ?? data['apellido'] ?? '').toString();
                final full = ('$nombre $apellido').trim();
                if (full.isNotEmpty) return full;
              }
              // si cliente es mapa plano
              final nombre2 = (cliente['nombrecliente'] ?? cliente['nombreCliente'] ?? cliente['nombre'] ?? '').toString();
              final apellido2 = (cliente['apellidocliente'] ?? cliente['apellidoCliente'] ?? cliente['apellido'] ?? '').toString();
              final full2 = ('$nombre2 $apellido2').trim();
              if (full2.isNotEmpty) return full2;
            } else if (cliente is List && cliente.isNotEmpty) {
              final c0 = cliente.first;
              if (c0 is Map) {
                final nombre = (c0['nombrecliente'] ?? c0['nombreCliente'] ?? c0['nombre'] ?? '').toString();
                final apellido = (c0['apellidocliente'] ?? c0['apellidoCliente'] ?? c0['apellido'] ?? '').toString();
                final full = ('$nombre $apellido').trim();
                if (full.isNotEmpty) return full;
              }
            }
          }

          // 2. revisar campos planos en el mismo objeto
          final nombrePlain = (j['nombrecliente'] ?? j['nombre_cliente'] ?? j['nombreCliente'] ?? j['nombre'] ?? '').toString();
          final apellidoPlain = (j['apellidocliente'] ?? j['apellidoCliente'] ?? j['apellido'] ?? '').toString();
          final fullPlain = ('$nombrePlain $apellidoPlain').trim();
          if (fullPlain.isNotEmpty) return fullPlain;

          // 3. intentar en sesiones[0].cliente o sesiones[0].cliente.data
          final sesiones = j['sesiones'] ?? j['sesion'] ?? j['session'];
          if (sesiones is List && sesiones.isNotEmpty) {
            final s0 = sesiones.first;
            if (s0 is Map) {
              final c = s0['cliente'] ?? s0['cliente_id'];
              if (c is Map) {
                final nombre = (c['nombrecliente'] ?? c['nombreCliente'] ?? c['nombre'] ?? '').toString();
                final apellido = (c['apellidocliente'] ?? c['apellidoCliente'] ?? c['apellido'] ?? '').toString();
                final full = ('$nombre $apellido').trim();
                if (full.isNotEmpty) return full;
              }
            }
          }

          return '';
        } catch (_) {
          return '';
        }
      }

      for (final item in agenda) {
        try {
          final nombre = _extractNombreCliente(item);
          if (nombre.isNotEmpty && _normalize(nombre).contains(term)) {
            filtered.add(item);
            continue;
          }
          // fallback: si el item contiene un campo 'cliente' como texto
          try {
            final possible = (item['cliente'] is String) ? item['cliente'] : '';
            if (possible != null && _normalize(possible.toString()).contains(term)) {
              filtered.add(item);
              continue;
            }
          } catch (_) {}
        } catch (_) {}
      }
      // debug
      print('Sesiones: filtro="$term" -> ${filtered.length}/${agenda.length} coincidencias');
      return filtered;
    } catch (e) {
      return agenda;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(

      body: Column(
        children: [
          // Selector de rango compacto
          InkWell(
            onTap: _selectDateRange,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.primaryContainer.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.event,
                      color: colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Periodo visualizado',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _getRangoTexto(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit, size: 18),
                ],
              ),
            ),
          ),

          // Tabs para filtrar por estado
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: colorScheme.onPrimary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Agendadas'),
                Tab(text: 'Realizadas'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // NUEVO: Buscador por nombre de cliente
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Buscar por cliente',
              leading: const Icon(Icons.search),
              trailing: _search.isNotEmpty
                  ? [
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                    ]
                  : null,
              onChanged: _onSearchChanged,
              elevation: const WidgetStatePropertyAll(1),
            ),
          ),
          const SizedBox(height: 12),

          // Lista de sesiones
          Expanded(
            child: Consumer<TicketProvider>(
              builder: (context, provider, _) {
                if (provider.isLoadingAgenda) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Mostrar contador de sesiones cargadas
                final displayed = _computeFilteredAgenda(provider.agenda);
                final count = displayed.length;

                if (provider.error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 56, color: colorScheme.error),
                          const SizedBox(height: 16),
                          Text(
                            'Error al cargar agenda',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${provider.error}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _loadAgenda,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (provider.agenda.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _filtroEstado == 'agendada' ? Icons.event_note : Icons.check_circle_outline,
                          size: 72,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _filtroEstado == 'agendada'
                              ? 'No hay sesiones agendadas'
                              : 'No hay sesiones realizadas',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No hay citas para este período',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _loadAgenda,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Actualizar'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Text('$count sesiones', style: theme.textTheme.labelLarge),
                          const Spacer(),
                          Text(_getRangoTexto(), style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadAgenda,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                          itemCount: displayed.length,
                          itemBuilder: (context, index) {
                            final sesion = AgendaItem.fromJson(displayed[index]);
                            return _SesionCard(
                              sesion: sesion,
                              // Mostrar acciones (reprogramar/atendida) sólo si estamos en la pestaña 'agendada'
                              showActions: _filtroEstado == 'agendada',
                              onMarcarAtendida: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Marcar como atendida'),
                                    content: Text('¿Confirmar que la sesión de ${sesion.nombreCliente} fue atendida?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Confirmar'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true) {
                                  final success = await provider.marcarSesionAtendida(sesion.sesionId);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success ? 'Sesión marcada como atendida' : 'Error al marcar sesión'),
                                        backgroundColor: success ? Colors.green : Colors.red,
                                      ),
                                    );
                                    // Si la operación fue exitosa, recargar la agenda para reflejar el cambio
                                    if (success) {
                                      _loadAgenda();
                                    }
                                  }
                                }
                              },
                              onReprogramar: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: sesion.fechaHora ?? DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2030),
                                  locale: const Locale('es', 'ES'),
                                );

                                if (picked != null) {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(sesion.fechaHora ?? DateTime.now()),
                                  );

                                  if (time != null) {
                                    final nuevaFecha = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      time.hour,
                                      time.minute,
                                    );

                                    final success = await provider.reprogramarSesion(sesion.sesionId, nuevaFecha);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(success ? 'Sesión reprogramada' : 'Error al reprogramar'),
                                          backgroundColor: success ? Colors.green : Colors.red,
                                        ),
                                      );
                                      if (success) {
                                        _loadAgenda();
                                      }
                                    }
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SesionCard extends StatelessWidget {
  final AgendaItem sesion;
  final VoidCallback onMarcarAtendida;
  final VoidCallback onReprogramar;
  final bool showActions;

  const _SesionCard({
    Key? key,
    required this.sesion,
    required this.onMarcarAtendida,
    required this.onReprogramar,
    this.showActions = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tieneDeuda = sesion.saldoPendiente > 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Aquí podrías navegar al detalle del ticket si lo deseas
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con hora y estado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          sesion.fechaHora != null
                              ? DateFormat('HH:mm').format(sesion.fechaHora!)
                              : 'Sin hora',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (tieneDeuda)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber, size: 16, color: colorScheme.error),
                          const SizedBox(width: 4),
                          Text(
                            'Debe Bs ${sesion.saldoPendiente.toStringAsFixed(2)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Sesión ${sesion.numeroSesion}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Cliente
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      sesion.nombreCliente.isNotEmpty ? sesion.nombreCliente[0].toUpperCase() : '?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sesion.nombreCliente,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sesion.nombreTratamiento,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Acciones
              if (showActions) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReprogramar,
                        icon: const Icon(Icons.schedule, size: 18),
                        label: const Text('Reprogramar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onMarcarAtendida,
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Atendida'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
