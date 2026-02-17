import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/auth_repository.dart';
import '../../providers/sucursal_provider.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  late final AuthRepository _repo;
  List<Map<String, dynamic>> _employees = [];
  bool _loading = false;
  String? _error;
  String _search = '';
  int? _lastLoadedSucursalId; // Para evitar recargas infinitas

  @override
  void initState() {
    super.initState();
    _repo = Provider.of<AuthRepository>(context, listen: false);
    // Cargamos inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEmployees();
    });
  }

  Future<void> _loadEmployees() async {
    final sucursalProvider = Provider.of<SucursalProvider>(
      context,
      listen: false,
    );
    final sucId = sucursalProvider.selectedSucursalId;

    if (sucId == null) {
      setState(() {
        _employees = [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = await _repo
          .getUsuarios(sucursalId: sucId)
          .timeout(const Duration(seconds: 10));
      final allowed = {
        'administrador',
        'admin',
        'empleado',
        'vendedor',
        'gerente',
      };

      if (mounted) {
        setState(() {
          _employees = users
              .where((u) {
                final t = (u['tipoUsuario'] ?? u['tipo_usuario'] ?? '')
                    .toString()
                    .toLowerCase();
                if (t.isEmpty) return true;
                return allowed.contains(t);
              })
              .map<Map<String, dynamic>>((u) => Map<String, dynamic>.from(u))
              .toList();
          _lastLoadedSucursalId = sucId;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is TimeoutException
              ? 'Tiempo de espera agotado'
              : e.toString();
        });
      }
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.trim().isEmpty) return _employees;
    final q = _search.trim().toLowerCase();
    return _employees.where((e) {
      final username = (e['username'] ?? '').toString().toLowerCase();
      final email = (e['email'] ?? '').toString().toLowerCase();
      return username.contains(q) || email.contains(q);
    }).toList();
  }

  Future<void> _showEmployeeDialog([Map<String, dynamic>? employee]) async {
    // CORRECCIÓN: Obtenemos el ID aquí y lo pasamos al diálogo
    final sucursalProvider = Provider.of<SucursalProvider>(
      context,
      listen: false,
    );
    final sucId = sucursalProvider.selectedSucursalId;

    if (employee == null && sucId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar una sucursal primero')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EmployeeDialog(
        repo: _repo,
        employee: employee,
        sucursalId: sucId, // Pasamos el ID explícitamente
      ),
    );
    if (result == true) await _loadEmployees();
  }

  Future<void> _confirmDelete(Map<String, dynamic> employee) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar empleado'),
        content: Text(
          '¿Eliminar a "${employee['username'] ?? employee['email']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final id = employee['documentId'] ?? employee['id']?.toString();
      if (id == null) throw Exception('ID no disponible');
      await _repo.eliminarUsuarioFunction(id.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Empleado eliminado'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadEmployees();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Usamos Consumer para escuchar cambios en la sucursal automáticamente
    return Consumer<SucursalProvider>(
      builder: (context, sucursalProv, child) {
        // Si cambió la sucursal y no hemos recargado, recargamos
        if (sucursalProv.selectedSucursalId != null &&
            sucursalProv.selectedSucursalId != _lastLoadedSucursalId &&
            !_loading) {
          // Pequeño delay para evitar build during build
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadEmployees());
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Empleados'),
            backgroundColor: cs.surface,
            actions: [
              IconButton.filledTonal(
                onPressed: _loadEmployees,
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showEmployeeDialog(),
            icon: const Icon(Icons.person_add),
            label: const Text('Nuevo'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: cs.primary),
                    hintText: 'Buscar por nombre o email',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text('Error: $_error'),
                      ) // Simplificado para brevedad
                    : _filtered.isEmpty
                    ? const Center(
                        child: Text('No hay empleados en esta sucursal'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEmployees,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final e = _filtered[i];
                            final confirmed = e['confirmed'] ?? false;
                            final blocked = e['blocked'] ?? false;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    (e['username'] ?? 'E')
                                        .toString()[0]
                                        .toUpperCase(),
                                  ),
                                ),
                                title: Text(e['username'] ?? 'Sin nombre'),
                                subtitle: Text(e['email'] ?? ''),
                                trailing: IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () => showModalBottomSheet(
                                    context: ctx,
                                    builder: (_) => _EmployeeActions(
                                      e,
                                      onEdit: () => _showEmployeeDialog(e),
                                      onDelete: () => _confirmDelete(e),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmployeeActions extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _EmployeeActions(
    this.employee, {
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Editar'),
            onTap: () {
              Navigator.pop(context);
              onEdit();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _EmployeeDialog extends StatefulWidget {
  final AuthRepository repo;
  final Map<String, dynamic>? employee;
  final int? sucursalId; // NUEVO PARAMETRO

  const _EmployeeDialog({required this.repo, this.employee, this.sucursalId});

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String _role = 'empleado';

  @override
  void initState() {
    super.initState();
    if (widget.employee != null) {
      _userCtrl.text = widget.employee!['username'] ?? '';
      _emailCtrl.text = widget.employee!['email'] ?? '';
      _role =
          widget.employee!['tipoUsuario'] ??
          widget.employee!['tipo_usuario'] ??
          'empleado';
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación de seguridad para crear
    if (widget.employee == null && widget.sucursalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se identificó la sucursal')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (widget.employee != null) {
        final id =
            widget.employee!['documentId'] ??
            widget.employee!['id']?.toString();
        if (id != null)
          await widget.repo.updateUser(
            id.toString(),
            username: _userCtrl.text,
            email: _emailCtrl.text,
            tipoUsuario: _role,
          );
      } else {
        // CREAR (Usamos el ID pasado por parámetro)
        await widget.repo.crearUsuarioFunction(
          email: _emailCtrl.text,
          password: _passCtrl.text,
          nombre: _userCtrl.text,
          sucursalId: widget.sucursalId!,
          tipoUsuario: _role,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.employee != null;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEdit ? 'Editar Empleado' : 'Nuevo Empleado',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _userCtrl,
                decoration: const InputDecoration(labelText: 'Usuario'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    v != null && v.contains('@') ? null : 'Email inválido',
              ),
              const SizedBox(height: 8),
              if (!isEdit)
                TextFormField(
                  controller: _passCtrl,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                  validator: (v) =>
                      v != null && v.length >= 6 ? null : 'Mínimo 6 caracteres',
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _role,
                items: const [
                  DropdownMenuItem(value: 'empleado', child: Text('Empleado')),
                  DropdownMenuItem(
                    value: 'administrador',
                    child: Text('Administrador'),
                  ),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'empleado'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEdit ? 'Guardar' : 'Crear'),
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
