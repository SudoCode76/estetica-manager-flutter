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
    final chartData = (data['chart_data'] as List?) ?? [];
    final topTratamientos = (data['top_tratamientos'] as List?) ?? [];
    final pendientes = (data['pendientes_cobro'] as List?) ?? [];

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
                Text('Ingresos', style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(20)),
                  child: const Text('+12%', style: TextStyle(color: Color(0xFF00695C), fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ]),
              const SizedBox(height: 8),
              Text('Bs ${NumberFormat('#,##0.00', 'es_BO').format(ingresos)}', style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF2D2D3A), fontSize: 32)),
              const SizedBox(height: 32),

              // GRÁFICO BAR CHART
              SizedBox(
                height: 180,
                child: IgnorePointer(
                  ignoring: true,
                  child: BarChart(BarChartData(
                    barGroups: _buildChartGroups(chartData),
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < chartData.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(chartData[idx]['label'].toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(enabled: false),
                  )),
                ),
              )
            ]),
          ),

          const SizedBox(height: 20),

          // TOP TRATAMIENTOS
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tratamientos más vendidos', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF2D2D3A))),
              const SizedBox(height: 24),
              if (topTratamientos.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Sin datos")))
              else
                ...topTratamientos.map((t) {
                  final count = (t['count'] as num).toInt();
                  final maxVal = topTratamientos.map((e) => (e['count'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
                  return _buildProgressRow(t['name'] ?? '', count, maxVal);
                }),
            ]),
          ),

          const SizedBox(height: 20),

          // PENDIENTES
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Pendientes de Cobro', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF2D2D3A))),
                const Text('Ver todos', style: TextStyle(color: Color(0xFF7B61FF), fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),
              if (pendientes.isEmpty)
                const Padding(padding: EdgeInsets.all(8.0), child: Text("Todo al día"))
              else
                ...pendientes.map((p) => _buildDebtRow(p)),
            ]),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildChartGroups(List data) {
    if (data.isEmpty) return [];
    return List.generate(data.length, (i) {
      final val = (data[i]['value'] as num).toDouble();
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: val,
          color: const Color(0xFF7B61FF),
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          backDrawRodData: BackgroundBarChartRodData(show: true, toY: val == 0 ? 100 : val * 1.2, color: const Color(0xFFF3F3F3)),
        )
      ]);
    });
  }

  Widget _buildProgressRow(String name, int count, double max) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D2D3A))),
          Text('$count sesiones', style: const TextStyle(color: Color(0xFF2D2D3A), fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: max == 0 ? 0 : count / max,
            color: const Color(0xFF7B61FF),
            backgroundColor: const Color(0xFFEEEAFF),
            minHeight: 8,
          ),
        )
      ]),
    );
  }

  Widget _buildDebtRow(Map p) {
    final amount = (p['amount'] as num).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Fecha: ${p['date']?.toString().substring(0, 10) ?? '-'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        Text('Bs ${NumberFormat('#,##0.00', 'es_BO').format(amount)}', style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 15)),
      ]),
    );
  }
}
