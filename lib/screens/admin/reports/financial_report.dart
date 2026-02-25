import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:app_estetica/providers/reports_provider.dart';
import 'report_period.dart';

class FinancialReport extends StatelessWidget {
  /// Período clásico activo. `null` cuando se navega con DateNavBar.
  final ReportPeriod? period;

  /// Modo de fecha activo (period / singleDay / dateRange / monthPick / yearPick).
  final ReportDateMode dateMode;

  /// Granularidad del gráfico calculada por el provider.
  final ChartGranularity chartGranularity;

  final Map<String, dynamic> data;

  const FinancialReport({
    super.key,
    required this.period,
    required this.dateMode,
    required this.chartGranularity,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final ingresos = (data['ingresos'] as num?)?.toDouble() ?? 0.0;
    final totalQr = (data['total_qr'] as num?)?.toDouble() ?? 0.0;
    final totalEfectivo = (data['total_efectivo'] as num?)?.toDouble() ?? 0.0;
    final rawChart = (data['chart_data'] as List?) ?? [];
    final List<Map<String, dynamic>> chartData = rawChart
        .map<Map<String, dynamic>>((e) {
          final label = (e is Map && e['label'] != null)
              ? e['label'].toString()
              : '';
          final value = (e is Map && e['value'] is num)
              ? (e['value'] as num).toDouble()
              : 0.0;
          // Traducir días de la semana en inglés solo cuando aplica
          final translated =
              (chartGranularity == ChartGranularity.daily &&
                  period == ReportPeriod.week)
              ? _weekdayLabelEs(label)
              : label;
          return {'label': translated, 'value': value};
        })
        .toList();
    final topTratamientos = (data['top_tratamientos'] as List?) ?? [];

    // Etiqueta del eje del gráfico según la granularidad.
    String chartLabel;
    switch (chartGranularity) {
      case ChartGranularity.hourly:
        chartLabel = 'Por hora';
        break;
      case ChartGranularity.daily:
        chartLabel = 'Por día';
        break;
      case ChartGranularity.monthly:
        chartLabel = 'Por día del mes';
        break;
      case ChartGranularity.yearly:
        chartLabel = 'Por mes';
        break;
      case ChartGranularity.none:
        chartLabel = '';
        break;
    }

    // ¿Mostrar el gráfico?
    final showChart = chartGranularity != ChartGranularity.none;

    // Normalizar chartData a lista de {label, value}
    // (chartData se usa directamente en la UI/Gráfico)

    final cs = Theme.of(context).colorScheme;
    final surface = cs.surface;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // CARD INGRESOS
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingresos Totales',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bs ${NumberFormat('#,##0.00', 'es_BO').format(ingresos)}',
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 12),

                const SizedBox(height: 12),
                // Layout: mostrar totales por método a la derecha del gráfico en pantallas anchas
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 700;

                    // Widget de gráfico o mensaje de "rango muy amplio"
                    Widget chartWidget = showChart
                        ? SizedBox(
                            height: 180,
                            child: chartData.isEmpty
                                ? Center(
                                    child: Text(
                                      'Sin movimientos',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                : BarChart(
                                    BarChartData(
                                      barGroups: _buildChartGroups(
                                        chartData,
                                        cs,
                                      ),
                                      gridData: const FlGridData(show: false),
                                      titlesData: FlTitlesData(
                                        leftTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (val, meta) {
                                              final idx = val.toInt();
                                              if (idx >= 0 &&
                                                  idx < chartData.length) {
                                                if (chartData.length > 7 &&
                                                    idx % 2 != 0) {
                                                  return const SizedBox.shrink();
                                                }
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8.0,
                                                      ),
                                                  child: Text(
                                                    chartData[idx]['label']
                                                        .toString(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                    ),
                                  ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withAlpha(120),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bar_chart_outlined,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'El rango seleccionado es mayor a 7 días — gráfico deshabilitado',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );

                    final rightColumn = ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Column(
                        children: [
                          _paymentMethodCard(
                            context,
                            label: 'Total QR',
                            amount: totalQr,
                            icon: Icons.qr_code,
                            color: cs.primary,
                          ),
                          const SizedBox(height: 12),
                          _paymentMethodCard(
                            context,
                            label: 'Total Efectivo',
                            amount: totalEfectivo,
                            icon: Icons.payments,
                            color: cs.secondary,
                          ),
                        ],
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          rightColumn,
                          const SizedBox(height: 12),
                          if (showChart) ...[
                            Text(
                              'Tendencia ($chartLabel)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          chartWidget,
                        ],
                      );
                    }

                    // Wide layout: chart left, cards right
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showChart) ...[
                                Text(
                                  'Tendencia ($chartLabel)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              chartWidget,
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        rightColumn,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // TOP TRATAMIENTOS
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tratamientos más vendidos',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 24),

                // Totales por método removidos de esta sección
                if (topTratamientos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        "No se registraron ventas",
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  ...topTratamientos.map((t) {
                    final count = (t['count'] as num).toInt();
                    // Calcular máximo para la barra de progreso relativa
                    final maxVal = topTratamientos
                        .map((e) => (e['count'] as num).toDouble())
                        .reduce((a, b) => a > b ? a : b);
                    return _buildTreatmentRow(
                      t['name'] ?? 'Tratamiento',
                      count,
                      maxVal,
                      textTheme,
                      cs,
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Pendientes de cobro removido (se muestra en otra parte si es necesario)
        ],
      ),
    );
  }

  // Small card to show payment method totals
  Widget _paymentMethodCard(
    BuildContext context, {
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: textTheme.bodySmall),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: amount),
                    duration: const Duration(milliseconds: 600),
                    builder: (ctx, value, _) {
                      return Text(
                        'Bs ${NumberFormat('#,##0.00', 'es_BO').format(value)}',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPERS UI ---

  double _calculateMaxY(List data) {
    if (data.isEmpty) return 100;
    final max = data
        .map((e) => (e['value'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
    return max == 0 ? 100 : max * 1.2; // 20% de margen arriba
  }

  List<BarChartGroupData> _buildChartGroups(List data, ColorScheme cs) {
    return List.generate(data.length, (i) {
      final val = (data[i]['value'] as num).toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: val,
            color: cs.primary,
            width: 32,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _calculateMaxY(data),
              color: cs.surfaceContainerHigh,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildTreatmentRow(
    String name,
    int count,
    double max,
    TextTheme textTheme,
    ColorScheme cs,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '$count sesiones',
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: max == 0 ? 0 : count / max,
              color: cs.primary, // Barra progreso según theme
              backgroundColor: cs.primary.withAlpha(
                (0.12 * 255).toInt(),
              ), // Fondo suave
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// Traduce etiquetas de días en inglés a abreviaturas en español (ej: Mon -> Lun)
String _weekdayLabelEs(String label) {
  final l = label.toLowerCase();
  if (l.startsWith('mon') || l == 'monday') return 'Lun';
  if (l.startsWith('tue') || l == 'tuesday') return 'Mar';
  if (l.startsWith('wed') || l == 'wednesday') return 'Mié';
  if (l.startsWith('thu') || l == 'thursday') return 'Jue';
  if (l.startsWith('fri') || l == 'friday') return 'Vie';
  if (l.startsWith('sat') || l == 'saturday') return 'Sáb';
  if (l.startsWith('sun') || l == 'sunday') return 'Dom';
  return label;
}
