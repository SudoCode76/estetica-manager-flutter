import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'report_period.dart';

class ServicesReport extends StatelessWidget {
  final ReportPeriod period;
  final Map<String, dynamic> data;
  const ServicesReport({super.key, required this.period, required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completados = (data['completados'] as num?)?.toInt() ?? 0;
    final chartData = (data['chart_data'] as List?) ?? [];
    final topServicios = (data['top_servicios'] as List?) ?? [];
    final categorias = (data['categorias'] as List?) ?? [];
    final ingresos = (data['ingresos_detalle'] as List?) ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),

          // HEADER CHART
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TRATAMIENTOS COMPLETADOS', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Text('$completados', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2C))),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                child: chartData.isEmpty
                    ? Center(child: Text('Sin datos', style: TextStyle(color: Colors.grey[500])))
                    : BarChart(BarChartData(
                        barGroups: List.generate(chartData.length, (i) {
                          final val = (chartData[i]['value'] as num).toDouble();
                          return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: val, color: const Color(0xFF9FA8DA), width: 14, borderRadius: BorderRadius.circular(6))]);
                        }),
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                      )),
              )
            ]),
          ),

          const SizedBox(height: 16),

          // TOP TRATAMIENTOS
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Top Tratamientos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Icon(Icons.more_horiz, color: Colors.grey),
              ]),
              const SizedBox(height: 20),
              if (topServicios.isEmpty) const Text("Sin datos"),
              ...topServicios.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(child: Text(s['name'] ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('${s['count']}', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: (s['count'] as num).toDouble() / 20, color: const Color(0xFF9FA8DA), backgroundColor: const Color(0xFFE8EAF6), minHeight: 6),
                  )
                ]),
              )).toList(),
            ]),
          ),

          const SizedBox(height: 16),

          // CATEGORIAS (Pie Chart)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Categorías', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              if (categorias.isEmpty)
                const Text("Sin datos")
              else
                Row(children: [
                  SizedBox(
                    height: 120, width: 120,
                    child: PieChart(PieChartData(
                      sections: List.generate(categorias.length, (i) {
                        final val = (categorias[i]['count'] as num).toDouble();
                        return PieChartSectionData(value: val, color: i==0 ? const Color(0xFF7B61FF) : (i==1 ? const Color(0xFFB39DDB) : const Color(0xFFE1BEE7)), radius: 15, showTitle: false);
                      }),
                      centerSpaceRadius: 40,
                      sectionsSpace: 4,
                    )),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: categorias.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF7B61FF))),
                            const SizedBox(width: 8),
                            Flexible(child: Text(c['name'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                          ]),
                          Text('${(c['count'] as num).toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                      )).toList(),
                    ),
                  )
                ]),
            ]),
          ),

          const SizedBox(height: 16),

          // DETALLE INGRESOS
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Detalle de Ingresos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Ver Todo', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 20),
              if (ingresos.isEmpty) const Text("No hay ingresos recientes"),
              ...ingresos.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Row(children: [
                  CircleAvatar(backgroundColor: const Color(0xFFEDE7F6), radius: 22, child: Icon(Icons.monetization_on_rounded, color: cs.primary, size: 20)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['title'] ?? 'Servicio', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(item['subtitle'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ])),
                  Text('Bs ${((item['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
              )).toList(),
            ]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
