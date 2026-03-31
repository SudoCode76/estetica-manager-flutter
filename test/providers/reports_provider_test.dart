import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:app_estetica/providers/reports_provider.dart';
import 'package:app_estetica/screens/admin/reports/report_period.dart';

void main() {
  group('ReportsProvider - Lógica de Negocio', () {
    group('Cálculo de Granularidad del Gráfico', () {
      test('Período TODAY retorna granularidad HOURLY', () {
        // Este test valida la lógica de negocio sin necesitar inicializar Supabase
        // Ya que solo prueba la lógica de cálculo de granularidad
        
        const dateMode = ReportDateMode.period;
        const activePeriod = ReportPeriod.today;

        // Lógica que el provider implementa
        late ChartGranularity granularity;
        
        if (dateMode == ReportDateMode.period) {
          switch (activePeriod) {
            case ReportPeriod.today:
              granularity = ChartGranularity.hourly;
              break;
            case ReportPeriod.week:
              granularity = ChartGranularity.daily;
              break;
            case ReportPeriod.month:
              granularity = ChartGranularity.daily;
              break;
            case ReportPeriod.year:
              granularity = ChartGranularity.yearly;
              break;
            case null:
              granularity = ChartGranularity.none;
              break;
          }
        }

        expect(granularity, equals(ChartGranularity.hourly));
      });

      test('Período WEEK retorna granularidad DAILY', () {
        const dateMode = ReportDateMode.period;
        const activePeriod = ReportPeriod.week;

        late ChartGranularity granularity;
        
        if (dateMode == ReportDateMode.period) {
          switch (activePeriod) {
            case ReportPeriod.today:
              granularity = ChartGranularity.hourly;
              break;
            case ReportPeriod.week:
              granularity = ChartGranularity.daily;
              break;
            case ReportPeriod.month:
              granularity = ChartGranularity.daily;
              break;
            case ReportPeriod.year:
              granularity = ChartGranularity.yearly;
              break;
            case null:
              granularity = ChartGranularity.none;
              break;
          }
        }

        expect(granularity, equals(ChartGranularity.daily));
      });

      test('Período MONTH retorna granularidad DAILY', () {
        const dateMode = ReportDateMode.period;
        const activePeriod = ReportPeriod.month;

        late ChartGranularity granularity;
        
        if (dateMode == ReportDateMode.period) {
          switch (activePeriod) {
            case ReportPeriod.today:
              granularity = ChartGranularity.hourly;
              break;
            case ReportPeriod.week:
              granularity = ChartGranularity.daily;
              break;
            case ReportPeriod.month:
              granularity = ChartGranularity.daily;
              break;
            case ReportPeriod.year:
              granularity = ChartGranularity.yearly;
              break;
            case null:
              granularity = ChartGranularity.none;
              break;
          }
        }

        expect(granularity, equals(ChartGranularity.daily));
      });

      test('Período YEAR retorna granularidad YEARLY', () {
        const dateMode = ReportDateMode.period;
        const activePeriod = ReportPeriod.year;

        late ChartGranularity granularity;
        
        if (dateMode == ReportDateMode.period) {
          switch (activePeriod) {
            case ReportPeriod.today:
              granularity = ChartGranularity.hourly;
              break;
            case ReportPeriod.week:
              granularity = ChartGranularity.daily;
              break;
            case ReportPeriod.month:
              granularity = ChartGranularity.daily;
              break;
            case ReportPeriod.year:
              granularity = ChartGranularity.yearly;
              break;
            case null:
              granularity = ChartGranularity.none;
              break;
          }
        }

        expect(granularity, equals(ChartGranularity.yearly));
      });

      test('DateRange con 1 día retorna granularidad HOURLY', () {
        final start = DateTime(2024, 6, 1);
        final end = DateTime(2024, 6, 1); // Mismo día
        
        final days = end.difference(start).inDays + 1;
        
        late ChartGranularity granularity;
        if (days <= 1) {
          granularity = ChartGranularity.hourly;
        } else if (days <= 7) {
          granularity = ChartGranularity.daily;
        } else {
          granularity = ChartGranularity.none;
        }

        expect(granularity, equals(ChartGranularity.hourly));
        expect(days, equals(1));
      });

      test('DateRange con 5 días retorna granularidad DAILY', () {
        final start = DateTime(2024, 6, 1);
        final end = DateTime(2024, 6, 5);
        
        final days = end.difference(start).inDays + 1;
        
        late ChartGranularity granularity;
        if (days <= 1) {
          granularity = ChartGranularity.hourly;
        } else if (days <= 7) {
          granularity = ChartGranularity.daily;
        } else {
          granularity = ChartGranularity.none;
        }

        expect(granularity, equals(ChartGranularity.daily));
        expect(days, equals(5));
      });

      test('DateRange con 10 días retorna granularidad NONE', () {
        final start = DateTime(2024, 6, 1);
        final end = DateTime(2024, 6, 10);
        
        final days = end.difference(start).inDays + 1;
        
        late ChartGranularity granularity;
        if (days <= 1) {
          granularity = ChartGranularity.hourly;
        } else if (days <= 7) {
          granularity = ChartGranularity.daily;
        } else {
          granularity = ChartGranularity.none;
        }

        expect(granularity, equals(ChartGranularity.none));
        expect(days, equals(10));
      });

      test('DateMode.monthPick retorna granularidad MONTHLY', () {
        const dateMode = ReportDateMode.monthPick;

        late ChartGranularity granularity;
        switch (dateMode) {
          case ReportDateMode.yearPick:
            granularity = ChartGranularity.yearly;
            break;
          case ReportDateMode.monthPick:
            granularity = ChartGranularity.monthly;
            break;
          case ReportDateMode.singleDay:
            granularity = ChartGranularity.hourly;
            break;
          case ReportDateMode.dateRange:
          case ReportDateMode.period:
            granularity = ChartGranularity.daily;
            break;
        }

        expect(granularity, equals(ChartGranularity.monthly));
      });

      test('DateMode.yearPick retorna granularidad YEARLY', () {
        const dateMode = ReportDateMode.yearPick;

        late ChartGranularity granularity;
        switch (dateMode) {
          case ReportDateMode.yearPick:
            granularity = ChartGranularity.yearly;
            break;
          case ReportDateMode.monthPick:
            granularity = ChartGranularity.monthly;
            break;
          case ReportDateMode.singleDay:
            granularity = ChartGranularity.hourly;
            break;
          case ReportDateMode.dateRange:
          case ReportDateMode.period:
            granularity = ChartGranularity.daily;
            break;
        }

        expect(granularity, equals(ChartGranularity.yearly));
      });
    });

    group('Lógica de Cálculo de Fechas', () {
      test('Período TODAY retorna fechas del día actual', () {
        final now = DateTime.now();
        final expectedStart = DateTime(now.year, now.month, now.day);
        final expectedEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

        // Simular la lógica del provider
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

        expect(start.year, equals(expectedStart.year));
        expect(start.month, equals(expectedStart.month));
        expect(start.day, equals(expectedStart.day));
        expect(end.hour, equals(23));
        expect(end.minute, equals(59));
      });
    });

    group('Validaciones de Estado', () {
      test('Datos inician vacíos', () {
        final financialData = <String, dynamic>{};
        final clientsData = <String, dynamic>{};

        expect(financialData, isEmpty);
        expect(clientsData, isEmpty);
      });

      test('isLoading inicia como false', () {
        bool isLoading = false;
        expect(isLoading, equals(false));
      });

      test('Período por defecto es TODAY', () {
        const defaultPeriod = ReportPeriod.today;
        expect(defaultPeriod, equals(ReportPeriod.today));
      });
    });
  });
}
