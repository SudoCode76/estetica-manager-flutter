import 'dart:ui';
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
   Map<int, int> cantidadSesionesPorTratamiento = {}; // cantidad de sesiones por tratamiento
   Map<int, List<DateTime>> cronogramaSesionesPorTratamiento = {}; // NUEVO: fechas de cada sesión
   int? clienteId;
   String? clienteNombre;
   int? usuarioId;
   String? usuarioNombre;
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
   bool isLoadingUserType = true; // NUEVO: controla si se ha determinado el tipo de usuario
   String? error; // Error de carga de datos (muestra pantalla completa de error)
   String? validationError; // Error de validación/creación (se muestra inline en el formulario)
   bool _isSubmitting = false; // Flag para evitar envíos múltiples y mostrar loader

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
       if (_tratamientoSearchDebounce?.isActive ?? false) _tratamientoSearchDebounce!.cancel();
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
       'categoriaTratamientos'
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

   Future<void> cargarDatos() async {
     setState(() {
       isLoading = true;
       error = null;
     });
     try {
       if (kDebugMode) debugPrint('NewTicketScreen: Cargando categorías...');
      List<dynamic> cats;
      try {
        cats = await _catalogRepo.getCategorias().timeout(const Duration(seconds: 8));
      } on TimeoutException {
        throw Exception('Timeout al obtener categorías (verifica conexión)');
      }
       // Filtrar solo categorías activas (estadoCategoria == true o null->assume active)
       categorias = List<dynamic>.from(cats.where((c) => c['estadoCategoria'] == true || c['estadoCategoria'] == null));
       if (kDebugMode) debugPrint('NewTicketScreen: ${categorias.length} categorías activas cargadas (de ${cats.length})');

       if (kDebugMode) debugPrint('NewTicketScreen: Cargando tratamientos...');
      List<dynamic> tr;
      try {
        tr = await _catalogRepo.getTratamientos().timeout(const Duration(seconds: 8));
      } on TimeoutException {
        throw Exception('Timeout al obtener tratamientos (verifica conexión)');
      }
       // Filtrar solo tratamientos activos
       tratamientos = List<dynamic>.from(tr.where((t) => t['estadoTratamiento'] == true || t['estadoTratamiento'] == null));
       if (kDebugMode) debugPrint('NewTicketScreen: ${tratamientos.length} tratamientos activos cargados (de ${tr.length})');

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
     setState(() { isLoading = false; });
   }

   Future<void> _loadUsuariosForSucursal() async {
     setState(() {
       isLoadingUsuarios = true;
     });

     final sucId = _sucursalProvider?.selectedSucursalId;
     if (kDebugMode) debugPrint('NewTicketScreen: _loadUsuariosForSucursal called with sucursalId=$sucId');
     if (kDebugMode) debugPrint('NewTicketScreen: Current usuarioId=$usuarioId, _isEmployee=$_isEmployee');
     try {
       final data = await _authRepo.getUsuarios(sucursalId: sucId);
       if (kDebugMode) debugPrint('NewTicketScreen: Loaded ${data.length} usuarios');
       if (kDebugMode) debugPrint('NewTicketScreen: Usuario IDs en lista: ${data.map((u) => u['id']).toList()}');
       setState(() {
         usuarios = data;
         isLoadingUsuarios = false;
         // si el usuario seleccionado no pertenece a esta sucursal, limpiarlo
         if (usuarioId != null && !usuarios.any((u) => u['id'] == usuarioId)) {
           if (kDebugMode) debugPrint('NewTicketScreen: ⚠️ Clearing usuarioId=$usuarioId (not in filtered list)');
           usuarioId = null;
         } else if (usuarioId != null) {
           if (kDebugMode) debugPrint('NewTicketScreen: ✓ usuarioId=$usuarioId está en la lista');
         }
       });
     } catch (e) {
       final msg = e.toString();
       if (kDebugMode) debugPrint('NewTicketScreen: ❌ Error loading usuarios: $msg');
       setState(() {
         isLoadingUsuarios = false;
       });
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar usuarios: $msg')));
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
       final data = await _clienteRepo.searchClientes(sucursalId: _sucursalProvider!.selectedSucursalId, query: query);
       setState(() {
         clientes = data;
       });
     } catch (e) {
       final msg = e.toString();
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar clientes: $msg')));
     }
   }


   double calcularPrecioTotal() {
     double total = 0;
     for (var id in tratamientosSeleccionados) {
       final trat = tratamientos.firstWhere((t) => t['id'] == id, orElse: () => null);
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
           content: Text('Selecciona una sucursal en el menú lateral antes de continuar'),
           behavior: SnackBarBehavior.floating,
         ),
       );
       return;
     }

     final result = await CreateClientDialog.show(context, _sucursalProvider!.selectedSucursalId!);

     if (result != null) {
       // Extraer el ID del cliente creado
       final createdId = result['id'] as int?;
       if (createdId != null) {
         setState(() {
           clienteId = createdId;
           // Algunos endpoints devuelven keys en snake_case (nombrecliente), otros en camelCase (nombreCliente)
           final nombre = (result['nombreCliente'] ?? result['nombrecliente'] ?? '').toString();
           final apellido = (result['apellidoCliente'] ?? result['apellidocliente'] ?? '').toString();
           clienteNombre = '$nombre ${apellido}'.trim();
         });
         // Recargar lista de clientes para el dropdown
         await _loadClientsForSucursal();
       }
     }
   }

   /// Selector de fecha y hora para cada sesión
   Future<DateTime?> _pickDateTime(BuildContext context, {String? labelSesion}) async {
     final date = await showDatePicker(
       context: context,
       initialDate: DateTime.now(),
       firstDate: DateTime.now(),
       lastDate: DateTime(2030),
       helpText: labelSesion != null ? 'Fecha para $labelSesion' : 'Seleccionar fecha',
     );
     if (date == null) return null;

     final time = await showTimePicker(
       context: context,
       initialTime: TimeOfDay.now(),
       helpText: labelSesion != null ? 'Hora para $labelSesion' : 'Seleccionar hora',
     );
     if (time == null) return null;

     return DateTime(date.year, date.month, date.day, time.hour, time.minute);
   }

   Future<Map<String, dynamic>?> _mostrarDialogoCantidadSesiones(
     BuildContext context,
     String nombreTratamiento,
     {int? cantidadActual, List<DateTime>? fechasActuales}
   ) async {
     int sesiones = cantidadActual ?? 1;
     List<DateTime> fechasElegidas = List.from(fechasActuales ?? []);

     return showDialog<Map<String, dynamic>>(
       context: context,
       barrierDismissible: false,
       builder: (BuildContext context) {
         return StatefulBuilder(
           builder: (context, setDialogState) {
             return AlertDialog(
               title: Text(
                 'Programar Sesiones',
                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
               ),
               content: SingleChildScrollView(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       nombreTratamiento,
                       style: TextStyle(
                         fontSize: 14,
                         color: Theme.of(context).colorScheme.onSurfaceVariant,
                       ),
                     ),
                     const SizedBox(height: 16),
                     Text(
                       '¿Cuántas sesiones?',
                       style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                     ),
                     const SizedBox(height: 12),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         IconButton(
                           icon: const Icon(Icons.remove_circle_outline),
                           iconSize: 28,
                           onPressed: sesiones > 1
                               ? () {
                                   setDialogState(() {
                                     sesiones--;
                                     if (fechasElegidas.length > sesiones) {
                                       fechasElegidas.removeRange(sesiones, fechasElegidas.length);
                                     }
                                   });
                                 }
                               : null,
                         ),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                           decoration: BoxDecoration(
                             color: Theme.of(context).colorScheme.primaryContainer,
                             borderRadius: BorderRadius.circular(10),
                           ),
                           child: Text(
                             '$sesiones',
                             style: TextStyle(
                               fontSize: 28,
                               fontWeight: FontWeight.bold,
                               color: Theme.of(context).colorScheme.onPrimaryContainer,
                             ),
                           ),
                         ),
                         IconButton(
                           icon: const Icon(Icons.add_circle_outline),
                           iconSize: 28,
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
                     const SizedBox(height: 12),
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
                                   fechasElegidas.removeRange(sesiones, fechasElegidas.length);
                                 }
                               });
                             }
                           },
                         );
                       }).toList(),
                     ),
                     const SizedBox(height: 20),
                     Divider(),
                     const SizedBox(height: 12),
                     Text(
                       'Fechas de las sesiones:',
                       style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                     ),
                     const SizedBox(height: 8),
                     // Lista de fechas programadas
                     ...List.generate(sesiones, (index) {
                       final sesionNum = index + 1;
                       final tieneFecha = fechasElegidas.length > index;
                       final fecha = tieneFecha ? fechasElegidas[index] : null;

                       return Padding(
                         padding: const EdgeInsets.only(bottom: 8),
                         child: OutlinedButton.icon(
                           onPressed: () async {
                             final fechaNueva = await _pickDateTime(
                               context,
                               labelSesion: 'Sesión $sesionNum',
                             );
                             if (fechaNueva != null) {
                               setDialogState(() {
                                 if (tieneFecha) {
                                   fechasElegidas[index] = fechaNueva;
                                 } else {
                                   while (fechasElegidas.length < index) {
                                     fechasElegidas.add(DateTime.now());
                                   }
                                   fechasElegidas.add(fechaNueva);
                                 }
                               });
                             }
                           },
                           icon: Icon(
                             fecha != null ? Icons.event_available : Icons.event,
                             size: 18,
                           ),
                           label: Text(
                             fecha != null
                                 ? 'Sesión $sesionNum: ${DateFormat('dd/MM/yy HH:mm').format(fecha)}'
                                 : 'Sesión $sesionNum: Seleccionar fecha',
                             style: TextStyle(fontSize: 12),
                           ),
                           style: OutlinedButton.styleFrom(
                             backgroundColor: fecha != null
                                 ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                                 : null,
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
                 FilledButton(
                   onPressed: fechasElegidas.length == sesiones
                       ? () {
                           Navigator.of(context).pop({
                             'cantidad_sesiones': sesiones,
                             'cronograma_sesiones': fechasElegidas,
                           });
                         }
                       : null,
                   child: const Text('Confirmar'),
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
     setState(() { validationError = null; });

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
         validationError = 'Error: No hay sucursal seleccionada. Selecciona una en el menú lateral.';
       });
       return;
     }

     setState(() { _isSubmitting = true; });

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
            final cronogramaSesiones = cronogramaSesionesPorTratamiento[tratId] ?? [];

            // Validar que haya cronograma
            if (cronogramaSesiones.isEmpty) {
              throw Exception('El tratamiento ${trat['nombreTratamiento']} no tiene fechas programadas');
            }

            itemsCarrito.add({
              'id': trat['id'],
              'nombreTratamiento': trat['nombreTratamiento'] ?? '',
              'precio': (trat['precio'] is num) ? (trat['precio'] as num).toDouble() : 0.0,
              'cantidad_sesiones': cantidadSesiones,
              'cronograma_sesiones': cronogramaSesiones, // ← NUEVO: Lista de fechas
            });
          }
        }

        // 4. Calcular Total: precio por sesión * cantidad de sesiones por tratamiento
        final totalVenta = itemsCarrito.fold<double>(
          0,
          (sum, t) {
            final precio = (t['precio'] is num) ? (t['precio'] as num).toDouble() : 0.0;
            final cantidadSes = (t['cantidad_sesiones'] is num) ? (t['cantidad_sesiones'] as num).toInt() : 1;
            return sum + (precio * cantidadSes);
          },
        );

        if (kDebugMode) debugPrint('NewTicketScreen: Creating venta - cliente=$clienteId, sucursal=$sucursalId, total=$totalVenta, pago=$pago');
        if (kDebugMode) debugPrint('NewTicketScreen: Items carrito: ${itemsCarrito.map((i) => "${i['nombreTratamiento']} x${i['cantidad_sesiones']} sesiones").join(", ")}');
        if (kDebugMode) debugPrint('NewTicketScreen: Cronogramas: ${itemsCarrito.map((i) => "${i['nombreTratamiento']}: ${(i['cronograma_sesiones'] as List).map((f) => DateFormat('dd/MM HH:mm').format(f)).join(', ')}").join(" | ")}');

       // Validación adicional: pago no puede superar el totalVenta
       if (pago != null && pago! > totalVenta) {
         setState(() {
           validationError = 'El pago no puede ser mayor al total de la venta (Bs ${totalVenta.toStringAsFixed(2)})';
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
               await Provider.of<TicketProvider>(context, listen: false).fetchAgenda(DateTime.now(), sucursalId: sucId);
             }
           } catch (e) {
             if (kDebugMode) debugPrint('NewTicketScreen: Error al refrescar agenda: $e');
           }

           // Volver a la pantalla anterior
           Navigator.pop(context, true);
         }
     } catch (e) {
       // Mostrar error real (útil para depurar RPC)
       final msg = e.toString();
       if (kDebugMode) debugPrint('NewTicketScreen: Error creando venta: $msg');

       setState(() {
         validationError = 'Error al crear venta: ${msg.replaceAll('Exception: ', '')}';
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
       if (mounted) setState(() { _isSubmitting = false; });
     }
   }

   @override
   Widget build(BuildContext context) {
     final colorScheme = Theme.of(context).colorScheme;

     return Scaffold(
       appBar: AppBar(
         title: const Text('Nuevo Ticket'),
       ),
       body: isLoading
           ? Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   CircularProgressIndicator(
                     color: colorScheme.primary,
                   ),
                   const SizedBox(height: 16),
                   Text(
                     'Cargando datos...',
                     style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                       color: colorScheme.onSurfaceVariant,
                     ),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     'Categorías y tratamientos',
                     style: Theme.of(context).textTheme.bodySmall?.copyWith(
                       color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                     ),
                   ),
                 ],
               ),
             )
           : error != null
               ? Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(
                         Icons.error_outline,
                         size: 64,
                         color: colorScheme.error,
                       ),
                       const SizedBox(height: 16),
                       Text(
                         'Error al cargar datos',
                         style: Theme.of(context).textTheme.titleLarge?.copyWith(
                           color: colorScheme.error,
                         ),
                       ),
                       const SizedBox(height: 8),
                       Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 32),
                         child: Text(
                           error!,
                           textAlign: TextAlign.center,
                           style: Theme.of(context).textTheme.bodyMedium,
                         ),
                       ),
                       const SizedBox(height: 24),
                       FilledButton.icon(
                         onPressed: () {
                           setState(() {
                             error = null;
                           });
                           cargarDatos();
                         },
                         icon: const Icon(Icons.refresh),
                         label: const Text('Reintentar'),
                       ),
                     ],
                   ),
                 )
               : SingleChildScrollView(
               padding: EdgeInsets.symmetric(
                 horizontal: Responsive.horizontalPadding(context),
                 vertical: Responsive.verticalPadding(context),
               ),
               child: LayoutBuilder(builder: (context, constraints) {
                 // Calcular ancho máximo para evitar overflow horizontal en pantallas pequeñas
                 final horizontalPad = Responsive.horizontalPadding(context);
                 final maxWidth = (constraints.maxWidth - (horizontalPad * 2)).clamp(0.0, Responsive.maxContentWidth(context));
                 return Center(
                   child: ConstrainedBox(
                     constraints: BoxConstraints(maxWidth: maxWidth > 0 ? maxWidth : constraints.maxWidth),
                     child: ClipRRect(
                       borderRadius: BorderRadius.circular(Responsive.isSmallScreen(context) ? 20 : 28),
                       child: BackdropFilter(
                         filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                         child: Container(
                           decoration: BoxDecoration(
                             borderRadius: BorderRadius.circular(28),
                             color: colorScheme.surface.withValues(alpha: 0.12),
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.black.withValues(alpha: 0.08),
                                 blurRadius: 30,
                                 offset: const Offset(0, 10),
                               ),
                             ],
                             border: Border.all(color: colorScheme.outline.withValues(alpha: 0.06)),
                           ),
                            padding: EdgeInsets.all(Responsive.isSmallScreen(context) ? 16 : 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Tratamientos agrupados por categoría (permite seleccionar de múltiples categorías)
                                Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                     'Tratamientos',
                                     style: Theme.of(context).textTheme.labelLarge,
                                   ),
                                   if (tratamientosSeleccionados.isNotEmpty)
                                     Flexible(
                                       child: Text(
                                         '${tratamientosSeleccionados.length} seleccionado(s) - Bs ${calcularPrecioTotal().toStringAsFixed(2)}',
                                         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                           color: colorScheme.primary,
                                           fontWeight: FontWeight.bold,
                                         ),
                                         textAlign: TextAlign.right,
                                         overflow: TextOverflow.ellipsis,
                                         maxLines: 2,
                                       ),
                                     ),
                                 ],
                               ),
                               const SizedBox(height: 8),
                               if (tratamientos.isEmpty)
                                 Container(
                                   padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                   decoration: BoxDecoration(
                                     color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.04),
                                     borderRadius: BorderRadius.circular(14),
                                   ),
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.stretch,
                                     children: [
                                       Text(
                                         'No hay tratamientos cargados',
                                         style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                                       ),
                                       const SizedBox(height: 8),
                                       Text(
                                         'Es posible que haya un problema de conexión o la base de datos no contiene tratamientos activos.',
                                         style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                                       ),
                                       const SizedBox(height: 12),
                                       Align(
                                         alignment: Alignment.centerLeft,
                                         child: FilledButton.icon(
                                           onPressed: () {
                                             cargarDatos();
                                           },
                                           icon: const Icon(Icons.refresh),
                                           label: const Text('Reintentar carga'),
                                         ),
                                       ),
                                     ],
                                   ),
                                 )
                               else
                                 Column(
                                   crossAxisAlignment: CrossAxisAlignment.stretch,
                                   children: [
                                     // Dropdown de categorías (filtro)
                                     DropdownButtonFormField<int?>(
                                       initialValue: _selectedCategoriaFilter,
                                       isExpanded: true,
                                       decoration: InputDecoration(
                                         contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: Responsive.isSmallScreen(context) ? 12 : 14),
                                         filled: true,
                                         fillColor: colorScheme.surfaceContainerHighest,
                                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5))),
                                       ),
                                       items: [
                                         const DropdownMenuItem<int?>(value: null, child: Text('Todas las categorías')),
                                         ...categorias.map<DropdownMenuItem<int>>((c) {
                                           return DropdownMenuItem(value: c['id'] as int?, child: Text(c['nombreCategoria'] ?? 'Sin nombre'));
                                         }).toList(),
                                       ],
                                       onChanged: (v) => setState(() {
                                         _selectedCategoriaFilter = v;
                                       }),
                                       hint: const Text('Filtrar por categoría'),
                                     ),
                                     const SizedBox(height: 8),
                                     // Buscador de tratamientos
                                     TextField(
                                       controller: _tratamientoSearchCtrl,
                                       decoration: InputDecoration(
                                         hintText: 'Buscar tratamiento...',
                                         prefixIcon: const Icon(Icons.search),
                                         filled: true,
                                         fillColor: colorScheme.surfaceContainerHighest,
                                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5))),
                                       ),
                                       // Evitar que el campo crezca más de lo disponible
                                       maxLines: 1,
                                     ),
                                     const SizedBox(height: 8),
                                     Container(
                                       constraints: BoxConstraints(maxHeight: Responsive.isSmallScreen(context) ? 300 : 360),
                                       decoration: BoxDecoration(
                                         color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                                         borderRadius: BorderRadius.circular(14),
                                         border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                                       ),
                                       child: Builder(builder: (context) {
                                         final searchLower = _tratamientoSearch.toLowerCase();
                                         final filtered = tratamientos.where((t) {
                                           final nombre = (t['nombreTratamiento'] ?? '').toString().toLowerCase();
                                           final catId = _getCategoriaIdFromTratamiento(t);
                                           final matchesCat = _selectedCategoriaFilter == null || catId == _selectedCategoriaFilter;
                                           final matchesSearch = searchLower.isEmpty || nombre.contains(searchLower);
                                           return matchesCat && matchesSearch;
                                         }).toList();

                                         if (filtered.isEmpty) {
                                           return Padding(
                                             padding: const EdgeInsets.all(16.0),
                                             child: Text('No hay tratamientos que coincidan', style: Theme.of(context).textTheme.bodyMedium),
                                           );
                                         }

                                         return ListView.builder(
                                           shrinkWrap: true,
                                           itemCount: filtered.length,
                                           itemBuilder: (context, index) {
                                             final t = filtered[index];
                                             final id = t['id'] as int;
                                             final precio = double.tryParse(t['precio']?.toString() ?? '0') ?? 0;
                                             final isSelected = tratamientosSeleccionados.contains(id);
                                             final cantidadSesiones = cantidadSesionesPorTratamiento[id] ?? 1;
                                             final fechasSesiones = cronogramaSesionesPorTratamiento[id] ?? [];

                                             return ListTile(
                                               key: ValueKey('tratamiento_filtered_$id'),
                                               dense: Responsive.isSmallScreen(context),
                                               contentPadding: EdgeInsets.symmetric(horizontal: Responsive.isSmallScreen(context) ? 8 : 16, vertical: 0),
                                               leading: Checkbox(
                                                 value: isSelected,
                                                 onChanged: (bool? value) async {
                                                   if (value == true) {
                                                     // Mostrar diálogo para seleccionar cantidad y fechas de sesiones
                                                     final resultado = await _mostrarDialogoCantidadSesiones(
                                                       context,
                                                       t['nombreTratamiento'] ?? 'Tratamiento',
                                                     );
                                                     if (resultado != null) {
                                                       setState(() {
                                                         tratamientosSeleccionados.add(id);
                                                         cantidadSesionesPorTratamiento[id] = resultado['cantidad_sesiones'];
                                                         cronogramaSesionesPorTratamiento[id] = resultado['cronograma_sesiones'];
                                                         final total = calcularPrecioTotal();
                                                         pago = total;
                                                         calcularEstadoPago();
                                                       });
                                                     }
                                                   } else {
                                                     setState(() {
                                                       tratamientosSeleccionados.remove(id);
                                                       cantidadSesionesPorTratamiento.remove(id);
                                                       cronogramaSesionesPorTratamiento.remove(id);
                                                       final total = calcularPrecioTotal();
                                                       pago = total;
                                                       calcularEstadoPago();
                                                     });
                                                   }
                                                 },
                                               ),
                                               title: Text(
                                                 t['nombreTratamiento'] ?? 'Sin nombre',
                                                 style: TextStyle(
                                                   color: isSelected ? colorScheme.primary : null,
                                                   fontWeight: isSelected ? FontWeight.bold : null,
                                                   fontSize: Responsive.isSmallScreen(context) ? 13 : null,
                                                 ),
                                                 overflow: TextOverflow.ellipsis,
                                                 maxLines: 2,
                                               ),
                                               subtitle: Row(
                                                 children: [
                                                   Text(
                                                     'Bs ${precio.toStringAsFixed(2)}',
                                                     style: TextStyle(fontSize: Responsive.isSmallScreen(context) ? 11 : null),
                                                   ),
                                                   if (isSelected) ...[
                                                     const SizedBox(width: 8),
                                                     Container(
                                                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                       decoration: BoxDecoration(
                                                         color: colorScheme.primaryContainer,
                                                         borderRadius: BorderRadius.circular(4),
                                                       ),
                                                       child: Text(
                                                         '$cantidadSesiones sesión${cantidadSesiones > 1 ? "es" : ""}',
                                                         style: TextStyle(
                                                           fontSize: 10,
                                                           color: colorScheme.onPrimaryContainer,
                                                           fontWeight: FontWeight.bold,
                                                         ),
                                                       ),
                                                     ),
                                                   ],
                                                 ],
                                               ),
                                               trailing: isSelected
                                                   ? IconButton(
                                                       icon: const Icon(Icons.settings, size: 20),
                                                       tooltip: 'Modificar sesiones',
                                                       onPressed: () async {
                                                         final resultado = await _mostrarDialogoCantidadSesiones(
                                                           context,
                                                           t['nombreTratamiento'] ?? 'Tratamiento',
                                                           cantidadActual: cantidadSesiones,
                                                           fechasActuales: fechasSesiones,
                                                         );
                                                         if (resultado != null) {
                                                           setState(() {
                                                             cantidadSesionesPorTratamiento[id] = resultado['cantidad_sesiones'];
                                                             cronogramaSesionesPorTratamiento[id] = resultado['cronograma_sesiones'];
                                                             final total = calcularPrecioTotal();
                                                             pago = total;
                                                             calcularEstadoPago();
                                                           });
                                                         }
                                                       },
                                                     )
                                                   : null,
                                             );
                                           },
                                         );
                                       }),
                                     ),
                                   ],
                                 ),
                               const SizedBox(height: 18),
                               Text('Cliente', style: Theme.of(context).textTheme.labelLarge),
                               const SizedBox(height: 8),
                               Row(
                                 children: [
                                   Expanded(
                                     child: FilledButton.icon(
                                       onPressed: () async {
                                         // Debug: ver qué sucursal tiene el provider
                                         if (kDebugMode) debugPrint('NewTicketScreen: _sucursalProvider = $_sucursalProvider');
                                         if (kDebugMode) debugPrint('NewTicketScreen: selectedSucursalId = ${_sucursalProvider?.selectedSucursalId}');
                                         if (kDebugMode) debugPrint('NewTicketScreen: selectedSucursalName = ${_sucursalProvider?.selectedSucursalName}');

                                         // Validar que haya provider
                                         if (_sucursalProvider == null) {
                                           if (kDebugMode) debugPrint('NewTicketScreen: ERROR - _sucursalProvider is NULL!');
                                           ScaffoldMessenger.of(context).showSnackBar(
                                             const SnackBar(content: Text('Error: Provider no disponible. Intenta reiniciar la app.')),
                                           );
                                           return;
                                         }

                                         // Validar que haya sucursal seleccionada
                                         if (_sucursalProvider?.selectedSucursalId == null) {
                                           if (kDebugMode) debugPrint('NewTicketScreen: ERROR - selectedSucursalId is NULL!');
                                           ScaffoldMessenger.of(context).showSnackBar(
                                             const SnackBar(content: Text('Selecciona una sucursal en el menú lateral antes de continuar')),
                                           );
                                           return;
                                         }

                                         if (kDebugMode) debugPrint('NewTicketScreen: Opening SelectClientScreen with sucursalId=${_sucursalProvider?.selectedSucursalId}');
                                         final selected = await Navigator.push(
                                           context,
                                           MaterialPageRoute(builder: (context) => SelectClientScreen(sucursalId: _sucursalProvider!.selectedSucursalId!)),
                                         );
                                         if (selected != null && selected is Map) {
                                           setState(() {
                                             clienteId = selected['id'];
                                             clienteNombre = '${selected['nombreCliente'] ?? ''} ${selected['apellidoCliente'] ?? ''}'.trim();
                                           });
                                           // volver automáticamente a la pantalla de crear ticket (ya estamos en ella), no hacemos nada más
                                         }
                                       },
                                       icon: const Icon(Icons.person_search),
                                       label: Text(clienteNombre == null ? (clienteId == null ? 'Seleccionar cliente' : 'Cliente seleccionado') : clienteNombre!),
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                   FilledButton(
                                     onPressed: _showCreateClientDialog,
                                     child: const Icon(Icons.person_add),
                                   ),
                                 ],
                               ),
                               const SizedBox(height: 18),
                               // Mostrar precio total de tratamientos
                               if (tratamientosSeleccionados.isNotEmpty)
                                 Container(
                                   padding: const EdgeInsets.all(16),
                                   decoration: BoxDecoration(
                                     color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                     borderRadius: BorderRadius.circular(14),
                                     border: Border.all(
                                       color: colorScheme.primary.withValues(alpha: 0.2),
                                     ),
                                   ),
                                   child: LayoutBuilder(builder: (context, box) {
                                     // Usamos LayoutBuilder para ajustar el ancho del monto.
                                     return Row(
                                       children: [
                                         // Label flexible que puede ocupar varias líneas si es necesario
                                         Expanded(
                                           child: Text(
                                             'Total de tratamientos:',
                                             style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                               fontWeight: FontWeight.bold,
                                             ),
                                             maxLines: 2,
                                             overflow: TextOverflow.ellipsis,
                                           ),
                                         ),
                                         const SizedBox(width: 8),
                                         // Monto con ancho restringido y FittedBox para escalar el texto y evitar cortes
                                         ConstrainedBox(
                                           constraints: BoxConstraints(
                                             minWidth: 80,
                                             maxWidth: box.maxWidth * 0.45,
                                           ),
                                           child: FittedBox(
                                             fit: BoxFit.scaleDown,
                                             alignment: Alignment.centerRight,
                                             child: Text(
                                               'Bs ${calcularPrecioTotal().toStringAsFixed(2)}',
                                               style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                 color: colorScheme.primary,
                                                 fontWeight: FontWeight.bold,
                                               ),
                                               textAlign: TextAlign.right,
                                             ),
                                           ),
                                         ),
                                       ],
                                     );
                                   }),
                                 ),
                               if (tratamientosSeleccionados.isNotEmpty) const SizedBox(height: 18),
                               // Pago
                               Text('Pago realizado (Bs)', style: Theme.of(context).textTheme.labelLarge),
                               const SizedBox(height: 8),
                               TextFormField(
                                 initialValue: pago?.toString() ?? '',
                                 keyboardType: TextInputType.number,
                                 decoration: InputDecoration(
                                   hintText: 'Monto pagado',
                                   errorText: (pago != null && pago! > calcularPrecioTotal()) ? 'El pago no puede ser mayor al total' : null,
                                 ),
                                 onChanged: (v) {
                                   setState(() {
                                     pago = double.tryParse(v) ?? 0;
                                     // Validación inmediata: si pago excede el total, mostrar mensaje
                                     if (pago != null && pago! > calcularPrecioTotal()) {
                                       validationError = 'El pago no puede ser mayor al total';
                                     } else {
                                       validationError = null;
                                     }
                                     calcularEstadoPago();
                                   });
                                 },
                               ),
                               const SizedBox(height: 18),
                               // Estado de pago y saldo (responsive)
                               Wrap(
                                 spacing: 12,
                                 runSpacing: 6,
                                 crossAxisAlignment: WrapCrossAlignment.center,
                                 children: [
                                   Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                     decoration: BoxDecoration(
                                       color: estadoPago == 'Completo' ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.08),
                                       borderRadius: BorderRadius.circular(12),
                                     ),
                                     child: Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         Text('Estado de pago: ', style: Theme.of(context).textTheme.bodyMedium),
                                         Text(estadoPago, style: TextStyle(color: estadoPago == 'Completo' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                                       ],
                                     ),
                                   ),
                                   Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                     decoration: BoxDecoration(
                                       color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.08),
                                       borderRadius: BorderRadius.circular(12),
                                     ),
                                     child: Text('Saldo pendiente: Bs ${saldoPendiente.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                                   ),
                                 ],
                               ),
                               const SizedBox(height: 24),
                               // Mensaje de error de validación
                               if (validationError != null)
                                 Container(
                                   margin: const EdgeInsets.only(bottom: 16),
                                   padding: const EdgeInsets.all(12),
                                   decoration: BoxDecoration(
                                     color: Theme.of(context).colorScheme.errorContainer,
                                     borderRadius: BorderRadius.circular(12),
                                     border: Border.all(
                                       color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
                                     ),
                                   ),
                                   child: Row(
                                     children: [
                                       Icon(
                                         Icons.error_outline,
                                         color: Theme.of(context).colorScheme.onErrorContainer,
                                         size: 24,
                                       ),
                                       const SizedBox(width: 12),
                                       Expanded(
                                         child: Text(
                                           validationError!,
                                           style: TextStyle(
                                             color: Theme.of(context).colorScheme.onErrorContainer,
                                             fontWeight: FontWeight.w500,
                                           ),
                                         ),
                                       ),
                                       IconButton(
                                         icon: Icon(
                                           Icons.close,
                                           color: Theme.of(context).colorScheme.onErrorContainer,
                                           size: 20,
                                         ),
                                         onPressed: () {
                                           setState(() { validationError = null; });
                                         },
                                         padding: EdgeInsets.zero,
                                         constraints: const BoxConstraints(),
                                       ),
                                     ],
                                   ),
                                 ),
                               FilledButton.icon(
                                 onPressed: _isSubmitting ? null : crearTicket,
                                 icon: _isSubmitting ? SizedBox(
                                   width: Responsive.isSmallScreen(context) ? 16 : 18,
                                   height: Responsive.isSmallScreen(context) ? 16 : 18,
                                   child: const CircularProgressIndicator(strokeWidth: 2),
                                 ) : Icon(
                                   Icons.save,
                                   size: Responsive.isSmallScreen(context) ? 18 : 20,
                                 ),
                                 label: Text(
                                   _isSubmitting ? 'Guardando...' : 'Guardar Ticket',
                                   style: TextStyle(fontSize: Responsive.isSmallScreen(context) ? 14 : 16),
                                 ),
                                 style: FilledButton.styleFrom(
                                   padding: EdgeInsets.symmetric(
                                     vertical: Responsive.isSmallScreen(context) ? 14 : 16,
                                   ),
                                   textStyle: TextStyle(
                                     fontSize: Responsive.isSmallScreen(context) ? 16 : 18,
                                     fontWeight: FontWeight.bold,
                                   ),
                                   shape: RoundedRectangleBorder(
                                     borderRadius: BorderRadius.circular(Responsive.isSmallScreen(context) ? 12 : 16),
                                   ),
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ),
                     ),
                   ),
                 );
               }),
             ),
     );
   }
 }
