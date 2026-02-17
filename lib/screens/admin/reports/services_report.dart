import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'report_period.dart';

class ServicesReport extends StatelessWidget {
  final ReportPeriod period;
  final Map<String, dynamic> data;
  const ServicesReport({super.key, required this.period, required this.data});

  bool _looksLikeHourLabel(String label) {
    final normalized = label.toLowerCase().trim();
    final regex = RegExp(
      r'^[0-2]?\d(:[0-5]\d)?\s*(a\.?m\.?|p\.?m\.?)?$',
      caseSensitive: false,
    );
    return regex.hasMatch(normalized);
  }

  DateTime _startOfWeek(DateTime now) => DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));

  String _syntheticLabel(ReportPeriod period, int index, int total) {
    final now = DateTime.now();
    switch (period) {
      case ReportPeriod.year:
        final year = now.year - (total - 1 - index);
        return year.toString();
      case ReportPeriod.month:
        final date = DateTime(now.year, now.month - (total - 1 - index), 1);
        return DateFormat('MMM').format(date);
      case ReportPeriod.week:
        final date = _startOfWeek(now).add(Duration(days: index));
        return DateFormat('EEE').format(date);
      case ReportPeriod.today:
        final date = DateTime(
          now.year,
          now.month,
          now.day,
          0,
        ).add(Duration(hours: index));
        return DateFormat('HH:mm').format(date);
    }
  }

  bool _shouldOverrideLabel(String rawLabel, ReportPeriod period) {
    if (rawLabel.isEmpty) return true;
    if (period != ReportPeriod.today && _looksLikeHourLabel(rawLabel)) {
      return true;
    }
    return false;
  }

  String _resolveLabel(
    ReportPeriod period,
    int index,
    int total,
    Map<String, dynamic> point,
  ) {
    final rawLabel = point['label']?.toString() ?? '';
    if (!_shouldOverrideLabel(rawLabel, period)) {
      return rawLabel;
    }
    return _syntheticLabel(period, index, total);
  }

  String _periodUnitDescription(ReportPeriod period) {
    switch (period) {
      case ReportPeriod.year:
        return 'un año';
      case ReportPeriod.month:
        return 'un mes';
      case ReportPeriod.week:
        return 'un día de la semana';
      case ReportPeriod.today:
        return 'una hora del día';
    }
  }

  bool _shouldShowLabel(int index, int total) {
    if (total <= 6) return true;
    final step = (total / 4).ceil().clamp(1, total);
    return index == 0 || index == total - 1 || index % step == 0;
  }

  // ---- Aggregation by period (bucket floor strategy) ----
  List<Map<String, dynamic>> _aggregateChartDataByPeriod(
    List<dynamic> raw,
    ReportPeriod period,
  ) {
    final Map<String, Map<String, dynamic>> acc = {};

    DateTime? tryParse(String? s) {
      if (s == null) return null;
      final trimmed = s.toString().trim();
      // Try ISO parse first
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed;
      return null;
    }

    DateTime floorToBucket(DateTime dt) {
      switch (period) {
        case ReportPeriod.today:
          return DateTime(dt.year, dt.month, dt.day, dt.hour);
        case ReportPeriod.week:
          return DateTime(dt.year, dt.month, dt.day);
        case ReportPeriod.month:
          return DateTime(dt.year, dt.month, dt.day);
        case ReportPeriod.year:
          return DateTime(dt.year, dt.month, 1);
      }
    }

    String labelForBucket(DateTime bucket) {
      switch (period) {
        case ReportPeriod.today:
          return DateFormat('HH:mm').format(bucket);
        case ReportPeriod.week:
          return DateFormat('EEE').format(bucket);
        case ReportPeriod.month:
          return DateFormat('d').format(bucket);
        case ReportPeriod.year:
          return DateFormat('MMM').format(bucket);
      }
    }

    for (final e in raw) {
      final map = (e is Map)
          ? Map<String, dynamic>.from(e)
          : {'label': e.toString(), 'value': 0};
      final rawLabel = map['label']?.toString() ?? '';
      final value = (map['value'] is num)
          ? (map['value'] as num).toDouble()
          : 0.0;

      // Prefer backend-provided bucket_start when available (timestamptz string)
      DateTime? parsed;
      if (map['bucket_start'] != null) {
        parsed = DateTime.tryParse(map['bucket_start'].toString());
      }
      parsed ??= tryParse(rawLabel);
      DateTime bucket;
      String key;

      if (parsed != null) {
        bucket = floorToBucket(parsed.toLocal());
        key = bucket.toIso8601String();
      } else {
        // Try parsing hour labels like '05pm' or '11pm'
        final hourMatch = RegExp(
          r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\$',
          caseSensitive: false,
        ).firstMatch(rawLabel);
        if (hourMatch != null &&
            (period == ReportPeriod.today ||
                period == ReportPeriod.week ||
                period == ReportPeriod.month)) {
          final now = DateTime.now();
          int hour = int.parse(hourMatch.group(1)!);
          final minute = (hourMatch.group(2) != null)
              ? int.parse(hourMatch.group(2)!)
              : 0;
          final ampm = hourMatch.group(3);
          if (ampm != null && ampm.toLowerCase().startsWith('p') && hour < 12)
            hour += 12;
          if (ampm != null && ampm.toLowerCase().startsWith('a') && hour == 12)
            hour = 0;
          final assumed = DateTime(now.year, now.month, now.day, hour, minute);
          bucket = floorToBucket(assumed);
          key = bucket.toIso8601String();
        } else {
          // fallback: use rawLabel as grouping key
          key = rawLabel;
          bucket = DateTime.fromMillisecondsSinceEpoch(0);
        }
      }

      if (!acc.containsKey(key)) {
        acc[key] = {
          'label': labelForBucket(bucket),
          'date': bucket,
          'value': value,
        };
      } else {
        acc[key]!['value'] = (acc[key]!['value'] as double) + value;
      }
    }

    final list = acc.values.toList();
    list.sort((a, b) {
      final da = a['date'] as DateTime?;
      final db = b['date'] as DateTime?;
      if (da != null && db != null) return da.compareTo(db);
      return (a['label'] as String).compareTo(b['label'] as String);
    });
    return list;
  }

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
                  height: 160,
                  child: chartData.isEmpty
                      ? Center(
                          child: Text(
                            'Sin datos',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            // aggregate raw chartData into unique buckets per period
                            final aggregated = _aggregateChartDataByPeriod(
                              chartData,
                              period,
                            );
                            final total = aggregated.length;
                            final spots = <FlSpot>[];
                            final labels = <double, String>{};
                            for (var i = 0; i < total; i++) {
                              final item = aggregated[i];
                              final value = (item['value'] as double?) ?? 0.0;
                              final x = i.toDouble();
                              spots.add(FlSpot(x, value));
                              labels[x] = item['label']?.toString() ?? '';
                            }
                            final showDots = total <= 12;

                            return LineChart(
                              LineChartData(
                                minX: 0,
                                maxX: (total - 1).toDouble(),
                                gridData: const FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 36,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.round();
                                        if (!_shouldShowLabel(index, total)) {
                                          return const SizedBox.shrink();
                                        }
                                        final label =
                                            labels[value] ??
                                            labels[index.toDouble()] ??
                                            '';
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 11,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                lineTouchData: LineTouchData(
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((spot) {
                                        final idx = spot.x.round().clamp(
                                          0,
                                          total - 1,
                                        );
                                        final label =
                                            labels[spot.x] ??
                                            labels[idx.toDouble()] ??
                                            '';
                                        return LineTooltipItem(
                                          '$label\n${spot.y.toStringAsFixed(0)}',
                                          TextStyle(
                                            color: cs.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        );
                                      }).toList();
                                    },
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    color: cs.primary,
                                    barWidth: 3,
                                    dotData: FlDotData(show: showDots),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          cs.primary.withAlpha(
                                            (0.35 * 255).toInt(),
                                          ),
                                          cs.primary.withAlpha(
                                            (0.02 * 255).toInt(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cada punto representa ${_periodUnitDescription(period)}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
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
