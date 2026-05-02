import 'package:app_estetica/providers/finance_provider.dart';
import 'package:app_estetica/providers/reports_provider.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:app_estetica/repositories/catalog_repository.dart';
import 'package:app_estetica/widgets/finance_date_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum _OverviewTab { expenses, branch }

enum _MovementFilter { all, income, expense }

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  static const int _dayGroupsPageSize = 4;

  bool _requested = false;
  int _movementsPage = 0;
  _OverviewTab _overviewTab = _OverviewTab.expenses;
  _MovementFilter _movementFilter = _MovementFilter.all;
  final Set<String> _expandedDays = <String>{};

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
            (dashboard['ingresos_por_sucursal'] as List?) ?? const [];
        final egresosPorSucursal =
            (dashboard['egresos_por_sucursal'] as List?) ?? const [];
        final topCategoriasGastos =
            (dashboard['top_categorias_gastos'] as List?) ?? const [];
        final transaccionesPorDiaRaw =
            (dashboard['transacciones_por_dia'] as List?) ?? const [];

        final groupedDays = _buildDayGroupsFromBackend(transaccionesPorDiaRaw);
        final filteredDayGroups = _filterDayGroups(groupedDays);
        final totalMovementPages = filteredDayGroups.isEmpty
            ? 1
            : (filteredDayGroups.length / _dayGroupsPageSize).ceil();
        final safeMovementPage = _movementsPage.clamp(
          0,
          totalMovementPages - 1,
        );
        final startIndex = safeMovementPage * _dayGroupsPageSize;
        final endIndex = (startIndex + _dayGroupsPageSize).clamp(
          0,
          filteredDayGroups.length,
        );
        final pagedDayGroups = filteredDayGroups.isEmpty
            ? const <_MovementDayGroup>[]
            : filteredDayGroups.sublist(startIndex, endIndex);

        final expenseCategoryItems = _buildExpenseCategoryItems(
          topCategoriasGastos,
        );
        final branchItems = _buildBranchItems(
          ingresosPorSucursal,
          egresosPorSucursal,
        );

        if (provider.isLoading && !_hasData(dashboard)) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: provider.refreshCurrent,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                onDateChanged: (date) {
                  setState(() {
                    _movementsPage = 0;
                    _expandedDays.clear();
                  });
                  provider.fetchDashboardForDate(date);
                },
                onRangeChanged: (range) {
                  setState(() {
                    _movementsPage = 0;
                    _expandedDays.clear();
                  });
                  provider.fetchDashboardForRange(range);
                },
                onMonthChanged: (year, month) {
                  setState(() {
                    _movementsPage = 0;
                    _expandedDays.clear();
                  });
                  provider.fetchDashboardForMonth(year, month);
                },
                onYearChanged: (year) {
                  setState(() {
                    _movementsPage = 0;
                    _expandedDays.clear();
                  });
                  provider.fetchDashboardForYear(year);
                },
              ),
              const SizedBox(height: 18),
              _BalanceCard(
                totalIngresos: totalIngresos,
                totalEgresos: totalEgresos,
                periodLabel: _periodLabel(provider),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _AmountStatCard(
                      title: 'Ingresos',
                      amount: totalIngresos,
                      amountColor: const Color(0xFF2FBD78),
                      backgroundColor: const Color(0xFFE7FFF2),
                      icon: Icons.south_rounded,
                      iconColor: const Color(0xFF2FBD78),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AmountStatCard(
                      title: 'Gastos',
                      amount: totalEgresos,
                      amountColor: const Color(0xFFF05058),
                      backgroundColor: const Color(0xFFFFECEC),
                      icon: Icons.north_rounded,
                      iconColor: const Color(0xFFF05058),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _SectionHeader(
                title: _overviewTab == _OverviewTab.expenses
                    ? 'Top categorías'
                    : 'Resumen por sucursal',
                trailing: _overviewTab == _OverviewTab.expenses
                    ? Text(
                        '${expenseCategoryItems.length} categorías',
                        style: textTheme.titleSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : Text(
                        '${branchItems.length} sucursales',
                        style: textTheme.titleSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              _RoundedSegmentedContainer<_OverviewTab>(
                value: _overviewTab,
                values: const [_OverviewTab.expenses, _OverviewTab.branch],
                labelBuilder: (value) => switch (value) {
                  _OverviewTab.expenses => 'Gastos',
                  _OverviewTab.branch => 'Sucursal',
                },
                onChanged: (value) {
                  setState(() {
                    _overviewTab = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              if (_overviewTab == _OverviewTab.expenses)
                _BreakdownCard(
                  items: expenseCategoryItems,
                  emptyText: 'No hay gastos registrados en el período.',
                )
              else
                _BranchBreakdownCard(
                  items: branchItems,
                  emptyText: 'No hay movimientos por sucursal en el período.',
                ),
              const SizedBox(height: 26),
              const _SectionHeader(title: 'Transacciones por día'),
              const SizedBox(height: 14),
              _RoundedSegmentedContainer<_MovementFilter>(
                value: _movementFilter,
                values: const [
                  _MovementFilter.all,
                  _MovementFilter.income,
                  _MovementFilter.expense,
                ],
                labelBuilder: (value) => switch (value) {
                  _MovementFilter.all => 'Todos',
                  _MovementFilter.income => 'Ingresos',
                  _MovementFilter.expense => 'Gastos',
                },
                onChanged: (value) {
                  setState(() {
                    _movementFilter = value;
                    _movementsPage = 0;
                    _expandedDays.clear();
                  });
                },
              ),
              const SizedBox(height: 14),
              if (pagedDayGroups.isEmpty)
                _EmptyCard(
                  text: 'No hay transacciones para el filtro seleccionado.',
                )
              else
                ...pagedDayGroups.map(
                  (group) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DayTransactionGroupCard(
                      group: group,
                      isExpanded: _expandedDays.contains(group.key),
                      isBusy: provider.isSavingExpense,
                      onToggle: () {
                        setState(() {
                          if (_expandedDays.contains(group.key)) {
                            _expandedDays.remove(group.key);
                          } else {
                            _expandedDays.add(group.key);
                          }
                        });
                      },
                      onEditExpense: _showEditExpenseDialog,
                      onDeleteExpense: _confirmDeleteExpense,
                    ),
                  ),
                ),
              if (filteredDayGroups.length > _dayGroupsPageSize) ...[
                const SizedBox(height: 6),
                _CompactPaginationBar(
                  totalItems: filteredDayGroups.length,
                  currentPage: safeMovementPage,
                  totalPages: totalMovementPages,
                  onPreviousPage: safeMovementPage > 0
                      ? () {
                          setState(() {
                            _movementsPage = safeMovementPage - 1;
                            _expandedDays.clear();
                          });
                        }
                      : null,
                  onNextPage: safeMovementPage < totalMovementPages - 1
                      ? () {
                          setState(() {
                            _movementsPage = safeMovementPage + 1;
                            _expandedDays.clear();
                          });
                        }
                      : null,
                ),
              ],
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

  List<_BreakdownItem> _buildExpenseCategoryItems(List<dynamic> categories) {
    return categories.map<_BreakdownItem>((item) {
      return _BreakdownItem(
        label: item['label']?.toString() ?? 'Sin categoría',
        amount: (item['amount'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  List<_BranchBreakdownItem> _buildBranchItems(
    List ingresosPorSucursal,
    List egresosPorSucursal,
  ) {
    final map = <String, _BranchBreakdownItem>{};

    for (final item in ingresosPorSucursal) {
      final name = item['sucursal_nombre']?.toString() ?? 'Sin sucursal';
      final income = (item['total'] as num?)?.toDouble() ?? 0.0;
      map[name] = _BranchBreakdownItem(
        label: name,
        ingreso: income,
        egreso: map[name]?.egreso ?? 0.0,
      );
    }

    for (final item in egresosPorSucursal) {
      final name = item['sucursal_nombre']?.toString() ?? 'Sin sucursal';
      final expense = (item['total'] as num?)?.toDouble() ?? 0.0;
      map[name] = _BranchBreakdownItem(
        label: name,
        ingreso: map[name]?.ingreso ?? 0.0,
        egreso: expense,
      );
    }

    final items = map.values.toList();
    items.sort((a, b) => b.ingreso.compareTo(a.ingreso));
    return items;
  }

  List<_MovementDayGroup> _buildDayGroupsFromBackend(List<dynamic> rawItems) {
    final groups = rawItems.map<_MovementDayGroup>((item) {
      final map = item as Map;
      final rawDate = map['fecha']?.toString() ?? '';
      final date = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
      final movements = ((map['movimientos'] as List?) ?? const [])
          .map<Map<String, dynamic>>(
            (movement) => Map<String, dynamic>.from(movement as Map),
          )
          .toList();

      return _MovementDayGroup(
        key: map['key']?.toString() ?? DateFormat('yyyy-MM-dd').format(date),
        date: date,
        items: movements,
        total: (map['total'] as num?)?.toDouble() ?? 0.0,
        incomeCount: (map['ingresos_count'] as num?)?.toInt() ?? 0,
        expenseCount: (map['egresos_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }

  List<_MovementDayGroup> _filterDayGroups(List<_MovementDayGroup> groups) {
    if (_movementFilter == _MovementFilter.all) return groups;

    final wantedType = _movementFilter == _MovementFilter.income
        ? 'ingreso'
        : 'egreso';

    final filtered = <_MovementDayGroup>[];
    for (final group in groups) {
      final items = group.items
          .where((item) => item['tipo'] == wantedType)
          .toList();
      if (items.isEmpty) continue;

      final total = items.fold<double>(0, (sum, item) {
        final amount = (item['monto'] as num?)?.toDouble() ?? 0.0;
        return sum + (item['tipo'] == 'egreso' ? -amount : amount);
      });

      filtered.add(
        _MovementDayGroup(
          key: group.key,
          date: group.date,
          items: items,
          total: total,
          incomeCount: items.where((item) => item['tipo'] == 'ingreso').length,
          expenseCount: items.where((item) => item['tipo'] == 'egreso').length,
        ),
      );
    }

    return filtered;
  }

  String _periodLabel(FinanceProvider provider) {
    switch (provider.dateMode) {
      case ReportDateMode.singleDay:
      case ReportDateMode.period:
        final now = DateTime.now();
        final date = provider.selectedDate;
        if (date.year == now.year &&
            date.month == now.month &&
            date.day == now.day) {
          return 'Hoy';
        }
        return DateFormat('dd MMM yyyy', 'es').format(date);
      case ReportDateMode.dateRange:
        final range = provider.selectedRange;
        if (range == null) return 'Rango';
        return '${DateFormat('dd MMM', 'es').format(range.start)} - ${DateFormat('dd MMM yyyy', 'es').format(range.end)}';
      case ReportDateMode.monthPick:
        final month = provider.selectedMonth;
        if (month == null) return 'Mes';
        return DateFormat('MMMM yyyy', 'es').format(month);
      case ReportDateMode.yearPick:
        return 'Año ${provider.selectedYear ?? ''}'.trim();
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

  Future<void> _showEditExpenseDialog(Map movement) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _RegisterExpenseDialog(existingExpense: movement),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Egreso actualizado correctamente')),
      );
    }
  }

  Future<void> _confirmDeleteExpense(Map movement) async {
    final expenseId = movement['referencia_id']?.toString();
    if (expenseId == null || expenseId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar egreso'),
        content: const Text('¿Deseas eliminar este egreso?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<FinanceProvider>().deleteExpense(expenseId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Egreso eliminado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar el egreso: $e')),
      );
    }
  }
}

class _RegisterExpenseDialog extends StatefulWidget {
  final Map? existingExpense;

  const _RegisterExpenseDialog({this.existingExpense});

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
    _hydrateExistingExpense();
    _loadSucursales();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existingExpense != null;

  void _hydrateExistingExpense() {
    final expense = widget.existingExpense;
    if (expense == null) return;

    _amountController.text = ((expense['monto'] as num?)?.toDouble() ?? 0.0)
        .toStringAsFixed(2)
        .replaceAll('.', ',');
    _descriptionController.text = expense['descripcion']?.toString() ?? '';
    _categoryController.text = expense['categoria_nombre']?.toString() ?? '';
    _selectedSucursalId = expense['sucursal_id'] as int?;
    _expenseDate =
        DateTime.tryParse(expense['fecha']?.toString() ?? '')?.toLocal() ??
        DateTime.now();
  }

  Future<void> _loadSucursales() async {
    final catalogRepo = context.read<CatalogRepository>();
    final sucursalProvider = context.read<SucursalProvider>();

    try {
      final sucursales = await catalogRepo.getSucursales();
      if (!mounted) return;
      setState(() {
        _sucursales = sucursales;
        _selectedSucursalId ??= sucursalProvider.selectedSucursalId;
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
      if (_isEditing) {
        final expenseId = widget.existingExpense?['referencia_id']?.toString();
        if (expenseId == null || expenseId.isEmpty) {
          throw Exception('No se encontró el identificador del egreso');
        }
        await context.read<FinanceProvider>().updateExpense(
          expenseId: expenseId,
          amount: amount,
          description: _descriptionController.text.trim(),
          sucursalId: _selectedSucursalId!,
          categoryName: _categoryController.text.trim(),
          expenseDate: _expenseDate,
        );
      } else {
        await context.read<FinanceProvider>().registerExpense(
          amount: amount,
          description: _descriptionController.text.trim(),
          sucursalId: _selectedSucursalId!,
          categoryName: _categoryController.text.trim(),
          expenseDate: _expenseDate,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el egreso: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<FinanceProvider>();

    return AlertDialog(
      title: Text(_isEditing ? 'Editar egreso' : 'Registrar egreso'),
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
              : Text(_isEditing ? 'Actualizar' : 'Guardar'),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double totalIngresos;
  final double totalEgresos;
  final String periodLabel;

  const _BalanceCard({
    required this.totalIngresos,
    required this.totalEgresos,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final balance = totalIngresos - totalEgresos;
    final balanceColor = balance >= 0 ? cs.onPrimaryContainer : cs.error;

    return Material(
      color: Colors.transparent,
      elevation: 6,
      shadowColor: cs.shadow.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE2C8FF), Color(0xFFFFC7E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    periodLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(Icons.insights_rounded, color: cs.error, size: 24),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Balance actual',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _signedCurrency(balance),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: balanceColor,
                fontWeight: FontWeight.w900,
                fontSize: 50,
                height: 0.96,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.balance_rounded, color: balanceColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    balance >= 0 ? 'Resultado positivo' : 'Resultado negativo',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: balanceColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountStatCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color amountColor;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;

  const _AmountStatCard({
    required this.title,
    required this.amount,
    required this.amountColor,
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              _currency(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _RoundedSegmentedContainer<T> extends StatelessWidget {
  final T value;
  final List<T> values;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  const _RoundedSegmentedContainer({
    required this.value,
    required this.values,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: values.map((item) {
          final selected = item == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: selected ? cs.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: cs.shadow.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labelBuilder(item).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: selected ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final List<_BreakdownItem> items;
  final String emptyText;

  const _BreakdownCard({required this.items, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxAmount = items.isEmpty
        ? 0.0
        : items.first.amount <= 0
        ? 0.0
        : items.first.amount;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: items.isEmpty
            ? Text(
                emptyText,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              )
            : Column(
                children: items.map((item) {
                  final ratio = maxAmount == 0 ? 0.0 : item.amount / maxAmount;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _currency(item.amount),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: ratio.clamp(0.0, 1.0),
                            backgroundColor: cs.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}

class _BranchBreakdownCard extends StatelessWidget {
  final List<_BranchBreakdownItem> items;
  final String emptyText;

  const _BranchBreakdownCard({required this.items, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxAmount = items.isEmpty
        ? 0.0
        : items.first.ingreso <= 0
        ? 0.0
        : items.first.ingreso;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: items.isEmpty
            ? Text(
                emptyText,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              )
            : Column(
                children: items.map((item) {
                  final ratio = maxAmount == 0 ? 0.0 : item.ingreso / maxAmount;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _currency(item.ingreso),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF5A66F0),
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: ratio.clamp(0.0, 1.0),
                            backgroundColor: cs.surfaceContainerHighest,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF5A66F0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Egresos ${_currency(item.egreso)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}

class _DayTransactionGroupCard extends StatelessWidget {
  final _MovementDayGroup group;
  final bool isExpanded;
  final bool isBusy;
  final VoidCallback onToggle;
  final Future<void> Function(Map movement) onEditExpense;
  final Future<void> Function(Map movement) onDeleteExpense;

  const _DayTransactionGroupCard({
    required this.group,
    required this.isExpanded,
    required this.isBusy,
    required this.onToggle,
    required this.onEditExpense,
    required this.onDeleteExpense,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalColor = group.total >= 0
        ? const Color(0xFF5A66F0)
        : const Color(0xFFF05058);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 74,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat(
                            'MMM',
                            'es',
                          ).format(group.date).toUpperCase(),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFF6C76F4),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          DateFormat('dd').format(group.date),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${group.items.length} transacción${group.items.length == 1 ? '' : 'es'}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${group.items.length} movimiento${group.items.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _signedCurrency(group.total),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: totalColor,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Column(
                children: group.items.map((movement) {
                  final isIngreso = movement['tipo'] == 'ingreso';
                  final iconColor = isIngreso
                      ? const Color(0xFF24B9D6)
                      : const Color(0xFFF27A47);
                  final bgColor = isIngreso
                      ? const Color(0xFFE8F8FD)
                      : const Color(0xFFFFEEE8);
                  final amount = (movement['monto'] as num?)?.toDouble() ?? 0.0;
                  final amountText = isIngreso
                      ? '+${_currency(amount)}'
                      : '-${_currency(amount)}';
                  final title = _buildMovementTitle(movement);
                  final subtitle = _buildMovementSubtitle(movement);
                  final amountColor = isIngreso
                      ? const Color(0xFF5A66F0)
                      : const Color(0xFFF05058);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: bgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isIngreso
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: iconColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              amountText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: amountColor,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            if (movement['tipo'] == 'egreso')
                              PopupMenuButton<String>(
                                enabled: !isBusy,
                                padding: EdgeInsets.zero,
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    onEditExpense(movement);
                                    return;
                                  }
                                  if (value == 'delete') {
                                    onDeleteExpense(movement);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Text('Editar'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text('Eliminar'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildMovementTitle(Map movement) {
    if (movement['tipo'] == 'egreso') {
      final category = movement['categoria_nombre']?.toString();
      if (category != null && category.trim().isNotEmpty) {
        return category.trim();
      }
      final description = movement['descripcion']?.toString();
      if (description != null && description.trim().isNotEmpty) {
        return description.trim();
      }
      return 'Egreso';
    }

    final method = movement['metodo_pago']?.toString();
    if (method != null && method.isNotEmpty) {
      return 'Pago ${method.toUpperCase()}';
    }
    return 'Ingreso';
  }

  String? _buildMovementSubtitle(Map movement) {
    if (movement['tipo'] == 'egreso') {
      final description = movement['descripcion']?.toString().trim() ?? '';
      final category = movement['categoria_nombre']?.toString().trim() ?? '';
      final branch = movement['sucursal_nombre']?.toString().trim() ?? '';

      final parts = <String>[];
      if (description.isNotEmpty && description != category)
        parts.add(description);
      if (branch.isNotEmpty) parts.add(branch);
      return parts.isEmpty ? null : parts.join(' · ');
    }

    final branch = movement['sucursal_nombre']?.toString().trim() ?? '';
    final reference = movement['referencia_id']?.toString().trim() ?? '';
    final refLabel = reference.isEmpty ? '' : 'ticket $reference';
    final parts = <String>[];
    if (branch.isNotEmpty) parts.add(branch);
    if (refLabel.isNotEmpty) parts.add(refLabel);
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _CompactPaginationBar extends StatelessWidget {
  final int totalItems;
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  const _CompactPaginationBar({
    required this.totalItems,
    required this.currentPage,
    required this.totalPages,
    this.onPreviousPage,
    this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        FilledButton.tonalIcon(
          onPressed: onPreviousPage,
          icon: const Icon(Icons.chevron_left_rounded),
          label: const Text('Anterior'),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$totalItems días · ${currentPage + 1}/$totalPages',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.onSecondaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
        FilledButton.tonalIcon(
          onPressed: onNextPage,
          label: const Text('Siguiente'),
          icon: const Icon(Icons.chevron_right_rounded),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _BreakdownItem {
  final String label;
  final double amount;

  const _BreakdownItem({required this.label, required this.amount});
}

class _BranchBreakdownItem {
  final String label;
  final double ingreso;
  final double egreso;

  const _BranchBreakdownItem({
    required this.label,
    required this.ingreso,
    required this.egreso,
  });
}

class _MovementDayGroup {
  final String key;
  final DateTime date;
  final List<Map<String, dynamic>> items;
  final double total;
  final int incomeCount;
  final int expenseCount;

  const _MovementDayGroup({
    required this.key,
    required this.date,
    required this.items,
    required this.total,
    required this.incomeCount,
    required this.expenseCount,
  });
}

String _currency(double amount) {
  return 'Bs. ${NumberFormat('#,##0.00', 'es_BO').format(amount)}';
}

String _signedCurrency(double amount) {
  final abs = 'Bs. ${NumberFormat('#,##0.00', 'es_BO').format(amount.abs())}';
  if (amount < 0) return '-$abs';
  if (amount > 0) return '+$abs';
  return abs;
}
