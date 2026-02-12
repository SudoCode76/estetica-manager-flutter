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

    final atendidos = (data['atendidos'] as num?)?.toInt() ?? 0;
    final nuevos = (data['nuevos'] as num?)?.toInt() ?? 0;
    final recurrentesPct = (data['recurrentes_pct'] as num?)?.toDouble() ?? 0.0;

    // Datos normalizados para el gráfico
    final rawChart = (data['chart_data'] as List?) ?? [];
    final List<Map<String, dynamic>> chartData = rawChart.map<Map<String, dynamic>>((e) {
      final label = (e is Map && e['label'] != null) ? e['label'].toString() : '';
      final value = (e is Map && e['value'] is num) ? (e['value'] as num).toDouble() : 0.0;
      return {'label': label, 'value': value};
    }).toList();

    final topClients = (data['top_clientes'] as List?) ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),

          // CARD PRINCIPAL
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                // CAMBIO DE ETIQUETA AQUÍ:
                Text('CLIENTES CON TICKET', style: TextStyle(color: Colors.grey[600], fontSize: 12, letterSpacing: 0.5, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.confirmation_number_outlined, color: Color(0xFF9333EA), size: 20),
                )
              ]),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('$atendidos', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2C))),
                  const SizedBox(width: 10),
                  if (atendidos > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(12)),
                      child: const Text('+12%', style: TextStyle(color: Color(0xFF00695C), fontWeight: FontWeight.bold, fontSize: 11)),
                    )
                ],
              ),
              const SizedBox(height: 20),

              // GRÁFICO DINÁMICO
              SizedBox(
                height: 120,
                child: chartData.isEmpty
                  ? const Center(child: Text("Sin actividad", style: TextStyle(color: Colors.grey)))
                  : BarChart(BarChartData(
                      barGroups: List.generate(chartData.length, (i) {
                        final val = chartData[i]['value'] as double;
                        return BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: val,
                            color: const Color(0xFFD8B4FE), // Violeta suave
                            width: 18,
                            borderRadius: BorderRadius.circular(6)
                          )
                        ]);
                      }),
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        show: true,
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < chartData.length) {
                                // Mostrar etiquetas espaciadas si son muchas
                                if (chartData.length > 7 && idx % 2 != 0) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    chartData[idx]['label'] as String,
                                    style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                            reservedSize: 20
                          )
                        )
                      ),
                      borderData: FlBorderData(show: false),
                      alignment: BarChartAlignment.spaceAround,
                    )),
              )
            ]),
          ),

          const SizedBox(height: 16),

          Row(children: [
            // CARD NUEVOS
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('NUEVOS', style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('$nuevos', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      // Etiqueta dinámica
                      if (period == ReportPeriod.today)
                        Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(4)), child: const Text("HOY", style: TextStyle(fontSize: 9, color: Color(0xFF9333EA), fontWeight: FontWeight.bold)))
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Registrados\nen este periodo', style: TextStyle(color: Colors.grey, height: 1.2, fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(width: 16),

            // CARD RECURRENTES
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xFF9333EA), borderRadius: BorderRadius.circular(24)),
                child: Column(children: [
                  const Text('RECURRENTES', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 70, width: 70,
                    child: Stack(children: [
                      Center(child: Text('${(recurrentesPct * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                      SizedBox(
                        width: 70, height: 70,
                        child: CircularProgressIndicator(value: recurrentesPct, color: Colors.white, backgroundColor: Colors.white24, strokeWidth: 6),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const Text('Fidelización', style: TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
            )
          ]),

          const SizedBox(height: 16),

          // LISTA TOP CLIENTES
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Top Clientes', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF1E1E2C))),
                const Text('Ver todo', style: TextStyle(color: Color(0xFF9333EA), fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 24),
              if (topClients.isEmpty) const Center(child: Text("Sin datos", style: TextStyle(color: Colors.grey))),
              ...topClients.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final c = entry.value;
                final amount = (c['amount'] as num).toDouble();
                final maxVal = topClients.map((e) => (e['amount'] as num).toDouble()).fold<double>(0.0, (prev, el) => el > prev ? el : prev);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(children: [
                    Row(children: [
                      Text(idx.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Expanded(child: Text((c['name']?.toString() ?? 'Cliente'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                      Text('Bs ${amount.toInt()}', style: const TextStyle(color: Color(0xFF9333EA), fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: maxVal == 0 ? 0 : amount / maxVal, color: const Color(0xFF9333EA), backgroundColor: const Color(0xFFF3E8FF), minHeight: 6),
                    )
                  ]),
                );
              }).toList(),
            ]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
