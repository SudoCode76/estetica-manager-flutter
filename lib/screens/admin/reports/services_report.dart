import 'package:flutter/material.dart';
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

          // HEADER CHART (reemplazo simple)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TRATAMIENTOS COMPLETADOS', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Text('$completados', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2C))),
              const SizedBox(height: 20),

              // Simple bar representation using Rows and Containers (no pointer listeners)
              SizedBox(
                height: 120,
                child: _simpleBarVisualization(chartData, Theme.of(context)),
              ),
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
              ...topServicios.map((s) {
                final count = (s['count'] as num?)?.toInt() ?? 0;
                final maxVal = topServicios.isEmpty ? 1.0 : topServicios.map((e) => (e['count'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a > b ? a : b);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Flexible(child: Text(s['name'] ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('$count', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: count / (maxVal == 0 ? 1 : maxVal), color: const Color(0xFF9FA8DA), backgroundColor: const Color(0xFFE8EAF6), minHeight: 6),
                    )
                  ]),
                );
              }),
            ]),
          ),

          const SizedBox(height: 16),

          // CATEGORIAS (reemplazo PieChart por lista y mini circulos)
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
                    child: _simplePieLegend(categorias),
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
              )),
            ]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Simple bar visualization made of columns
  Widget _simpleBarVisualization(List data, ThemeData theme) {
    if (data.isEmpty) return const Center(child: Text('No data'));

    // Normalize values
    final values = data.map((e) => (e['value'] as num?)?.toDouble() ?? 0.0).toList();
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(values.length, (i) {
        final v = values[i];
        final heightFactor = maxVal == 0 ? 0.0 : (v / maxVal);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: 100 * heightFactor,
                  decoration: BoxDecoration(color: const Color(0xFF9FA8DA), borderRadius: BorderRadius.circular(6)),
                ),
                const SizedBox(height: 6),
                Text(data[i]['label']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey))
              ],
            ),
          ),
        );
      }),
    );
  }

  // Simple legend circle stack for categories
  Widget _simplePieLegend(List categorias) {
    if (categorias.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(categorias.length, (i) {
        final color = i == 0 ? const Color(0xFF7B61FF) : (i == 1 ? const Color(0xFFB39DDB) : const Color(0xFFE1BEE7));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Container(width: 18, height: 18, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Flexible(child: Text(categorias[i]['name'] ?? '', overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
      }),
    );
  }
}
