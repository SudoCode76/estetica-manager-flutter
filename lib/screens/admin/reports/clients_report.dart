import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'report_period.dart';

class ClientsReport extends StatelessWidget {
  final ReportPeriod period;
  final Map<String, dynamic> data;
  const ClientsReport({super.key, required this.period, required this.data});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final surface = Theme.of(context).colorScheme.surface;

    final atendidos = (data['atendidos'] as num?)?.toInt() ?? 0;
    final nuevos = (data['nuevos'] as num?)?.toInt() ?? 0;
    final recurrentesPct =
        (data['recurrentes_pct'] as num?)?.toDouble() ?? 0.0;

    // Datos normalizados para el gráfico
    final rawChart = (data['chart_data'] as List?) ?? [];
    final List<Map<String, dynamic>> chartData = rawChart
        .map<Map<String, dynamic>>((e) {
          final label =
              (e is Map && e['label'] != null) ? e['label'].toString() : '';
          final value = (e is Map && e['value'] is num)
              ? (e['value'] as num).toDouble()
              : 0.0;
          final translated = (period == ReportPeriod.week)
              ? _weekdayLabelEs(label)
              : label;
          return {'label': translated, 'value': value};
        })
        .toList();

    final topClients = (data['top_clientes'] as List?) ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),

          // CARD PRINCIPAL
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CLIENTES CON TICKET',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primary.withAlpha((0.08 * 255).toInt()),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.confirmation_number_outlined,
                        color: cs.primary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$atendidos',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (atendidos > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withAlpha((0.08 * 255).toInt()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+12%',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // GRÁFICO DINÁMICO
                SizedBox(
                  height: 120,
                  child: chartData.isEmpty
                      ? Center(
                          child: Text(
                            "Sin actividad",
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      : BarChart(
                          BarChartData(
                            barGroups: List.generate(chartData.length, (i) {
                              final val = chartData[i]['value'] as double;
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: val,
                                    color: cs.primary.withAlpha(
                                      (0.6 * 255).toInt(),
                                    ),
                                    width: 18,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ],
                              );
                            }),
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => cs.primaryContainer,
                                tooltipBorderRadius:
                                    BorderRadius.circular(12),
                                getTooltipItem: (
                                  group,
                                  groupIndex,
                                  rod,
                                  rodIndex,
                                ) {
                                  return BarTooltipItem(
                                    '${rod.toY.toInt()} clientes',
                                    TextStyle(
                                      color: cs.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              show: true,
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
                                      if (chartData.length > 7 &&
                                          idx % 2 != 0) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          chartData[idx]['label'] as String,
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                  reservedSize: 20,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            alignment: BarChartAlignment.spaceAround,
                          ),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              // CARD NUEVOS
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NUEVOS',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '$nuevos',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (period == ReportPeriod.today)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "HOY",
                                style: TextStyle(
                                  fontSize: 9,
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Registrados\nen este periodo',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          height: 1.2,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // CARD RECURRENTES
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'RECURRENTES',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 70,
                        width: 70,
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                '${(recurrentesPct * 100).toInt()}%',
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              height: 70,
                              child: CircularProgressIndicator(
                                value: recurrentesPct,
                                color: cs.primary,
                                backgroundColor: cs.surfaceContainerHigh,
                                strokeWidth: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Fidelización',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // LISTA TOP CLIENTES
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Top Clientes',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'Ver todo',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (topClients.isEmpty)
                  Center(
                    child: Text(
                      "Sin datos",
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ...topClients.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final c = entry.value;
                  final amount = (c['amount'] as num).toDouble();
                  final maxVal = topClients
                      .map((e) => (e['amount'] as num).toDouble())
                      .reduce((a, b) => a > b ? a : b);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              idx.toString().padLeft(2, '0'),
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                (c['name']?.toString() ?? 'Cliente'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              'Bs ${amount.toInt()}',
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: amount / (maxVal == 0 ? 1 : maxVal),
                            color: cs.primary,
                            backgroundColor: cs.primary.withAlpha(
                              (0.08 * 255).toInt(),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
