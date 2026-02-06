import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:app_estetica/repositories/cliente_repository.dart';
import 'package:app_estetica/config/responsive.dart';
import 'package:provider/provider.dart';

class CreateClientDialog extends StatefulWidget {
  final int sucursalId;

  const CreateClientDialog({
    super.key,
    required this.sucursalId,
  });

  @override
  State<CreateClientDialog> createState() => _CreateClientDialogState();

  /// Muestra el diálogo y retorna el cliente creado o null
  static Future<Map<String, dynamic>?> show(BuildContext context, int sucursalId) async {
    return await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CreateClientDialog(sucursalId: sucursalId),
    );
  }
}

class _CreateClientDialogState extends State<CreateClientDialog> {
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _crearCliente() async {
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
              Text('Registrando cliente...', style: textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );

    try {
      final Map<String, dynamic> nuevo = {
        'nombreCliente': _nombreController.text.trim(),
        'apellidoCliente': _apellidoController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'estadoCliente': true,
        'sucursal_id': widget.sucursalId, // SIEMPRE incluir la sucursal (clave DB)
      };

      debugPrint('CreateClientDialog: Creando cliente en sucursal=${widget.sucursalId}');
      debugPrint('CreateClientDialog: Datos: $nuevo');

      final creado = await Provider.of<ClienteRepository>(context, listen: false).crearCliente(nuevo);

      debugPrint('CreateClientDialog: Cliente creado exitosamente');

      // Cerrar loading
      if (mounted) Navigator.pop(context);
      // Cerrar diálogo con resultado
      if (mounted) Navigator.pop(context, creado);

      // Mostrar confirmación
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: colorScheme.onPrimary),
                const SizedBox(width: 12),
                const Text('Cliente registrado exitosamente'),
              ],
            ),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('CreateClientDialog: Error al crear cliente: ${e.toString()}');
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
    final isSmallScreen = Responsive.isSmallScreen(context);
    final dialogWidth = Responsive.dialogWidth(context);
    final dialogPadding = Responsive.dialogPadding(context);
    final borderRadius = isSmallScreen ? 20.0 : 32.0;
    final iconSize = isSmallScreen ? 24.0 : 32.0;
    final headerPadding = isSmallScreen ? 16.0 : 24.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: Responsive.verticalPadding(context),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: BoxConstraints(maxWidth: dialogWidth),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: isSmallScreen ? 20 : 30,
                offset: Offset(0, isSmallScreen ? 5 : 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header con gradiente
                Container(
                  padding: EdgeInsets.all(headerPadding),
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
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_add_rounded,
                          size: iconSize,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      SizedBox(width: Responsive.spacing(context, 16)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nuevo Cliente',
                              style: (isSmallScreen ? textTheme.titleLarge : textTheme.headlineSmall)?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: Responsive.spacing(context, 4)),
                            Text(
                              'Registrar información del cliente',
                              style: (isSmallScreen ? textTheme.labelSmall : textTheme.bodySmall)?.copyWith(
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
                  padding: dialogPadding,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Campo Nombre
                        TextFormField(
                          controller: _nombreController,
                          autofocus: !isSmallScreen, // No autofocus en pantallas pequeñas
                          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                          decoration: InputDecoration(
                            labelText: 'Nombre *',
                            hintText: 'Ej: María',
                            prefixIcon: Container(
                              margin: EdgeInsets.all(isSmallScreen ? 6 : 8),
                              padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                              ),
                              child: Icon(
                                Icons.person_outline,
                                color: colorScheme.primary,
                                size: isSmallScreen ? 18 : 20,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12 : 16,
                              vertical: isSmallScreen ? 12 : 16,
                            ),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'El nombre es requerido' : null,
                          textCapitalization: TextCapitalization.words,
                        ),
                        SizedBox(height: Responsive.spacing(context, 16)),

                        // Campo Apellido
                        TextFormField(
                          controller: _apellidoController,
                          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                          decoration: InputDecoration(
                            labelText: 'Apellido',
                            hintText: 'Ej: González',
                            prefixIcon: Container(
                              margin: EdgeInsets.all(isSmallScreen ? 6 : 8),
                              padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                              ),
                              child: Icon(
                                Icons.badge_outlined,
                                color: colorScheme.secondary,
                                size: isSmallScreen ? 18 : 20,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12 : 16,
                              vertical: isSmallScreen ? 12 : 16,
                            ),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        SizedBox(height: Responsive.spacing(context, 16)),

                        // Campo Teléfono
                        TextFormField(
                          controller: _telefonoController,
                          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                          decoration: InputDecoration(
                            labelText: 'Teléfono',
                            hintText: 'Ej: 71234567',
                            prefixIcon: Container(
                              margin: EdgeInsets.all(isSmallScreen ? 6 : 8),
                              padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                              ),
                              child: Icon(
                                Icons.phone_outlined,
                                color: colorScheme.tertiary,
                                size: isSmallScreen ? 18 : 20,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12 : 16,
                              vertical: isSmallScreen ? 12 : 16,
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v != null && v.isNotEmpty) {
                              final num = int.tryParse(v);
                              if (num == null) return 'Ingrese solo números';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isSmallScreen ? 20 : 24),

                        // Botones
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    vertical: isSmallScreen ? 12 : 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                                  ),
                                ),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                                ),
                              ),
                            ),
                            SizedBox(width: Responsive.spacing(context, 12)),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: _crearCliente,
                                icon: Icon(Icons.check_rounded, size: isSmallScreen ? 18 : 20),
                                label: Text(
                                  'Registrar',
                                  style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    vertical: isSmallScreen ? 12 : 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                                  ),
                                ),
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

