import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/repositories/catalog_repository.dart';
import 'package:app_estetica/providers/finance_provider.dart';
import 'package:app_estetica/providers/reports_provider.dart';
import 'package:app_estetica/widgets/finance_date_nav_bar.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FinanceProvider>().fetchDashboardForDate(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final dashboard = provider.dashboard;
        final totalIngresos =
            (dashboard['total_ingresos'] as num?)?.toDouble() ?? 0.0;
        final totalEgresos =
            (dashboard['total_egresos'] as num?)?.toDouble() ?? 0.0;
        final ingresosPorSucursal =
            (dashboard['ingresos_por_sucursal'] as List?) ?? [];
        final egresosPorSucursal =
            (dashboard['egresos_por_sucursal'] as List?) ?? [];
        final movimientosRecientes =
            (dashboard['movimientos_recientes'] as List?) ?? [];

        if (provider.isLoading && !_hasData(dashboard)) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: provider.refreshCurrent,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Controla ingresos, egresos y movimientos por periodo.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: provider.isSavingExpense
                        ? null
                        : () => _showRegisterExpenseDialog(context),
                    icon: provider.isSavingExpense
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_card_rounded),
                    label: const Text('Registrar egreso'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FinanceDateNavBar(
                provider: provider,
                onDateChanged: provider.fetchDashboardForDate,
                onRangeChanged: provider.fetchDashboardForRange,
                onMonthChanged: provider.fetchDashboardForMonth,
                onYearChanged: provider.fetchDashboardForYear,
              ),
              const SizedBox(height: 16),
              _SummaryCard(
                title: 'Ingresos Totales',
                subtitle: _buildSubtitle(provider),
                amount: totalIngresos,
                icon: Icons.account_balance_wallet_rounded,
                accentColor: cs.primary,
              ),
              const SizedBox(height: 16),
              _BranchTotalsSection(
                title: 'Ingresos por sucursal',
                icon: Icons.trending_up_rounded,
                items: ingresosPorSucursal,
                emptyText: 'No hay ingresos registrados todavía.',
              ),
              const SizedBox(height: 16),
              _BranchTotalsSection(
                title: 'Egresos por sucursal',
                icon: Icons.trending_down_rounded,
                items: egresosPorSucursal,
                emptyText: 'No hay egresos registrados todavía.',
                totalOverride: totalEgresos,
              ),
              const SizedBox(height: 16),
              _RecentMovementsSection(items: movimientosRecientes),
              if (provider.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'No se pudo actualizar Finanzas: ${provider.error}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: cs.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  bool _hasData(Map<String, dynamic> dashboard) {
    final ingresos = (dashboard['ingresos_por_sucursal'] as List?) ?? [];
    final egresos = (dashboard['egresos_por_sucursal'] as List?) ?? [];
    final movimientos = (dashboard['movimientos_recientes'] as List?) ?? [];
    return ingresos.isNotEmpty || egresos.isNotEmpty || movimientos.isNotEmpty;
  }

  String _buildSubtitle(FinanceProvider provider) {
    switch (provider.dateMode) {
      case ReportDateMode.singleDay:
      case ReportDateMode.period:
        return 'Ingresos consolidados del día seleccionado';
      case ReportDateMode.dateRange:
        return 'Ingresos consolidados del rango seleccionado';
      case ReportDateMode.monthPick:
        return 'Ingresos consolidados del mes seleccionado';
      case ReportDateMode.yearPick:
        return 'Ingresos consolidados del año seleccionado';
    }
  }

  Future<void> _showRegisterExpenseDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _RegisterExpenseDialog(),
    );

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Egreso registrado correctamente')),
      );
    }
  }
}

class _RegisterExpenseDialog extends StatefulWidget {
  const _RegisterExpenseDialog();

  @override
  State<_RegisterExpenseDialog> createState() => _RegisterExpenseDialogState();
}

class _RegisterExpenseDialogState extends State<_RegisterExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();

  DateTime _expenseDate = DateTime.now();
  int? _selectedSucursalId;
  List<dynamic> _sucursales = [];
  List<Map<String, dynamic>> _categorySuggestions = [];
  bool _loadingSucursales = true;
  bool _loadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadSucursales();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadSucursales() async {
    final catalogRepo = context.read<CatalogRepository>();
    final sucursalProvider = context.read<SucursalProvider>();

    try {
      final sucursales = await catalogRepo.getSucursales();
      if (!mounted) return;
      setState(() {
        _sucursales = sucursales;
        _selectedSucursalId = sucursalProvider.selectedSucursalId;
        _loadingSucursales = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSucursales = false;
      });
    }
  }

  Future<void> _searchCategories(String query) async {
    setState(() {
      _loadingSuggestions = true;
    });

    try {
      final suggestions = await context
          .read<FinanceProvider>()
          .searchExpenseCategories(query);
      if (!mounted) return;
      setState(() {
        _categorySuggestions = suggestions;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categorySuggestions = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSuggestions = false;
        });
      }
    }
  }

  Future<void> _pickExpenseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      locale: const Locale('es'),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _expenseDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        now.hour,
        now.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0 || _selectedSucursalId == null) {
      return;
    }

    try {
      await context.read<FinanceProvider>().registerExpense(
        amount: amount,
        description: _descriptionController.text.trim(),
        sucursalId: _selectedSucursalId!,
        categoryName: _categoryController.text.trim(),
        expenseDate: _expenseDate,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el egreso: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<FinanceProvider>();

    return AlertDialog(
      title: const Text('Registrar egreso'),
      content: SizedBox(
        width: 520,
        child: _loadingSucursales
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Monto',
                          prefixText: 'Bs ',
                        ),
                        validator: (value) {
                          final amount = double.tryParse(
                            value?.trim().replaceAll(',', '.') ?? '',
                          );
                          if (amount == null || amount <= 0) {
                            return 'Ingresa un monto válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          hintText:
                              'Ej. compra de insumos, alquiler, movilidad',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La descripción es obligatoria';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedSucursalId,
                        decoration: const InputDecoration(
                          labelText: 'Sucursal',
                        ),
                        items: _sucursales.map<DropdownMenuItem<int>>((s) {
                          return DropdownMenuItem<int>(
                            value: s['id'] as int,
                            child: Text(s['nombreSucursal']?.toString() ?? '-'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSucursalId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) return 'Selecciona una sucursal';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickExpenseDate,
                        borderRadius: BorderRadius.circular(16),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha del egreso',
                            suffixIcon: Icon(Icons.calendar_today_rounded),
                          ),
                          child: Text(
                            DateFormat('dd/MM/yyyy', 'es').format(_expenseDate),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          hintText: 'Ej. Insumos, Alquiler, Sueldos',
                        ),
                        onChanged: _searchCategories,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La categoría es obligatoria';
                          }
                          return null;
                        },
                      ),
                      if (_loadingSuggestions) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                      if (_categorySuggestions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Sugerencias',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categorySuggestions.map((item) {
                            final name = item['nombre']?.toString() ?? '';
                            return ActionChip(
                              label: Text(name),
                              backgroundColor: cs.surfaceContainerHigh,
                              onPressed: () {
                                setState(() {
                                  _categoryController.text = name;
                                  _categorySuggestions = [];
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Si la categoría no existe, se creará automáticamente.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: provider.isSavingExpense
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: provider.isSavingExpense ? null : _submit,
          child: provider.isSavingExpense
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double amount;
  final IconData icon;
  final Color accentColor;

  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _currency(amount),
                  style: textTheme.displaySmall?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
        ],
      ),
    );
  }
}

class _BranchTotalsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List items;
  final String emptyText;
  final double? totalOverride;

  const _BranchTotalsSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
    this.totalOverride,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = totalOverride ?? _sumItems(items);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _currency(total),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(
              emptyText,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            )
          else
            ...items.map((item) {
              final map = item as Map;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        map['sucursal_nombre']?.toString() ?? 'Sin sucursal',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _currency((map['total'] as num?)?.toDouble() ?? 0.0),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  double _sumItems(List items) {
    return items.fold<double>(0, (sum, item) {
      final map = item as Map;
      return sum + ((map['total'] as num?)?.toDouble() ?? 0.0);
    });
  }
}

class _RecentMovementsSection extends StatelessWidget {
  final List items;

  const _RecentMovementsSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: cs.primary),
              const SizedBox(width: 10),
              Text(
                'Movimientos recientes',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(
              'No hay movimientos recientes.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            )
          else
            ...items.map((item) {
              final map = item as Map;
              final isIngreso = map['tipo'] == 'ingreso';
              final tone = isIngreso ? cs.primary : cs.error;
              final fecha = _formatDate(map['fecha']?.toString());
              final descripcion = _buildMovementDescription(map);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isIngreso
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        color: tone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: tone.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  isIngreso ? 'Ingreso' : 'Egreso',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: tone,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  fecha,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            map['sucursal_nombre']?.toString() ??
                                'Sin sucursal',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            descripcion,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _currency((map['monto'] as num?)?.toDouble() ?? 0.0),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: tone,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _buildMovementDescription(Map map) {
    final tipo = map['tipo']?.toString();
    if (tipo == 'ingreso') {
      final metodo = map['metodo_pago']?.toString();
      final referencia = map['referencia_id']?.toString();
      final metodoLabel = metodo == null || metodo.isEmpty
          ? 'Pago registrado'
          : 'Pago $metodo';
      if (referencia == null || referencia.isEmpty) return metodoLabel;
      return '$metodoLabel · ticket $referencia';
    }

    final descripcion = map['descripcion']?.toString() ?? '';
    return descripcion.isEmpty ? 'Egreso registrado' : descripcion;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return DateFormat('dd/MM/yyyy HH:mm', 'es').format(date.toLocal());
  }
}

String _currency(double amount) {
  return 'Bs ${NumberFormat('#,##0.00', 'es_BO').format(amount)}';
}
