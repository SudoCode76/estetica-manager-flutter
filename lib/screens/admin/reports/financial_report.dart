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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // CARD INGRESOS
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ingresos Totales', style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text('Bs ${NumberFormat('#,##0.00', 'es_BO').format(ingresos)}', style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF1E1E2C), fontSize: 32)),
              const SizedBox(height: 24),

              Text('Tendencia ($chartLabel)', style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // GRÁFICO
              SizedBox(
                height: 180,
                child: chartData.isEmpty
                    ? const Center(child: Text("Sin movimientos", style: TextStyle(color: Colors.grey)))
                    : BarChart(BarChartData(
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
                                // Mostrar solo algunas etiquetas para que no se amontonen
                                if (chartData.length > 7 && idx % 2 != 0) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(chartData[idx]['label'].toString(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                );
                              }
                              return const SizedBox.shrink();
                            }),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                      )),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // TOP TRATAMIENTOS
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tratamientos más vendidos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2C)),
                ),
                const SizedBox(height: 24),

                if (topTratamientos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("No se registraron ventas", style: TextStyle(color: Colors.grey))),
                  )
                else
                  ...topTratamientos.map((t) {
                    final count = (t['count'] as num).toInt();
                    // Calcular máximo para la barra de progreso relativa
                    final maxVal = topTratamientos.map((e) => (e['count'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
                    return _buildTreatmentRow(t['name'] ?? 'Tratamiento', count, maxVal);
                  }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- 3. PENDIENTES DE COBRO ---
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pendientes de Cobro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2C))),
                    TextButton(
                      onPressed: () {}, // Navegar a lista completa si deseas
                      child: const Text('Ver todos', style: TextStyle(color: Color(0xFF7B61FF), fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 8),

                if (pendientes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("¡Todo al día! No hay deudas.", style: TextStyle(color: Colors.grey)),
                  )
                else
                  ...pendientes.map((p) => _buildDebtRow(p)),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --- HELPERS UI ---

  double _calculateMaxY(List data) {
    if (data.isEmpty) return 100;
    final max = data.map((e) => (e['value'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    return max == 0 ? 100 : max * 1.2; // 20% de margen arriba
  }

  List<BarChartGroupData> _buildChartGroups(List data) {
    return List.generate(data.length, (i) {
      final val = (data[i]['value'] as num).toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: val,
            color: const Color(0xFF7B61FF), // Morado principal del diseño
            width: 32, // Barras anchas como en la foto
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _calculateMaxY(data), // Fondo gris hasta el tope
              color: const Color(0xFFF5F5FA) // Gris muy claro de fondo
            ),
          )
        ]
      );
    });
  }

  Widget _buildTreatmentRow(String name, int count, double max) {
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
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E1E2C), fontSize: 15)
                )
              ),
              Text(
                '$count sesiones',
                style: const TextStyle(color: Color(0xFF1E1E2C), fontWeight: FontWeight.bold, fontSize: 14)
              ),
            ]
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: max == 0 ? 0 : count / max,
              color: const Color(0xFF7B61FF), // Barra progreso morada
              backgroundColor: const Color(0xFFEEEAFF), // Fondo lila suave
              minHeight: 10,
            ),
          )
        ]
      ),
    );
  }

  Widget _buildDebtRow(Map p) {
    final amount = (p['amount'] as num).toDouble();
    String fechaStr = '-';

    // Formatear fecha amigable
    if (p['date'] != null) {
      try {
        final dt = DateTime.parse(p['date'].toString());
        final now = DateTime.now();
        final diff = now.difference(dt).inDays;

        if (diff == 0) fechaStr = 'Hoy';
        else if (diff == 1) fechaStr = 'Ayer';
        else if (diff < 7) fechaStr = 'Hace $diff días';
        else fechaStr = DateFormat('dd MMM', 'es').format(dt);
      } catch (_) {}
    }

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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E1E2C))
              ),
              const SizedBox(height: 4),
              Text(
                fechaStr,
                style: TextStyle(color: Colors.grey[500], fontSize: 12)
              ),
            ]
          ),
          Text(
            'Bs ${NumberFormat('#,##0.00', 'es_BO').format(amount)}',
            style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 16) // Rojo para deuda
          ),
        ]
      ),
    );
  }
}
