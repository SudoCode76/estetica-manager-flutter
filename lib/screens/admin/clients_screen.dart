import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:app_estetica/services/api_service.dart';
import 'package:app_estetica/widgets/create_client_dialog.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_estetica/config/responsive.dart';


class ClientsScreen extends StatefulWidget {
  const ClientsScreen({Key? key}) : super(key: key);

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final ApiService api = ApiService();
  List<dynamic> clients = [];
  List<dynamic> filteredClients = [];
  bool isLoading = true;
  String search = '';
  String? errorMsg;
  SucursalProvider? _sucursalProvider;
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  bool _isEmployee = false;

  @override
  void initState() {
    super.initState();
    _loadUserType();
  }

  Future<void> _loadUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString('userType');
      setState(() {
        _isEmployee = userType == 'empleado';
      });
    } catch (e) {
      print('Error cargando tipo de usuario: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('ClientsScreen: didChangeDependencies called');
    final provider = SucursalInherited.of(context);
    print('ClientsScreen: Provider = $provider, selectedSucursalId = ${provider?.selectedSucursalId}');
    if (provider != _sucursalProvider) {
      print('ClientsScreen: Provider changed, removing old listener');
      _sucursalProvider?.removeListener(_onSucursalChanged);
      _sucursalProvider = provider;
      _sucursalProvider?.addListener(_onSucursalChanged);
      print('ClientsScreen: Calling fetchClients()');
      fetchClients();
    }
  }

  @override
  void dispose() {
    _sucursalProvider?.removeListener(_onSucursalChanged);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSucursalChanged() {
    print('ClientsScreen: _onSucursalChanged called');
    fetchClients();
  }

  Future<void> fetchClients() async {
    print('ClientsScreen: fetchClients() called');
    print('ClientsScreen: selectedSucursalId = ${_sucursalProvider?.selectedSucursalId}');

    if (_sucursalProvider?.selectedSucursalId == null) {
      print('ClientsScreen: ⚠️ NO HAY SUCURSAL SELECCIONADA');
      setState(() {
        isLoading = false;
        errorMsg = 'No hay sucursal seleccionada. Por favor, contacte al administrador.';
        clients = [];
        filteredClients = [];
      });
      return;
    }

    print('ClientsScreen: ✓ Sucursal seleccionada: ${_sucursalProvider!.selectedSucursalId}');
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      print('ClientsScreen: Llamando api.getClientes con sucursalId=${_sucursalProvider!.selectedSucursalId}');
      final data = await api.getClientes(
        sucursalId: _sucursalProvider!.selectedSucursalId,
        query: search.isEmpty ? null : search,
      );
      print('ClientsScreen: ✓ Recibidos ${data.length} clientes');
      clients = data;
      filteredClients = clients;
    } catch (e) {
      print('ClientsScreen: ❌ Error: $e');
      errorMsg = 'No se pudo conectar al servidor.';
    }
    setState(() {
      isLoading = false;
    });
  }

  void filterClients(String value) {
    search = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      fetchClients();
    });
  }

  Future<void> _showCreateClientDialog() async {
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
      // Recargar lista
      await fetchClients();
    }
  }

  Future<void> _showEditClientDialog(Map<String, dynamic> cliente) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditClientDialog(
        cliente: cliente,
        sucursalId: _sucursalProvider!.selectedSucursalId!,
      ),
    );

    if (result != null) {
      await fetchClients();
    }
  }

  Future<void> _deleteClient(Map<String, dynamic> cliente) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_rounded, color: colorScheme.error, size: 48),
        title: const Text('Eliminar Cliente'),
        content: Text(
          '¿Estás seguro que deseas eliminar a ${cliente['nombreCliente']} ${cliente['apellidoCliente']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Mostrar loading
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: colorScheme.primary),
                    const SizedBox(height: 16),
                    const Text('Eliminando cliente...'),
                  ],
                ),
              ),
            ),
          );
        }

        // Preferir documentId (string) si existe; si no, usar id convertido a string
        final String docIdForDelete = cliente['documentId']?.toString() ?? cliente['id']?.toString() ?? '';
        if (docIdForDelete.isEmpty) {
          if (mounted) Navigator.pop(context); // Cerrar loading
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ID del cliente no disponible, no se puede eliminar.'), backgroundColor: colorScheme.error),
            );
          }
          return;
        }
        await api.deleteCliente(docIdForDelete);

        if (mounted) Navigator.pop(context); // Cerrar loading

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: colorScheme.onPrimary),
                  const SizedBox(width: 12),
                  const Text('Cliente eliminado exitosamente'),
                ],
              ),
              backgroundColor: colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }

        await fetchClients();
      } catch (e) {
        if (mounted) Navigator.pop(context); // Cerrar loading

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: colorScheme.onError),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Error: ${e.toString()}')),
                ],
              ),
              backgroundColor: colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSmallScreen = Responsive.isSmallScreen(context);
    final isMobile = Responsive.isMobile(context);

    return SafeArea(
      child: Column(
        children: [
          // Barra de búsqueda y acciones
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(context)),
            child: Column(
              children: [
                // Búsqueda y botones en diseño adaptativo
                if (isSmallScreen) ...[
                  // En pantallas muy pequeñas, poner los botones debajo del SearchBar
                  SearchBar(
                    controller: _searchController,
                    hintText: 'Buscar cliente...',
                    hintStyle: WidgetStateProperty.all(
                      TextStyle(fontSize: isSmallScreen ? 13 : 14),
                    ),
                    leading: Icon(Icons.search, size: isSmallScreen ? 20 : 24),
                    trailing: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear, size: isSmallScreen ? 20 : 24),
                          onPressed: () {
                            _searchController.clear();
                            search = '';
                            _debounce?.cancel();
                            fetchClients();
                          },
                        ),
                    ],
                    onChanged: filterClients,
                    elevation: const WidgetStatePropertyAll(1),
                  ),
                  SizedBox(height: Responsive.spacing(context, 12)),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: fetchClients,
                          icon: Icon(Icons.refresh, size: 18),
                          label: Text('Actualizar', style: TextStyle(fontSize: 13)),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isEmployee ? null : _showCreateClientDialog,
                          icon: Icon(Icons.person_add, size: 18),
                          label: Text('Nuevo', style: TextStyle(fontSize: 13)),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // En pantallas normales, mantener diseño horizontal
                  Row(
                    children: [
                      Expanded(
                        child: SearchBar(
                          controller: _searchController,
                          hintText: isMobile ? 'Buscar...' : 'Buscar por nombre, apellido o teléfono',
                          leading: const Icon(Icons.search),
                          trailing: [
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  search = '';
                                  _debounce?.cancel();
                                  fetchClients();
                                },
                              ),
                          ],
                          onChanged: filterClients,
                          elevation: const WidgetStatePropertyAll(1),
                        ),
                      ),
                      SizedBox(width: Responsive.spacing(context, 12)),
                      FilledButton.icon(
                        onPressed: fetchClients,
                        icon: const Icon(Icons.refresh),
                        label: Text(isMobile ? '' : 'Actualizar'),
                        style: FilledButton.styleFrom(
                          minimumSize: Size(isMobile ? 56 : 120, 56),
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
                        ),
                      ),
                      if (!_isEmployee) ...[
                        SizedBox(width: Responsive.spacing(context, 8)),
                        FilledButton.icon(
                          onPressed: _showCreateClientDialog,
                          icon: const Icon(Icons.person_add),
                          label: Text(isMobile ? '' : 'Nuevo'),
                          style: FilledButton.styleFrom(
                            minimumSize: Size(isMobile ? 56 : 120, 56),
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                SizedBox(height: Responsive.spacing(context, 8)),
              ],
            ),
          ),

          // Lista de clientes
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                : errorMsg != null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                size: isSmallScreen ? 48 : 64,
                                color: colorScheme.error
                              ),
                              SizedBox(height: Responsive.spacing(context, 16)),
                              Text(
                                errorMsg!,
                                style: (isSmallScreen ? textTheme.bodyMedium : textTheme.bodyLarge)?.copyWith(
                                  color: colorScheme.error
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredClients.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_search_rounded,
                                    size: isSmallScreen ? 48 : 64,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  SizedBox(height: Responsive.spacing(context, 16)),
                                  Text(
                                    search.isEmpty
                                        ? 'No hay clientes en esta sucursal'
                                      : 'No se encontraron clientes',
                                  style: (isSmallScreen ? textTheme.bodyMedium : textTheme.bodyLarge)?.copyWith(
                                    color: colorScheme.onSurfaceVariant
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: Responsive.spacing(context, 8)),
                                Text(
                                  search.isEmpty
                                      ? 'Registra el primer cliente'
                                      : 'Intenta con otro término de búsqueda',
                                  style: (isSmallScreen ? textTheme.bodySmall : textTheme.bodyMedium)?.copyWith(
                                    color: colorScheme.onSurfaceVariant
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.horizontalPadding(context),
                              vertical: Responsive.verticalPadding(context),
                            ),
                            itemCount: filteredClients.length,
                            itemBuilder: (context, i) {
                              final c = filteredClients[i];
                              final nombre = '${c['nombreCliente'] ?? ''} ${c['apellidoCliente'] ?? ''}'.trim();
                              final telefono = c['telefono']?.toString() ?? 'Sin teléfono';
                              final avatarSize = isSmallScreen ? 48.0 : 56.0;
                              final fontSize = isSmallScreen ? 18.0 : 20.0;

                              return Card(
                                margin: EdgeInsets.only(bottom: Responsive.spacing(context, 12)),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 12 : 16,
                                    vertical: isSmallScreen ? 8 : 12,
                                  ),
                                  leading: Container(
                                    width: avatarSize,
                                    height: avatarSize,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          colorScheme.primaryContainer,
                                          colorScheme.secondaryContainer,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          color: colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    nombre,
                                    style: (isSmallScreen ? textTheme.titleSmall : textTheme.titleMedium)?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: isSmallScreen ? 12 : 14,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      SizedBox(width: Responsive.spacing(context, 4)),
                                      Flexible(
                                        child: Text(
                                          telefono,
                                          style: (isSmallScreen ? textTheme.bodySmall : textTheme.bodyMedium)?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                        ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: _isEmployee
                                      ? null // No mostrar menú para empleados
                                      : PopupMenuButton(
                                          icon: Icon(
                                            Icons.more_vert,
                                            color: colorScheme.onSurfaceVariant,
                                            size: isSmallScreen ? 20 : 24,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              onTap: () {
                                                Future.delayed(Duration.zero, () => _showEditClientDialog(c));
                                              },
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit, size: isSmallScreen ? 18 : 20, color: colorScheme.primary),
                                                  SizedBox(width: Responsive.spacing(context, 12)),
                                                  Text('Editar', style: TextStyle(fontSize: isSmallScreen ? 13 : 14)),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              onTap: () {
                                                Future.delayed(Duration.zero, () => _deleteClient(c));
                                              },
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete, size: isSmallScreen ? 18 : 20, color: colorScheme.error),
                                                  SizedBox(width: Responsive.spacing(context, 12)),
                                                  Text('Eliminar', style: TextStyle(fontSize: isSmallScreen ? 13 : 14)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
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

// Diálogo de editar cliente
class _EditClientDialog extends StatefulWidget {
  final Map<String, dynamic> cliente;
  final int sucursalId;

  const _EditClientDialog({
    required this.cliente,
    required this.sucursalId,
  });

  @override
  State<_EditClientDialog> createState() => _EditClientDialogState();
}

class _EditClientDialogState extends State<_EditClientDialog> {
  late final TextEditingController _nombreController;
  late final TextEditingController _apellidoController;
  late final TextEditingController _telefonoController;
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.cliente['nombreCliente'] ?? '');
    _apellidoController = TextEditingController(text: widget.cliente['apellidoCliente'] ?? '');
    _telefonoController = TextEditingController(text: widget.cliente['telefono']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _editarCliente() async {
    if (!_formKey.currentState!.validate()) return;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text('Actualizando cliente...', style: textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );

    try {
      final Map<String, dynamic> actualizado = {
        'nombreCliente': _nombreController.text.trim(),
        'apellidoCliente': _apellidoController.text.trim(),
        'telefono': int.tryParse(_telefonoController.text) ?? 0,
        'estadoCliente': widget.cliente['estadoCliente'] ?? true,
        'sucursal': widget.sucursalId,
      };

      // Preferir documentId (string) si existe; si no, usar id convertido a string
      final String docIdForUpdate = widget.cliente['documentId']?.toString() ?? widget.cliente['id']?.toString() ?? '';
      if (docIdForUpdate.isEmpty) {
        if (mounted) Navigator.pop(context); // Cerrar loading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ID del cliente no disponible, no se puede actualizar.'), backgroundColor: colorScheme.error),
          );
        }
        return;
      }
      await _api.updateCliente(docIdForUpdate, actualizado);

      // Cerrar loading
      if (mounted) Navigator.pop(context);
      // Cerrar diálogo con resultado
      if (mounted) Navigator.pop(context, actualizado);

      // Mostrar confirmación
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: colorScheme.onPrimary),
                const SizedBox(width: 12),
                const Text('Cliente actualizado exitosamente'),
              ],
            ),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      // Cerrar loading
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: colorScheme.onError),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header con gradiente
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.secondaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 32,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Editar Cliente',
                              style: textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Actualizar información del cliente',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Formulario
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Campo Nombre
                        TextFormField(
                          controller: _nombreController,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Nombre *',
                            hintText: 'Ej: María',
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person_outline,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'El nombre es requerido' : null,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),

                        // Campo Apellido
                        TextFormField(
                          controller: _apellidoController,
                          decoration: InputDecoration(
                            labelText: 'Apellido',
                            hintText: 'Ej: González',
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.badge_outlined,
                                color: colorScheme.secondary,
                                size: 20,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),

                        // Campo Teléfono
                        TextFormField(
                          controller: _telefonoController,
                          decoration: InputDecoration(
                            labelText: 'Teléfono',
                            hintText: 'Ej: 71234567',
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.phone_outlined,
                                color: colorScheme.tertiary,
                                size: 20,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 24),

                        // Botones
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _editarCliente,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('Guardar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
