import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'report_period.dart';

class FinancialReport extends StatelessWidget {
  final ReportPeriod period;
  final Map<String, dynamic> data;
  const FinancialReport({super.key, required this.period, required this.data});

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
          final translated = (period == ReportPeriod.week)
              ? _weekdayLabelEs(label)
              : label;
          return {'label': translated, 'value': value};
        })
        .toList();
    final topTratamientos = (data['top_tratamientos'] as List?) ?? [];
    final pendientes = (data['pendientes_cobro'] as List?) ?? [];

    String chartLabel = '';
    switch (period) {
      case ReportPeriod.today:
        chartLabel = 'Por hora';
        break;
      case ReportPeriod.week:
        chartLabel = 'Por día';
        break;
      case ReportPeriod.month:
        chartLabel = 'Por día del mes';
        break;
      case ReportPeriod.year:
        chartLabel = 'Por mes';
        break;
    }

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
                // Cards horizontales con Totales por Método
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: _PaymentMethodCard(
                        context,
                        label: 'Total QR',
                        amount: totalQr,
                        icon: Icons.qr_code,
                        color: cs.primary,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: _PaymentMethodCard(
                        context,
                        label: 'Total Efectivo',
                        amount: totalEfectivo,
                        icon: Icons.payments,
                        color: cs.secondary ?? cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Text(
                  'Tendencia ($chartLabel)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // GRÁFICO
                SizedBox(
                  height: 180,
                  child: chartData.isEmpty
                      ? const Center(
                          child: Text(
                            "Sin movimientos",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : BarChart(
                          BarChartData(
                            barGroups: _buildChartGroups(chartData, cs),
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    final idx = val.toInt();
                                    if (idx >= 0 && idx < chartData.length) {
                                      // Mostrar solo algunas etiquetas para que no se amontonen
                                      if (chartData.length > 7 && idx % 2 != 0)
                                        return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          chartData[idx]['label'].toString(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.bold,
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        "No se registraron ventas",
                        style: TextStyle(color: Colors.grey),
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
  Widget _PaymentMethodCard(
    BuildContext context, {
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.12),
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
              color: Colors.grey.shade200,
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

  Widget _buildDebtRow(BuildContext context, Map p) {
    final amount = (p['amount'] as num).toDouble();
    String fechaStr = '-';

    // Formatear fecha amigable
    if (p['date'] != null) {
      try {
        final dt = DateTime.parse(p['date'].toString());
        final now = DateTime.now();
        final diff = now.difference(dt).inDays;

        if (diff == 0)
          fechaStr = 'Hoy';
        else if (diff == 1)
          fechaStr = 'Ayer';
        else if (diff < 7)
          fechaStr = 'Hace $diff días';
        else
          fechaStr = DateFormat('dd MMM', 'es').format(dt);
      } catch (_) {}
    }

    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p['name'] ?? 'Cliente',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fechaStr,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
          Text(
            'Bs ${NumberFormat('#,##0.00', 'es_BO').format(amount)}',
            style: TextStyle(
              color: cs.error,
              fontWeight: FontWeight.bold,
              fontSize: 16,
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
