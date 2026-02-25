import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:app_estetica/repositories/catalog_repository.dart';
import 'package:app_estetica/repositories/cliente_repository.dart';
import 'package:app_estetica/repositories/auth_repository.dart';
import 'package:app_estetica/repositories/ticket_repository.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/screens/admin/clients/select_client_screen.dart';
import 'package:app_estetica/widgets/create_client_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:app_estetica/providers/ticket_provider.dart';
import 'package:app_estetica/config/responsive.dart';
import 'package:app_estetica/widgets/payment_method_selector.dart';
import 'package:app_estetica/widgets/rounded_card.dart';
import 'package:google_fonts/google_fonts.dart';

class NewTicketScreen extends StatefulWidget {
  final String? currentUserId;
  const NewTicketScreen({super.key, this.currentUserId});

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  late CatalogRepository _catalogRepo;
  late ClienteRepository _clienteRepo;
  late AuthRepository _authRepo;
  late TicketRepository _ticketRepo;
  bool _initialDataLoaded = false;
  DateTime? fecha;
  List<int> tratamientosSeleccionados = [];
  Map<int, int> cantidadSesionesPorTratamiento =
      {}; // cantidad de sesiones por tratamiento
  Map<int, List<DateTime>> cronogramaSesionesPorTratamiento =
      {}; // NUEVO: fechas de cada sesión
  int? clienteId;
  String? clienteNombre;
  int? usuarioId;
  String? usuarioNombre;
  // Metodo de pago seleccionado por defecto
  String _metodoPagoSeleccionado = 'efectivo';
  double? cuota;
  double? pago;
  double saldoPendiente = 0;
  String estadoPago = 'Incompleto';
  bool estadoTicket = false; // Nuevo ticket por defecto: no atendido

  List<dynamic> tratamientos = [];
  List<dynamic> categorias = [];
  // Filtro para la nueva UI de tratamientos
  int? _selectedCategoriaFilter;
  final TextEditingController _tratamientoSearchCtrl = TextEditingController();
  String _tratamientoSearch = '';
  Timer? _tratamientoSearchDebounce;
  List<dynamic> clientes = [];
  List<dynamic> usuarios = [];
  bool isLoading = true;
  bool isLoadingUsuarios = false;
  bool isLoadingUserType =
      true; // NUEVO: controla si se ha determinado el tipo de usuario
  String? error; // Error de carga de datos (muestra pantalla completa de error)
  String?
  validationError; // Error de validación/creación (se muestra inline en el formulario)
  bool _isSubmitting =
      false; // Flag para evitar envíos múltiples y mostrar loader

  // Variable para tipo de usuario
  bool _isEmployee = false;

  SucursalProvider? _sucursalProvider;
  Timer? _clientSearchDebounce;

  @override
  void initState() {
    super.initState();
    // IMPORTANTE: Limpiar usuarioId al inicio para evitar valores obsoletos
    usuarioId = null;
    usuarioNombre = null;
    _loadUserType();
    // listener para el campo de búsqueda de tratamientos
    _tratamientoSearchCtrl.addListener(() {
      if (_tratamientoSearchDebounce?.isActive ?? false)
        _tratamientoSearchDebounce!.cancel();
      _tratamientoSearchDebounce = Timer(const Duration(milliseconds: 300), () {
        setState(() {
          _tratamientoSearch = _tratamientoSearchCtrl.text.trim();
        });
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = SucursalInherited.of(context);
    if (provider != _sucursalProvider) {
      _sucursalProvider?.removeListener(_onSucursalChanged);
      _sucursalProvider = provider;
      _sucursalProvider?.addListener(_onSucursalChanged);
      // Obtener repos inyectados
      _catalogRepo = Provider.of<CatalogRepository>(context, listen: false);
      _clienteRepo = Provider.of<ClienteRepository>(context, listen: false);
      _authRepo = Provider.of<AuthRepository>(context, listen: false);
      _ticketRepo = Provider.of<TicketRepository>(context, listen: false);
      _loadClientsForSucursal();
      _loadUsuariosForSucursal();
      // Cargar datos dependientes del catálogo (solo una vez cuando los repos estén disponibles)
      if (!_initialDataLoaded) {
        _initialDataLoaded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) cargarDatos();
        });
      }
    }
  }

  @override
  void dispose() {
    _clientSearchDebounce?.cancel();
    _tratamientoSearchDebounce?.cancel();
    _tratamientoSearchCtrl.dispose();
    _sucursalProvider?.removeListener(_onSucursalChanged);
    super.dispose();
  }

  Future<void> _loadUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString('userType');
      final userString = prefs.getString('user');

      final wasEmployee = _isEmployee;

      setState(() {
        _isEmployee = userType == 'empleado';
      });

      // Si es empleado, auto-seleccionar su ID
      if (_isEmployee && userString != null) {
        final userData = jsonDecode(userString);
        final userId = userData['id'];
        final username = userData['username'] ?? userData['email'] ?? 'Usuario';

        setState(() {
          usuarioId = userId;
          usuarioNombre = username;
        });
      } else {
        // Si NO es empleado, limpiar el usuarioId para evitar conflictos
        setState(() {
          usuarioId = null;
          usuarioNombre = null;
        });

        // Si cambió de empleado a admin, recargar lista de usuarios
        if (wasEmployee != _isEmployee) {
          _loadUsuariosForSucursal();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error cargando tipo de usuario: $e');
    } finally {
      // IMPORTANTE: marcar que ya se cargó el tipo de usuario
      setState(() {
        isLoadingUserType = false;
      });
    }
  }

  void _onSucursalChanged() {
    _loadClientsForSucursal();
    _loadUsuariosForSucursal();
  }

  int? _getCategoriaIdFromTratamiento(dynamic tratamiento) {
    // Intentar extraer el ID de categoría de diferentes campos posibles
    final possibleKeys = [
      'categoria_tratamiento',
      'categoria-tratamiento',
      'categoriaTratamiento',
      'categoria',
      'categoria_tratamientos',
      'categoriaTratamientos',
    ];

    for (final key in possibleKeys) {
      final catValue = tratamiento[key];
      if (catValue != null) {
        if (catValue is Map && catValue['id'] != null) {
          return catValue['id'] as int?;
        } else if (catValue is int) {
          return catValue;
        }
      }
    }
    return null;
  }

  void _ensureValidTicketCategoriaFilter() {
    if (_selectedCategoriaFilter == null) return;
    final exists = categorias.any((c) => c['id'] == _selectedCategoriaFilter);
    if (!exists) {
      _selectedCategoriaFilter = null;
    }
  }

  Future<void> cargarDatos() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      if (kDebugMode) debugPrint('NewTicketScreen: Cargando categorías...');
      List<dynamic> cats;
      try {
        cats = await _catalogRepo.getCategorias().timeout(
          const Duration(seconds: 8),
        );
      } on TimeoutException {
        throw Exception('Timeout al obtener categorías (verifica conexión)');
      }
      // Filtrar solo categorías activas (estadoCategoria == true o null->assume active)
      categorias = List<dynamic>.from(
        cats.where(
          (c) => c['estadoCategoria'] == true || c['estadoCategoria'] == null,
        ),
      );
      _ensureValidTicketCategoriaFilter();
      if (kDebugMode)
        debugPrint(
          'NewTicketScreen: ${categorias.length} categorías activas cargadas (de ${cats.length})',
        );

      if (kDebugMode) debugPrint('NewTicketScreen: Cargando tratamientos...');
      List<dynamic> tr;
      try {
        tr = await _catalogRepo.getTratamientos().timeout(
          const Duration(seconds: 8),
        );
      } on TimeoutException {
        throw Exception('Timeout al obtener tratamientos (verifica conexión)');
      }
      // Filtrar solo tratamientos activos
      tratamientos = List<dynamic>.from(
        tr.where(
          (t) =>
              t['estadoTratamiento'] == true || t['estadoTratamiento'] == null,
        ),
      );
      if (kDebugMode)
        debugPrint(
          'NewTicketScreen: ${tratamientos.length} tratamientos activos cargados (de ${tr.length})',
        );

      // no cargamos clientes ni usuarios aquí; se cargan por sucursal cuando el provider esté listo
    } catch (e) {
      if (kDebugMode) debugPrint('NewTicketScreen: Error al cargar datos: $e');
      error = 'Error al cargar datos: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadUsuariosForSucursal() async {
    setState(() {
      isLoadingUsuarios = true;
    });

    final sucId = _sucursalProvider?.selectedSucursalId;
    if (kDebugMode)
      debugPrint(
        'NewTicketScreen: _loadUsuariosForSucursal called with sucursalId=$sucId',
      );
    if (kDebugMode)
      debugPrint(
        'NewTicketScreen: Current usuarioId=$usuarioId, _isEmployee=$_isEmployee',
      );
    try {
      final data = await _authRepo.getUsuarios(sucursalId: sucId);
      if (kDebugMode)
        debugPrint('NewTicketScreen: Loaded ${data.length} usuarios');
      if (kDebugMode)
        debugPrint(
          'NewTicketScreen: Usuario IDs en lista: ${data.map((u) => u['id']).toList()}',
        );
      setState(() {
        usuarios = data;
        isLoadingUsuarios = false;
        // si el usuario seleccionado no pertenece a esta sucursal, limpiarlo
        if (usuarioId != null && !usuarios.any((u) => u['id'] == usuarioId)) {
          if (kDebugMode)
            debugPrint(
              'NewTicketScreen: ⚠️ Clearing usuarioId=$usuarioId (not in filtered list)',
            );
          usuarioId = null;
        } else if (usuarioId != null) {
          if (kDebugMode)
            debugPrint(
              'NewTicketScreen: ✓ usuarioId=$usuarioId está en la lista',
            );
        }
      });
    } catch (e) {
      final msg = e.toString();
      if (kDebugMode)
        debugPrint('NewTicketScreen: ❌ Error loading usuarios: $msg');
      setState(() {
        isLoadingUsuarios = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar usuarios: $msg')),
        );
      }
    }
  }

  Future<void> _loadClientsForSucursal({String? query}) async {
    if (_sucursalProvider?.selectedSucursalId == null) {
      setState(() {
        clientes = [];
      });
      return;
    }
    try {
      final data = await _clienteRepo.searchClientes(
        sucursalId: _sucursalProvider!.selectedSucursalId,
        query: query,
      );
      setState(() {
        clientes = data;
      });
    } catch (e) {
      final msg = e.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar clientes: $msg')));
    }
  }

  double calcularPrecioTotal() {
    double total = 0;
    for (var id in tratamientosSeleccionados) {
      final trat = tratamientos.firstWhere(
        (t) => t['id'] == id,
        orElse: () => null,
      );
      if (trat != null) {
        final precio = double.tryParse(trat['precio']?.toString() ?? '0') ?? 0;
        final cantidadSesiones = cantidadSesionesPorTratamiento[id] ?? 1;
        // Multiplicar precio por cantidad de sesiones
        total += precio * cantidadSesiones;
      }
    }
    return total;
  }

  void calcularEstadoPago() {
    final precioTotal = calcularPrecioTotal();
    if (pago != null) {
      cuota = precioTotal;
      saldoPendiente = cuota! - pago!;
      if (saldoPendiente <= 0) {
        estadoPago = 'Completo';
        saldoPendiente = 0;
      } else {
        estadoPago = 'Incompleto';
      }
    }
  }

  Future<void> _showCreateClientDialog() async {
    // Validar que haya sucursal seleccionada antes de abrir el diálogo
    if (_sucursalProvider?.selectedSucursalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona una sucursal en el menú lateral antes de continuar',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await CreateClientDialog.show(
      context,
      _sucursalProvider!.selectedSucursalId!,
    );

    if (result != null) {
      // Extraer el ID del cliente creado
      final createdId = result['id'] as int?;
      if (createdId != null) {
        setState(() {
          clienteId = createdId;
          // Algunos endpoints devuelven keys en snake_case (nombrecliente), otros en camelCase (nombreCliente)
          final nombre =
              (result['nombreCliente'] ?? result['nombrecliente'] ?? '')
                  .toString();
          final apellido =
              (result['apellidoCliente'] ?? result['apellidocliente'] ?? '')
                  .toString();
          clienteNombre = '$nombre ${apellido}'.trim();
        });
        // Recargar lista de clientes para el dropdown
        await _loadClientsForSucursal();
      }
    }
  }

  /// Selector de fecha y hora para cada sesión
  Future<DateTime?> _pickDateTime(
    BuildContext context, {
    String? labelSesion,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      helpText: labelSesion != null
          ? 'Fecha para $labelSesion'
          : 'Seleccionar fecha',
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: labelSesion != null
          ? 'Hora para $labelSesion'
          : 'Seleccionar hora',
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<Map<String, dynamic>?> _mostrarDialogoCantidadSesiones(
    BuildContext context,
    String nombreTratamiento, {
    int? cantidadActual,
    List<DateTime>? fechasActuales,
  }) async {
    int sesiones = cantidadActual ?? 1;
    List<DateTime> fechasElegidas = List.from(fechasActuales ?? []);

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final cs = Theme.of(context).colorScheme;
            final tt = Theme.of(context).textTheme;
            return AlertDialog(
              title: Text(
                'Programar Sesiones',
                style: tt.headlineSmall?.copyWith(
                  fontFamily: GoogleFonts.nunito().fontFamily,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tratamiento name pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        nombreTratamiento,
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '¿Cuántas sesiones?',
                      style: tt.titleSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Counter row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.remove_rounded),
                          iconSize: 22,
                          onPressed: sesiones > 1
                              ? () {
                                  setDialogState(() {
                                    sesiones--;
                                    if (fechasElegidas.length > sesiones) {
                                      fechasElegidas.removeRange(
                                        sesiones,
                                        fechasElegidas.length,
                                      );
                                    }
                                  });
                                }
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Material(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            child: Text(
                              '$sesiones',
                              style: tt.displaySmall?.copyWith(
                                fontFamily: GoogleFonts.nunito().fontFamily,
                                fontWeight: FontWeight.w800,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add_rounded),
                          iconSize: 22,
                          onPressed: sesiones < 20
                              ? () {
                                  setDialogState(() {
                                    sesiones++;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Quick picks
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [1, 3, 5, 10].map((cantidad) {
                        return ChoiceChip(
                          label: Text('$cantidad'),
                          selected: sesiones == cantidad,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                sesiones = cantidad;
                                if (fechasElegidas.length > sesiones) {
                                  fechasElegidas.removeRange(
                                    sesiones,
                                    fechasElegidas.length,
                                  );
                                }
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Fechas de las sesiones',
                      style: tt.titleSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Session date buttons
                    ...List.generate(sesiones, (index) {
                      final sesionNum = index + 1;
                      final tieneFecha = fechasElegidas.length > index;
                      final fecha = tieneFecha ? fechasElegidas[index] : null;
                      final hasDate = fecha != null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: hasDate
                            ? FilledButton.tonalIcon(
                                onPressed: () async {
                                  final fechaNueva = await _pickDateTime(
                                    context,
                                    labelSesion: 'Sesión $sesionNum',
                                  );
                                  if (fechaNueva != null) {
                                    setDialogState(() {
                                      fechasElegidas[index] = fechaNueva;
                                    });
                                  }
                                },
                                icon: const Icon(
                                  Icons.event_available_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  'Sesión $sesionNum: ${DateFormat('dd/MM/yy HH:mm').format(fecha)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: FilledButton.styleFrom(
                                  alignment: Alignment.centerLeft,
                                  minimumSize: const Size(double.infinity, 40),
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: () async {
                                  final fechaNueva = await _pickDateTime(
                                    context,
                                    labelSesion: 'Sesión $sesionNum',
                                  );
                                  if (fechaNueva != null) {
                                    setDialogState(() {
                                      while (fechasElegidas.length < index) {
                                        fechasElegidas.add(DateTime.now());
                                      }
                                      fechasElegidas.add(fechaNueva);
                                    });
                                  }
                                },
                                icon: const Icon(
                                  Icons.event_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  'Sesión $sesionNum: Seleccionar fecha',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  alignment: Alignment.centerLeft,
                                  minimumSize: const Size(double.infinity, 40),
                                ),
                              ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: fechasElegidas.length == sesiones
                      ? () {
                          Navigator.of(context).pop({
                            'cantidad_sesiones': sesiones,
                            'cronograma_sesiones': fechasElegidas,
                          });
                        }
                      : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> crearTicket() async {
    // Evitar envíos múltiples
    if (_isSubmitting) return;

    // Limpiar error de validación previo
    setState(() {
      validationError = null;
    });

    // 1. Validaciones básicas
    List<String> camposFaltantes = [];

    if (tratamientosSeleccionados.isEmpty) camposFaltantes.add('Tratamientos');
    if (clienteId == null) camposFaltantes.add('Cliente');
    if (pago == null) camposFaltantes.add('Pago realizado');

    if (camposFaltantes.isNotEmpty) {
      setState(() {
        validationError = 'Campos requeridos: ${camposFaltantes.join(", ")}';
      });
      return;
    }

    // 2. Obtener datos del entorno (Sucursal)
    final sucursalId = _sucursalProvider?.selectedSucursalId;

    if (sucursalId == null) {
      setState(() {
        validationError =
            'Error: No hay sucursal seleccionada. Selecciona una en el menú lateral.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 3. Preparar carrito de compras con cronograma de sesiones
      List<Map<String, dynamic>> itemsCarrito = [];

      for (var tratId in tratamientosSeleccionados) {
        final trat = tratamientos.firstWhere(
          (t) => t['id'] == tratId,
          orElse: () => <String, dynamic>{},
        );

        if (trat.isNotEmpty) {
          final cantidadSesiones = cantidadSesionesPorTratamiento[tratId] ?? 1;
          final cronogramaSesiones =
              cronogramaSesionesPorTratamiento[tratId] ?? [];

          // Validar que haya cronograma
          if (cronogramaSesiones.isEmpty) {
            throw Exception(
              'El tratamiento ${trat['nombreTratamiento']} no tiene fechas programadas',
            );
          }

          itemsCarrito.add({
            'id': trat['id'],
            'nombreTratamiento': trat['nombreTratamiento'] ?? '',
            'precio': (trat['precio'] is num)
                ? (trat['precio'] as num).toDouble()
                : 0.0,
            'cantidad_sesiones': cantidadSesiones,
            'cronograma_sesiones':
                cronogramaSesiones, // ← NUEVO: Lista de fechas
          });
        }
      }

      // 4. Calcular Total: precio por sesión * cantidad de sesiones por tratamiento
      final totalVenta = itemsCarrito.fold<double>(0, (sum, t) {
        final precio = (t['precio'] is num)
            ? (t['precio'] as num).toDouble()
            : 0.0;
        final cantidadSes = (t['cantidad_sesiones'] is num)
            ? (t['cantidad_sesiones'] as num).toInt()
            : 1;
        return sum + (precio * cantidadSes);
      });

      if (kDebugMode)
        debugPrint(
          'NewTicketScreen: Creating venta - cliente=$clienteId, sucursal=$sucursalId, total=$totalVenta, pago=$pago',
        );
      if (kDebugMode)
        debugPrint(
          'NewTicketScreen: Items carrito: ${itemsCarrito.map((i) => "${i['nombreTratamiento']} x${i['cantidad_sesiones']} sesiones").join(", ")}',
        );
      if (kDebugMode)
        debugPrint(
          'NewTicketScreen: Cronogramas: ${itemsCarrito.map((i) => "${i['nombreTratamiento']}: ${(i['cronograma_sesiones'] as List).map((f) => DateFormat('dd/MM HH:mm').format(f)).join(', ')}").join(" | ")}',
        );

      // Validación adicional: pago no puede superar el totalVenta
      if (pago != null && pago! > totalVenta) {
        setState(() {
          validationError =
              'El pago no puede ser mayor al total de la venta (Bs ${totalVenta.toStringAsFixed(2)})';
          _isSubmitting = false;
        });
        return;
      }

      // 5. LLAMAR AL SERVICIO (Transacción atómica)
      await _ticketRepo.registrarVenta(
        clienteId: clienteId!,
        sucursalId: sucursalId, // Ahora obligatorio
        totalVenta: totalVenta,
        pagoInicial: pago ?? 0.0,
        itemsCarrito: itemsCarrito,
        metodoPago: _metodoPagoSeleccionado,
      );

      // 6. Éxito!
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Venta registrada con éxito!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Refrescar la lista global de tickets/agenda
        try {
          final sucId = _sucursalProvider?.selectedSucursalId;
          if (sucId != null) {
            await Provider.of<TicketProvider>(
              context,
              listen: false,
            ).fetchAgenda(DateTime.now(), sucursalId: sucId);
          }
        } catch (e) {
          if (kDebugMode)
            debugPrint('NewTicketScreen: Error al refrescar agenda: $e');
        }

        // Volver a la pantalla anterior
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Mostrar error real (útil para depurar RPC)
      final msg = e.toString();
      if (kDebugMode) debugPrint('NewTicketScreen: Error creando venta: $msg');

      setState(() {
        validationError =
            'Error al crear venta: ${msg.replaceAll('Exception: ', '')}';
      });

      if (mounted) {
        // También mostrar en dialog para errores críticos
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error al crear venta'),
            content: Text(msg.replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          _isSubmitting = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isSmall = Responsive.isSmallScreen(context);

    // ── helpers ──────────────────────────────────────────────────────────────
    InputDecoration _fieldDecoration({
      required String hint,
      String? label,
      Widget? prefix,
      String? errorText,
    }) {
      return InputDecoration(
        hintText: hint,
        labelText: label,
        prefixIcon: prefix,
        errorText: errorText,
      );
    }

    Widget _sectionHeader(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: tt.titleSmall?.copyWith(
                fontFamily: GoogleFonts.nunito().fontFamily,
                color: cs.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    // ── loading / error states ────────────────────────────────────────────────
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nuevo Ticket')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: cs.primary),
              const SizedBox(height: 20),
              Text(
                'Cargando datos...',
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                'Categorías y tratamientos',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nuevo Ticket')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_rounded, size: 64, color: cs.error),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar datos',
                  style: tt.titleLarge?.copyWith(color: cs.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => error = null);
                    cargarDatos();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── main form ─────────────────────────────────────────────────────────────
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nuevo Ticket',
          style: tt.titleLarge?.copyWith(
            fontFamily: GoogleFonts.nunito().fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.horizontalPadding(context),
          vertical: Responsive.verticalPadding(context),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.isMobile(context)
                  ? double.infinity
                  : Responsive.maxContentWidth(context),
            ),
            child: RoundedCard(
              padding: EdgeInsets.all(isSmall ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── TRATAMIENTOS ───────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _sectionHeader('Tratamientos'),
                      if (tratamientosSeleccionados.isNotEmpty)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${tratamientosSeleccionados.length} · Bs ${calcularPrecioTotal().toStringAsFixed(2)}',
                              style: tt.labelMedium?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (tratamientos.isEmpty)
                    // Empty state card
                    Material(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.spa_rounded,
                              size: 36,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No hay tratamientos cargados',
                              style: tt.titleSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Es posible que haya un problema de conexión o la base de datos no contiene tratamientos activos.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Align(
                              child: FilledButton.tonalIcon(
                                onPressed: cargarDatos,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Reintentar carga'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Category filter dropdown — inherits theme InputDecoration
                        DropdownButtonFormField<int?>(
                          value: _selectedCategoriaFilter,
                          isExpanded: true,
                          decoration: _fieldDecoration(
                            hint: 'Filtrar por categoría',
                            prefix: Icon(
                              Icons.category_rounded,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Todas las categorías'),
                            ),
                            ...categorias.map<DropdownMenuItem<int>>((c) {
                              return DropdownMenuItem(
                                value: c['id'] as int?,
                                child: Text(
                                  c['nombreCategoria'] ?? 'Sin nombre',
                                ),
                              );
                            }),
                          ],
                          onChanged: (v) => setState(() {
                            _selectedCategoriaFilter = v;
                          }),
                        ),
                        const SizedBox(height: 8),
                        // Search field
                        TextField(
                          controller: _tratamientoSearchCtrl,
                          maxLines: 1,
                          decoration: _fieldDecoration(
                            hint: 'Buscar tratamiento...',
                            prefix: const Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Treatment list box
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: isSmall ? 280 : 340,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cs.outlineVariant,
                            ),
                          ),
                          child: Builder(
                            builder: (context) {
                              final searchLower =
                                  _tratamientoSearch.toLowerCase();
                              final filtered = tratamientos.where((t) {
                                final nombre =
                                    (t['nombreTratamiento'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                final catId =
                                    _getCategoriaIdFromTratamiento(t);
                                final matchesCat =
                                    _selectedCategoriaFilter == null ||
                                    catId == _selectedCategoriaFilter;
                                final matchesSearch =
                                    searchLower.isEmpty ||
                                    nombre.contains(searchLower);
                                return matchesCat && matchesSearch;
                              }).toList();

                              if (filtered.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'No hay tratamientos que coincidan',
                                    style: tt.bodyMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final t = filtered[index];
                                  final id = t['id'] as int;
                                  final precio =
                                      double.tryParse(
                                        t['precio']?.toString() ?? '0',
                                      ) ??
                                      0;
                                  final isSelected =
                                      tratamientosSeleccionados.contains(id);
                                  final cantidadSesiones =
                                      cantidadSesionesPorTratamiento[id] ?? 1;
                                  final fechasSesiones =
                                      cronogramaSesionesPorTratamiento[id] ??
                                      [];

                                  return ListTile(
                                    key: ValueKey('tratamiento_filtered_$id'),
                                    dense: isSmall,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    selectedTileColor: cs.secondaryContainer
                                        .withValues(alpha: 0.5),
                                    selected: isSelected,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isSmall ? 8 : 12,
                                      vertical: 0,
                                    ),
                                    leading: Checkbox.adaptive(
                                      value: isSelected,
                                      activeColor: cs.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      onChanged: (bool? value) async {
                                        if (value == true) {
                                          final resultado =
                                              await _mostrarDialogoCantidadSesiones(
                                                context,
                                                t['nombreTratamiento'] ??
                                                    'Tratamiento',
                                              );
                                          if (resultado != null) {
                                            setState(() {
                                              tratamientosSeleccionados.add(id);
                                              cantidadSesionesPorTratamiento[id] =
                                                  resultado['cantidad_sesiones'];
                                              cronogramaSesionesPorTratamiento[id] =
                                                  resultado['cronograma_sesiones'];
                                              pago = calcularPrecioTotal();
                                              calcularEstadoPago();
                                            });
                                          }
                                        } else {
                                          setState(() {
                                            tratamientosSeleccionados.remove(
                                              id,
                                            );
                                            cantidadSesionesPorTratamiento
                                                .remove(id);
                                            cronogramaSesionesPorTratamiento
                                                .remove(id);
                                            pago = calcularPrecioTotal();
                                            calcularEstadoPago();
                                          });
                                        }
                                      },
                                    ),
                                    title: Text(
                                      t['nombreTratamiento'] ?? 'Sin nombre',
                                      style: tt.bodyMedium?.copyWith(
                                        color: isSelected
                                            ? cs.onSecondaryContainer
                                            : null,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        fontSize: isSmall ? 13 : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                    subtitle: Row(
                                      children: [
                                        Text(
                                          'Bs ${precio.toStringAsFixed(2)}',
                                          style: tt.bodySmall?.copyWith(
                                            color: cs.onSurfaceVariant,
                                            fontSize: isSmall ? 11 : null,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 6),
                                          Chip(
                                            label: Text(
                                              '$cantidadSesiones ses.',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: cs.onPrimaryContainer,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            padding: EdgeInsets.zero,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                            side: BorderSide.none,
                                            backgroundColor:
                                                cs.primaryContainer,
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: isSelected
                                        ? IconButton.filledTonal(
                                            icon: const Icon(
                                              Icons.tune_rounded,
                                              size: 18,
                                            ),
                                            tooltip: 'Modificar sesiones',
                                            onPressed: () async {
                                              final resultado =
                                                  await _mostrarDialogoCantidadSesiones(
                                                    context,
                                                    t['nombreTratamiento'] ??
                                                        'Tratamiento',
                                                    cantidadActual:
                                                        cantidadSesiones,
                                                    fechasActuales:
                                                        fechasSesiones,
                                                  );
                                              if (resultado != null) {
                                                setState(() {
                                                  cantidadSesionesPorTratamiento[id] =
                                                      resultado['cantidad_sesiones'];
                                                  cronogramaSesionesPorTratamiento[id] =
                                                      resultado['cronograma_sesiones'];
                                                  pago = calcularPrecioTotal();
                                                  calcularEstadoPago();
                                                });
                                              }
                                            },
                                          )
                                        : null,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),

                  // ── MÉTODO DE PAGO ─────────────────────────────────────────
                  _sectionHeader('Método de pago'),
                  PaymentMethodSelector(
                    value: _metodoPagoSeleccionado,
                    onChanged: (m) => setState(() {
                      _metodoPagoSeleccionado = m;
                    }),
                  ),
                  const SizedBox(height: 20),

                  // ── CLIENTE ────────────────────────────────────────────────
                  _sectionHeader('Cliente'),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            if (kDebugMode)
                              debugPrint(
                                'NewTicketScreen: _sucursalProvider = $_sucursalProvider',
                              );
                            if (kDebugMode)
                              debugPrint(
                                'NewTicketScreen: selectedSucursalId = ${_sucursalProvider?.selectedSucursalId}',
                              );
                            if (kDebugMode)
                              debugPrint(
                                'NewTicketScreen: selectedSucursalName = ${_sucursalProvider?.selectedSucursalName}',
                              );

                            if (_sucursalProvider == null) {
                              if (kDebugMode)
                                debugPrint(
                                  'NewTicketScreen: ERROR - _sucursalProvider is NULL!',
                                );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Error: Provider no disponible. Intenta reiniciar la app.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (_sucursalProvider?.selectedSucursalId == null) {
                              if (kDebugMode)
                                debugPrint(
                                  'NewTicketScreen: ERROR - selectedSucursalId is NULL!',
                                );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Selecciona una sucursal en el menú lateral antes de continuar',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (kDebugMode)
                              debugPrint(
                                'NewTicketScreen: Opening SelectClientScreen with sucursalId=${_sucursalProvider?.selectedSucursalId}',
                              );
                            final selected = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SelectClientScreen(
                                  sucursalId:
                                      _sucursalProvider!.selectedSucursalId!,
                                ),
                              ),
                            );
                            if (selected != null && selected is Map) {
                              setState(() {
                                clienteId = selected['id'];
                                clienteNombre =
                                    '${selected['nombreCliente'] ?? ''} ${selected['apellidoCliente'] ?? ''}'
                                        .trim();
                              });
                            }
                          },
                          icon: const Icon(Icons.person_search_rounded),
                          label: Text(
                            clienteNombre == null
                                ? (clienteId == null
                                      ? 'Seleccionar cliente'
                                      : 'Cliente seleccionado')
                                : clienteNombre!,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: clienteId != null
                                ? cs.secondaryContainer
                                : cs.primary,
                            foregroundColor: clienteId != null
                                ? cs.onSecondaryContainer
                                : cs.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _showCreateClientDialog,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        tooltip: 'Nuevo cliente',
                        style: IconButton.styleFrom(
                          backgroundColor: cs.secondaryContainer,
                          foregroundColor: cs.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── TOTAL TRATAMIENTOS ─────────────────────────────────────
                  if (tratamientosSeleccionados.isNotEmpty) ...[
                    Material(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: LayoutBuilder(
                          builder: (context, box) {
                            return Row(
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  color: cs.onSecondaryContainer,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Total de tratamientos',
                                    style: tt.titleMedium?.copyWith(
                                      color: cs.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: 80,
                                    maxWidth: box.maxWidth * 0.4,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Bs ${calcularPrecioTotal().toStringAsFixed(2)}',
                                      style: tt.titleLarge?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w800,
                                        fontFamily:
                                            GoogleFonts.nunito().fontFamily,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── PAGO REALIZADO ─────────────────────────────────────────
                  _sectionHeader('Pago realizado (Bs)'),
                  TextFormField(
                    initialValue: pago?.toString() ?? '',
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(
                      hint: 'Monto pagado',
                      prefix: Icon(
                        Icons.payments_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                      errorText: (pago != null && pago! > calcularPrecioTotal())
                          ? 'El pago no puede ser mayor al total'
                          : null,
                    ),
                    onChanged: (v) {
                      setState(() {
                        pago = double.tryParse(v) ?? 0;
                        if (pago != null && pago! > calcularPrecioTotal()) {
                          validationError =
                              'El pago no puede ser mayor al total';
                        } else {
                          validationError = null;
                        }
                        calcularEstadoPago();
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── ESTADO PAGO CHIPS ──────────────────────────────────────
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        avatar: Icon(
                          estadoPago == 'Completo'
                              ? Icons.check_circle_rounded
                              : Icons.hourglass_bottom_rounded,
                          size: 16,
                          color: estadoPago == 'Completo'
                              ? cs.onPrimaryContainer
                              : cs.onTertiaryContainer,
                        ),
                        label: Text(
                          'Pago: $estadoPago',
                          style: tt.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: estadoPago == 'Completo'
                                ? cs.onPrimaryContainer
                                : cs.onTertiaryContainer,
                          ),
                        ),
                        backgroundColor: estadoPago == 'Completo'
                            ? cs.primaryContainer
                            : cs.tertiaryContainer,
                        side: BorderSide.none,
                      ),
                      if (saldoPendiente > 0)
                        Chip(
                          avatar: Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: cs.onErrorContainer,
                          ),
                          label: Text(
                            'Saldo: Bs ${saldoPendiente.toStringAsFixed(2)}',
                            style: tt.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onErrorContainer,
                            ),
                          ),
                          backgroundColor: cs.errorContainer,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── VALIDATION ERROR ───────────────────────────────────────
                  if (validationError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Material(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_rounded,
                                color: cs.onErrorContainer,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  validationError!,
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: cs.onErrorContainer,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => validationError = null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── SUBMIT BUTTON ──────────────────────────────────────────
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : crearTicket,
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: cs.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(
                      _isSubmitting ? 'Guardando...' : 'Guardar Ticket',
                      style: GoogleFonts.nunito(
                        fontSize: isSmall ? 15 : 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
