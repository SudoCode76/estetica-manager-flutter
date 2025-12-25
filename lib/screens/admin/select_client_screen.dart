import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_estetica/services/api_service.dart';

class SelectClientScreen extends StatefulWidget {
  final int sucursalId; // Ahora obligatorio
  const SelectClientScreen({Key? key, required this.sucursalId}) : super(key: key);

  @override
  State<SelectClientScreen> createState() => _SelectClientScreenState();
}

class _SelectClientScreenState extends State<SelectClientScreen> {
  final ApiService api = ApiService();
  List<dynamic> clients = [];
  bool isLoading = true;
  String? loadError;
  String query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // cargar con el sucursalId pasado
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClients());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadClients([String? q]) async {
    setState(() { isLoading = true; loadError = null; });
    try {
      final sucursalId = widget.sucursalId;
      // Debug: cargando clientes (sucursal, query)
      print('SelectClientScreen: Loading clientes for sucursal=$sucursalId query=$q');
      final data = await api.getClientes(sucursalId: sucursalId, query: q);
      print('SelectClientScreen: Loaded ${data.length} clientes');
      setState(() {
        clients = data;
        isLoading = false;
      });
    } catch (e) {
      final msg = e.toString();
      print('SelectClientScreen: Error loading clientes: $msg');
      setState(() {
        loadError = msg;
        clients = [];
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar clientes: $msg')));
      }
    }
  }

  Future<void> _showCreateClientDialog() async {
    final nombreController = TextEditingController();
    final apellidoController = TextEditingController();
    final telefonoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String,dynamic>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar cliente'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v == null || v.isEmpty ? 'Ingrese nombre' : null,
              ),
              TextFormField(
                controller: apellidoController,
                decoration: const InputDecoration(labelText: 'Apellido'),
              ),
              TextFormField(
                controller: telefonoController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            try {
              final Map<String, dynamic> nuevo = {
                'nombreCliente': nombreController.text.trim(),
                'apellidoCliente': apellidoController.text.trim(),
                'telefono': int.tryParse(telefonoController.text) ?? 0,
                'estadoCliente': true,
                'sucursal': widget.sucursalId, // Siempre asignar la sucursal
              };
              final creado = await api.crearCliente(nuevo);
              Navigator.pop(context, creado as Map<String, dynamic>?);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al crear cliente')));
            }
          }, child: const Text('Crear')),
        ],
      ),
    );

    if (result != null) {
      // si se creó un cliente, retornar ese cliente al caller
      Navigator.pop(context, result);
    } else {
      // recargar lista
      await _loadClients(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar cliente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateClientDialog,
            tooltip: 'Registrar cliente',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar cliente',
              ),
              onChanged: (v) {
                query = v;
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  _loadClients(query);
                });
              },
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : (loadError != null)
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Error al cargar clientes', style: TextStyle(color: colorScheme.error)),
                            const SizedBox(height: 8),
                            Text(loadError!, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 12),
                            FilledButton(onPressed: () => _loadClients(query), child: const Text('Reintentar')),
                          ],
                        ),
                      )
                    : clients.isEmpty
                        ? Center(child: Text('No hay clientes en esta sucursal', style: TextStyle(color: colorScheme.onSurfaceVariant)))
                        : ListView.separated(
                         itemCount: clients.length,
                         separatorBuilder: (_, __) => const Divider(height: 1),
                         itemBuilder: (context, i) {
                           final c = clients[i];
                           final nombre = '${c['nombreCliente'] ?? ''} ${c['apellidoCliente'] ?? ''}'.trim();
                           final telefono = c['telefono']?.toString() ?? '';
                           return ListTile(
                             title: Text(nombre.isNotEmpty ? nombre : 'Sin nombre'),
                             subtitle: Text(telefono),
                             onTap: () {
                               Navigator.pop(context, c);
                             },
                           );
                         },
                       ),
           ),
         ],
       ),
     );
   }
 }
