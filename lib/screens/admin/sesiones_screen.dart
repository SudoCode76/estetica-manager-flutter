import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
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
  DateTime _selectedDate = DateTime.now();
  SucursalProvider? _sucursalProvider;
  bool _localeInitialized = false;
  late TabController _tabController;
  String _filtroEstado = 'agendada'; // 'agendada' o 'realizada'
  bool _isFirstLoad = true; // Bandera para controlar primera carga

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initializeLocale();
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
      if (mounted) {
        setState(() {
          _localeInitialized = true;
        });
      }
    } catch (e) {
      print('Error inicializando locale: $e');
      if (mounted) {
        setState(() {
          _localeInitialized = true; // Continuar de todos modos
        });
      }
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
    if ((_isFirstLoad || providerChanged) && _localeInitialized) {
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

    print('SesionesScreen: Loading agenda for date=${_selectedDate.toString()} and sucursal=$sucursalId, estado=$_filtroEstado');

    await context.read<TicketProvider>().fetchAgenda(
      _selectedDate,
      sucursalId: sucursalId,
      estadoSesion: _filtroEstado, // Pasar estado para filtrar en la query
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('es', 'ES'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadAgenda();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de Sesiones'),
        elevation: 0,
        surfaceTintColor: colorScheme.surfaceTint,
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: 'Cambiar fecha',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAgenda,
            tooltip: 'Actualizar',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Selector de fecha compacto
          Container(
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
                        'Fecha seleccionada',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Cambiar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
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

          // Lista de sesiones
          Expanded(
            child: Consumer<TicketProvider>(
              builder: (context, provider, _) {
                if (provider.isLoadingAgenda) {
                  return const Center(child: CircularProgressIndicator());
                }

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
                          'No hay citas para esta fecha',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadAgenda,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    itemCount: provider.agenda.length,
                    itemBuilder: (context, index) {
                      final sesion = AgendaItem.fromJson(provider.agenda[index]);
                      return _SesionCard(
                        sesion: sesion,
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
                              }
                            }
                          }
                        },
                      );
                    },
                  ),
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

  const _SesionCard({
    Key? key,
    required this.sesion,
    required this.onMarcarAtendida,
    required this.onReprogramar,
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
          ),
        ),
      ),
    );
  }
}
