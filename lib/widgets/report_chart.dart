import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// ReportChart usando fl_chart: soporta line chart (tendencia) y bar chart (comparativa ingresos vs deuda)
class ReportChart extends StatelessWidget {
  final List<Map<String, dynamic>> data; // items: { 'date': 'YYYY-MM-DD' or 'YYYY-MM', 'payments': num, 'pendingDebt': num }
  final bool isBar;

  const ReportChart({super.key, required this.data, this.isBar = false});

  List<double> _toDoubleList(List<Map<String, dynamic>> raw, String key) {
    return raw.map<double>((e) {
      final v = e[key];
      if (v == null) return 0.0;
      if (v is String) return double.tryParse(v) ?? 0.0;
      if (v is num) return v.toDouble();
      return 0.0;
    }).toList();
  }

  String _shortLabel(String rawDate, bool isMonth) {
    try {
      final parts = rawDate.split('-');
      if (isMonth && parts.length >= 2) {
        final monthIdx = int.parse(parts[1]) - 1;
        const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
        final label = '${months[monthIdx]} ${parts[0]}';
        return label;
      }
      if (parts.length == 3) return '${parts[2]}/${parts[1]}';
    } catch (_) {}
    return rawDate;
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(child: Text('No hay datos para mostrar', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]))),
      );
    }

    final payments = _toDoubleList(data, 'payments');
    final debts = _toDoubleList(data, 'pendingDebt');

    final combined = <double>[]..addAll(payments)..addAll(debts);
    final maxY = (combined.isEmpty ? 1.0 : (combined.reduce((a, b) => a > b ? a : b) * 1.2));

    final xLabels = data.map((e) => (e['date'] ?? '').toString()).toList();

    return SizedBox(
      height: 240,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: isBar ? _buildBarChart(context, payments, debts, maxY, xLabels) : _buildLineChart(context, payments, maxY, xLabels),
        ),
      ),
    );
  }

  Widget _buildLineChart(BuildContext context, List<double> payments, double maxY, List<String> xLabels) {
    final spots = List<FlSpot>.generate(payments.length, (i) => FlSpot(i.toDouble(), payments[i]));

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 4),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, interval: maxY / 4)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= xLabels.length) return const SizedBox.shrink();
                final isMonth = xLabels[idx].split('-').length == 2;
                final label = _shortLabel(xLabels[idx], isMonth);
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(label, style: const TextStyle(fontSize: 10)));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withAlpha(180)]),
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), Colors.transparent])),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, List<double> payments, List<double> debts, double maxY, List<String> xLabels) {
    // Crear grupos de barras: para cada x, dos barras (payments, debts)
    final groups = <BarChartGroupData>[];
    final count = payments.length < debts.length ? payments.length : debts.length;
    for (var i = 0; i < count; i++) {
      groups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: payments[i], color: Theme.of(context).colorScheme.primary, width: 10),
        BarChartRodData(toY: debts[i], color: Colors.orange, width: 10),
      ], barsSpace: 6));
    }

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: groups,
        gridData: FlGridData(show: true, horizontalInterval: maxY / 4),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, interval: maxY / 4)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, interval: 1, getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= xLabels.length) return const SizedBox.shrink();
            final isMonth = xLabels[idx].split('-').length == 2;
            final label = _shortLabel(xLabels[idx], isMonth);
            return Padding(padding: const EdgeInsets.only(top: 6), child: Text(label, style: const TextStyle(fontSize: 10)));
          })),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
