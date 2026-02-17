import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'report_period.dart';

class ServicesReport extends StatelessWidget {
  final ReportPeriod period;
  final Map<String, dynamic> data;
  const ServicesReport({super.key, required this.period, required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surface = cs.surface;

    final completados = (data['completados'] as num?)?.toInt() ?? 0;
    final chartData = (data['chart_data'] as List?) ?? [];
    final topServicios = (data['top_servicios'] as List?) ?? [];
    final ingresos = (data['ingresos_detalle'] as List?) ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),

          // HEADER TREND
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
                  'TRATAMIENTOS COMPLETADOS',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$completados',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tendencia reciente',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 140,
                  child: chartData.isEmpty
                      ? Center(
                          child: Text(
                            'Sin datos',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            minX: 0,
                            maxX: (chartData.length - 1).toDouble(),
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineTouchData: const LineTouchData(enabled: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(chartData.length, (i) {
                                  final value =
                                      (chartData[i]['value'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  return FlSpot(i.toDouble(), value);
                                }),
                                isCurved: true,
                                color: cs.primary,
                                barWidth: 3,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      cs.primary.withAlpha((0.3 * 255).toInt()),
                                      cs.primary.withAlpha(
                                        (0.02 * 255).toInt(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // TOP TRATAMIENTOS
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
                      'Top Tratamientos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: cs.onSurface,
                      ),
                    ),
                    Icon(Icons.more_horiz, color: cs.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 20),
                if (topServicios.isEmpty) const Text("Sin datos"),
                ...topServicios.map((s) {
                  final count = (s['count'] as num?)?.toInt() ?? 0;
                  // Calculamos el máximo localmente para la barra de progreso
                  final maxVal = topServicios
                      .map((e) => (e['count'] as num?)?.toDouble() ?? 0.0)
                      .reduce((a, b) => a > b ? a : b);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                s['name'] ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              '$count',
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxVal == 0 ? 0 : count / maxVal,
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

          // SECCIÓN DE CATEGORÍAS ELIMINADA AQUÍ
          const SizedBox(height: 16),

          // DETALLE INGRESOS
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
                      'Detalle de Ingresos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'Ver Todo',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (ingresos.isEmpty) const Text("No hay ingresos recientes"),
                ...ingresos
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: cs.primary.withAlpha(
                                (0.12 * 255).toInt(),
                              ),
                              radius: 22,
                              child: Icon(
                                Icons.monetization_on_rounded,
                                color: cs.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] ?? 'Servicio',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['subtitle'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Bs ${((item['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
