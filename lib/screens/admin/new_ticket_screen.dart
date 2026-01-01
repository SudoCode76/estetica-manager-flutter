import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_estetica/services/api_service.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/screens/admin/select_client_screen.dart';
import 'package:app_estetica/widgets/create_client_dialog.dart';

class NewTicketScreen extends StatefulWidget {
  final String? currentUserId;
  const NewTicketScreen({Key? key, this.currentUserId}) : super(key: key);

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
   final ApiService api = ApiService();
   DateTime? fecha;
   List<int> tratamientosSeleccionados = []; // Ahora soporta múltiples tratamientos
   int? clienteId;
   String? clienteNombre;
   int? usuarioId;
   double? cuota;
   double? pago;
   double saldoPendiente = 0;
   String estadoPago = 'Incompleto';
   bool estadoTicket = false; // Nuevo ticket por defecto: no atendido

   List<dynamic> tratamientos = [];
   List<dynamic> categorias = [];
   List<dynamic> clientes = [];
   List<dynamic> usuarios = [];
   bool isLoading = true;
   String? error;

   SucursalProvider? _sucursalProvider;
   Timer? _clientSearchDebounce;

   @override
   void initState() {
     super.initState();
     cargarDatos();
   }

   @override
   void didChangeDependencies() {
     super.didChangeDependencies();
     final provider = SucursalInherited.of(context);
     if (provider != _sucursalProvider) {
       _sucursalProvider?.removeListener(_onSucursalChanged);
       _sucursalProvider = provider;
       _sucursalProvider?.addListener(_onSucursalChanged);
       // cargar clientes y usuarios de la sucursal seleccionada
       _loadClientsForSucursal();
       _loadUsuariosForSucursal();
     }
   }

   @override
   void dispose() {
     _clientSearchDebounce?.cancel();
     _sucursalProvider?.removeListener(_onSucursalChanged);
     super.dispose();
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

   Widget _buildTratamientosList(ColorScheme colorScheme) {
     final tratamientosSinCategoria = tratamientos.where((t) {
       return _getCategoriaIdFromTratamiento(t) == null;
     }).toList();

     final itemCount = categorias.length + (tratamientosSinCategoria.isNotEmpty ? 1 : 0);

     return ListView.builder(
       shrinkWrap: true,
       itemCount: itemCount,
       itemBuilder: (context, index) {
         if (index == categorias.length && tratamientosSinCategoria.isNotEmpty) {
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                 decoration: BoxDecoration(
                   color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                   border: Border(
                     bottom: BorderSide(
                       color: colorScheme.outline.withValues(alpha: 0.1),
                     ),
                   ),
                 ),
                 child: Row(
                   children: [
                     Icon(
                       Icons.category_outlined,
                       size: 20,
                       color: colorScheme.onSurfaceVariant,
                     ),
                     const SizedBox(width: 8),
                     Expanded(
                       child: Text(
                         'Otros tratamientos',
                         style: Theme.of(context).textTheme.titleSmall?.copyWith(
                           fontWeight: FontWeight.bold,
                           color: colorScheme.onSurfaceVariant,
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
               ...tratamientosSinCategoria.map((t) {
                 final id = t['id'] as int;
                 final precio = double.tryParse(t['precio']?.toString() ?? '0') ?? 0;
                 final isSelected = tratamientosSeleccionados.contains(id);

                 return CheckboxListTile(
                   key: ValueKey('tratamiento_sin_cat_$id'),
                   title: Text(t['nombreTratamiento'] ?? 'Sin nombre'),
                   subtitle: Text('Bs ${precio.toStringAsFixed(2)}'),
                   value: isSelected,
                   onChanged: (bool? value) {
                     setState(() {
                       if (value == true) {
                         tratamientosSeleccionados.add(id);
                         print('✅ Tratamiento $id agregado. Total: ${tratamientosSeleccionados.length}');
                       } else {
                         tratamientosSeleccionados.remove(id);
                         print('❌ Tratamiento $id removido. Total: ${tratamientosSeleccionados.length}');
                       }
                       print('📋 Lista actual: $tratamientosSeleccionados');
                       final total = calcularPrecioTotal();
                       pago = total;
                       calcularEstadoPago();
                     });
                   },
                   controlAffinity: ListTileControlAffinity.leading,
                 );
               }).toList(),
             ],
           );
         }

         // Categorías normales
         final categoria = categorias[index];
         final categoriaId = categoria['id'];
         final categoriaNombre = categoria['nombreCategoria'] ?? 'Sin categoría';

         // Filtrar tratamientos de esta categoría usando la función helper
         final tratamientosDeCat = tratamientos.where((t) {
           final catId = _getCategoriaIdFromTratamiento(t);
           return catId != null && catId == categoriaId;
         }).toList();

         if (tratamientosDeCat.isEmpty) return const SizedBox.shrink();

         return Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // Header de categoría
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               decoration: BoxDecoration(
                 color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                 border: Border(
                   bottom: BorderSide(
                     color: colorScheme.outline.withValues(alpha: 0.1),
                   ),
                 ),
               ),
               child: Row(
                 children: [
                   Icon(
                     Icons.spa,
                     size: 20,
                     color: colorScheme.primary,
                   ),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       categoriaNombre,
                       style: Theme.of(context).textTheme.titleSmall?.copyWith(
                         fontWeight: FontWeight.bold,
                         color: colorScheme.primary,
                       ),
                     ),
                   ),
                 ],
               ),
             ),
             // Lista de tratamientos de esta categoría
             ...tratamientosDeCat.map((t) {
               final id = t['id'] as int;
               final precio = double.tryParse(t['precio']?.toString() ?? '0') ?? 0;
               final isSelected = tratamientosSeleccionados.contains(id);

               return CheckboxListTile(
                 key: ValueKey('tratamiento_cat_${categoriaId}_$id'),
                 title: Text(t['nombreTratamiento'] ?? 'Sin nombre'),
                 subtitle: Text('Bs ${precio.toStringAsFixed(2)}'),
                 value: isSelected,
                 onChanged: (bool? value) {
                   setState(() {
                     if (value == true) {
                       tratamientosSeleccionados.add(id);
                       print('✅ Tratamiento $id (categoría $categoriaId) agregado. Total: ${tratamientosSeleccionados.length}');
                     } else {
                       tratamientosSeleccionados.remove(id);
                       print('❌ Tratamiento $id (categoría $categoriaId) removido. Total: ${tratamientosSeleccionados.length}');
                     }
                     print('📋 Lista actual: $tratamientosSeleccionados');
                     // Recalcular el pago y estado
                     final total = calcularPrecioTotal();
                     pago = total;
                     calcularEstadoPago();
                   });
                 },
                 controlAffinity: ListTileControlAffinity.leading,
               );
             }).toList(),
           ],
         );
       },
     );
   }

   Future<void> cargarDatos() async {
     setState(() {
       isLoading = true;
       error = null;
     });
     try {
       print('NewTicketScreen: Cargando categorías...');
       categorias = await api.getCategorias();
       print('NewTicketScreen: ${categorias.length} categorías cargadas');

       print('NewTicketScreen: Cargando tratamientos...');
       tratamientos = await api.getTratamientos(); // Cargar TODOS los tratamientos
       print('NewTicketScreen: ${tratamientos.length} tratamientos cargados');

       // no cargamos clientes ni usuarios aquí; se cargan por sucursal cuando el provider esté listo
     } catch (e) {
       print('NewTicketScreen: Error al cargar datos: $e');
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
     final sucId = _sucursalProvider?.selectedSucursalId;
     print('NewTicketScreen: _loadUsuariosForSucursal called with sucursalId=$sucId');
     try {
       final data = await api.getUsuarios(sucursalId: sucId);
       print('NewTicketScreen: Loaded ${data.length} usuarios');
       setState(() {
         usuarios = data;
         // si el usuario seleccionado no pertenece a esta sucursal, limpiarlo
         if (usuarioId != null && !usuarios.any((u) => u['id'] == usuarioId)) {
           print('NewTicketScreen: Clearing usuarioId=$usuarioId (not in filtered list)');
           usuarioId = null;
         }
       });
     } catch (e) {
       final msg = e.toString();
       print('NewTicketScreen: Error loading usuarios: $msg');
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
       final data = await api.getClientes(sucursalId: _sucursalProvider!.selectedSucursalId, query: query);
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
         total += double.tryParse(trat['precio']?.toString() ?? '0') ?? 0;
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
           clienteNombre = '${result['nombreCliente'] ?? ''} ${result['apellidoCliente'] ?? ''}'.trim();
         });
         // Recargar lista de clientes para el dropdown
         await _loadClientsForSucursal();
       }
     }
   }

   Future<void> crearTicket() async {
     if (fecha == null || tratamientosSeleccionados.isEmpty || clienteId == null || (usuarioId == null && widget.currentUserId == null) || pago == null) {
       setState(() { error = 'Completa todos los campos'; });
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Completa todos los campos requeridos')),
       );
       return;
     }
     if (_sucursalProvider?.selectedSucursalId == null) {
       setState(() { error = 'Selecciona una sucursal en el menú lateral'; });
       return;
     }
     calcularEstadoPago();

     final usuarioFinalId = usuarioId ?? int.tryParse(widget.currentUserId ?? '0');

     final ticket = {
       'fecha': fecha!.toIso8601String(),
       'cuota': cuota,
       'saldoPendiente': saldoPendiente,
       'estadoTicket': estadoTicket,
       'tratamientos': tratamientosSeleccionados, // Array de IDs de tratamientos
       'cliente': clienteId,
       'users_permissions_user': usuarioFinalId,
       'estadoPago': estadoPago,
       'sucursal': _sucursalProvider!.selectedSucursalId,
     };

     final ok = await api.crearTicket(ticket);
     if (ok) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('Ticket creado exitosamente'),
             backgroundColor: Colors.green,
           ),
         );
         Navigator.pop(context, true);
       }
     } else {
       setState(() { error = 'Error al crear ticket'; });
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('Error al crear el ticket'),
           backgroundColor: Colors.red,
         ),
       );
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
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
               child: ClipRRect(
                 borderRadius: BorderRadius.circular(28),
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
                     padding: const EdgeInsets.all(24),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                         // Fecha
                         Text('Fecha y hora', style: Theme.of(context).textTheme.labelLarge),
                         const SizedBox(height: 8),
                         GestureDetector(
                           onTap: () async {
                             final picked = await showDatePicker(
                               context: context,
                               initialDate: DateTime.now(),
                               firstDate: DateTime(2020),
                               lastDate: DateTime(2100),
                             );
                             if (picked != null) {
                               final time = await showTimePicker(
                                 context: context,
                                 initialTime: TimeOfDay.now(),
                               );
                               if (time != null) {
                                 setState(() {
                                   fecha = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                                 });
                               }
                             }
                           },
                           child: Container(
                             padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                             decoration: BoxDecoration(
                               color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                               borderRadius: BorderRadius.circular(14),
                             ),
                             child: Text(
                               fecha == null ? 'Seleccionar fecha y hora' : DateFormat('dd/MM/yyyy HH:mm').format(fecha!),
                               style: const TextStyle(fontSize: 16),
                             ),
                           ),
                         ),
                         const SizedBox(height: 18),
                         // Tratamientos agrupados por categoría (permite seleccionar de múltiples categorías)
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text('Tratamientos', style: Theme.of(context).textTheme.labelLarge),
                             if (tratamientosSeleccionados.isNotEmpty)
                               Text(
                                 '${tratamientosSeleccionados.length} seleccionado(s) - Bs ${calcularPrecioTotal().toStringAsFixed(2)}',
                                 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                   color: colorScheme.primary,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                           ],
                         ),
                         const SizedBox(height: 8),
                         if (tratamientos.isEmpty)
                           Container(
                             padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                             decoration: BoxDecoration(
                               color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                               borderRadius: BorderRadius.circular(14),
                             ),
                             child: Text(
                               'Cargando tratamientos...',
                               style: TextStyle(
                                 fontSize: 16,
                                 color: colorScheme.onSurfaceVariant,
                               ),
                             ),
                           )
                         else
                           Container(
                             constraints: const BoxConstraints(maxHeight: 400),
                             decoration: BoxDecoration(
                               color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                               borderRadius: BorderRadius.circular(14),
                               border: Border.all(
                                 color: colorScheme.outline.withValues(alpha: 0.2),
                               ),
                             ),
                             child: _buildTratamientosList(colorScheme),
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
                                   print('NewTicketScreen: _sucursalProvider = $_sucursalProvider');
                                   print('NewTicketScreen: selectedSucursalId = ${_sucursalProvider?.selectedSucursalId}');
                                   print('NewTicketScreen: selectedSucursalName = ${_sucursalProvider?.selectedSucursalName}');

                                   // Validar que haya provider
                                   if (_sucursalProvider == null) {
                                     print('NewTicketScreen: ERROR - _sucursalProvider is NULL!');
                                     ScaffoldMessenger.of(context).showSnackBar(
                                       const SnackBar(content: Text('Error: Provider no disponible. Intenta reiniciar la app.')),
                                     );
                                     return;
                                   }

                                   // Validar que haya sucursal seleccionada
                                   if (_sucursalProvider?.selectedSucursalId == null) {
                                     print('NewTicketScreen: ERROR - selectedSucursalId is NULL!');
                                     ScaffoldMessenger.of(context).showSnackBar(
                                       const SnackBar(content: Text('Selecciona una sucursal en el menú lateral antes de continuar')),
                                     );
                                     return;
                                   }

                                   print('NewTicketScreen: Opening SelectClientScreen with sucursalId=${_sucursalProvider?.selectedSucursalId}');
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
                         const SizedBox(height: 8),
                         // Usuario
                         Text('Usuario', style: Theme.of(context).textTheme.labelLarge),
                         const SizedBox(height: 8),
                         DropdownButtonFormField<int>(
                           initialValue: usuarioId,
                           items: usuarios.map<DropdownMenuItem<int>>((u) {
                             return DropdownMenuItem(
                               value: u['id'],
                               child: Text(u['username'] ?? u['email'] ?? ''),
                             );
                           }).toList(),
                           onChanged: (v) => setState(() => usuarioId = v),
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
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 Text(
                                   'Total de tratamientos:',
                                   style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                     fontWeight: FontWeight.bold,
                                   ),
                                 ),
                                 Text(
                                   'Bs ${calcularPrecioTotal().toStringAsFixed(2)}',
                                   style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                     color: colorScheme.primary,
                                     fontWeight: FontWeight.bold,
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         if (tratamientosSeleccionados.isNotEmpty) const SizedBox(height: 18),
                         // Pago
                         Text('Pago realizado (Bs)', style: Theme.of(context).textTheme.labelLarge),
                         const SizedBox(height: 8),
                         TextFormField(
                           initialValue: pago?.toString() ?? '',
                           keyboardType: TextInputType.number,
                           decoration: const InputDecoration(
                             hintText: 'Monto pagado',
                           ),
                           onChanged: (v) {
                             setState(() {
                               pago = double.tryParse(v) ?? 0;
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
                         if (error != null)
                           Padding(
                             padding: const EdgeInsets.only(bottom: 12),
                             child: Text(error!, style: const TextStyle(color: Colors.red)),
                           ),
                         FilledButton.icon(
                           onPressed: crearTicket,
                           icon: const Icon(Icons.save),
                           label: const Text('Guardar Ticket'),
                           style: FilledButton.styleFrom(
                             padding: const EdgeInsets.symmetric(vertical: 16),
                             textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

