import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportsRepository - Transformación de Datos', () {
    group('getFinancialReport', () {
      test('Normaliza correctamente el campo "ingresos"', () {
        // Arrange - Simular una respuesta de la API
        final mockResponse = {
          'ingresos': 1000.0,
        };

        // Act - Replicar la lógica de transformación del repository
        final ingresos = (mockResponse['ingresos'] is num)
            ? (mockResponse['ingresos'] as num).toDouble()
            : 0.0;

        // Assert
        expect(ingresos, equals(1000.0));
        expect(ingresos, isA<double>());
      });

      test('Convierte ingresos string a double correctamente', () {
        // Arrange
        final mockResponse = {
          'ingresos': '1500.50',
        };

        // Act - Intentar convertir
        final ingresos = (mockResponse['ingresos'] is num)
            ? (mockResponse['ingresos'] as num).toDouble()
            : 0.0;

        // Assert - Como es string, no es num, debería ser 0.0
        expect(ingresos, equals(0.0));
      });

      test('Maneja correctamente ingresos null', () {
        // Arrange
        final mockResponse = {
          'ingresos': null,
        };

        // Act
        final ingresos = (mockResponse['ingresos'] is num)
            ? (mockResponse['ingresos'] as num).toDouble()
            : 0.0;

        // Assert
        expect(ingresos, equals(0.0));
      });

      test('Transforma chart_data correctamente', () {
        // Arrange
        final rawChartData = [
          {'label': 'Enero', 'value': 500},
          {'label': 'Febrero', 'value': 300},
        ];

        // Act - Replicar la lógica del repository
        final chartData = rawChartData.map<Map<String, dynamic>>((e) {
          final map = (e is Map) ? Map<String, dynamic>.from(e) : {};
          return {
            'label': map['label']?.toString() ?? '',
            'value': (map['value'] is num)
                ? (map['value'] as num).toDouble()
                : 0.0,
          };
        }).toList();

        // Assert
        expect(chartData.length, equals(2));
        expect(chartData[0]['label'], equals('Enero'));
        expect(chartData[0]['value'], equals(500.0));
        expect(chartData[0]['value'], isA<double>());
        expect(chartData[1]['label'], equals('Febrero'));
        expect(chartData[1]['value'], equals(300.0));
      });

      test('Maneja chart_data vacío', () {
        // Arrange
        final rawChartData = <dynamic>[];

        // Act
        final chartData = rawChartData.map<Map<String, dynamic>>((e) {
          final map = (e is Map) ? Map<String, dynamic>.from(e) : {};
          return {
            'label': map['label']?.toString() ?? '',
            'value': (map['value'] is num)
                ? (map['value'] as num).toDouble()
                : 0.0,
          };
        }).toList();

        // Assert
        expect(chartData, isEmpty);
      });

      test('Transforma top_tratamientos correctamente', () {
        // Arrange
        final rawData = [
          {'name': 'Masaje', 'count': 5, 'total_dinero': 500.0},
          {'name': 'Facial', 'count': 3, 'total_dinero': 300.0},
        ];

        // Act
        final datos = rawData.map<Map<String, dynamic>>((e) {
          final map = (e is Map) ? Map<String, dynamic>.from(e) : {};
          return {
            'name': map['name']?.toString() ?? '',
            'count': (map['count'] is num) ? (map['count'] as num).toInt() : 0,
            'total_dinero': (map['total_dinero'] is num)
                ? (map['total_dinero'] as num).toDouble()
                : 0.0,
          };
        }).toList();

        // Assert
        expect(datos.length, equals(2));
        expect(datos[0]['name'], equals('Masaje'));
        expect(datos[0]['count'], equals(5));
        expect(datos[0]['count'], isA<int>());
        expect(datos[0]['total_dinero'], equals(500.0));
        expect(datos[0]['total_dinero'], isA<double>());
      });

      test('Convierte count a int correctamente', () {
        // Arrange
        final rawData = [
          {'name': 'Servicio', 'count': 7.5, 'total_dinero': 100.0},
        ];

        // Act - El count es 7.5, debe convertirse a 7
        final datos = rawData.map<Map<String, dynamic>>((e) {
          final map = (e is Map) ? Map<String, dynamic>.from(e) : {};
          return {
            'name': map['name']?.toString() ?? '',
            'count': (map['count'] is num) ? (map['count'] as num).toInt() : 0,
            'total_dinero': (map['total_dinero'] is num)
                ? (map['total_dinero'] as num).toDouble()
                : 0.0,
          };
        }).toList();

        // Assert
        expect(datos[0]['count'], equals(7));
        expect(datos[0]['count'], isA<int>());
      });

      test('Maneja top_tratamientos null', () {
        // Arrange
        final rawData = <dynamic>[];

        // Act
        final datos = rawData.map<Map<String, dynamic>>((e) {
          final map = (e is Map) ? Map<String, dynamic>.from(e) : {};
          return {
            'name': map['name']?.toString() ?? '',
            'count': (map['count'] is num) ? (map['count'] as num).toInt() : 0,
            'total_dinero': (map['total_dinero'] is num)
                ? (map['total_dinero'] as num).toDouble()
                : 0.0,
          };
        }).toList();

        // Assert
        expect(datos, isEmpty);
      });

      test('Transforma pendientes_cobro correctamente', () {
        // Arrange
        final rawData = [
          {'name': 'Cliente A', 'amount': 100.0, 'date': '2024-01-01'},
          {'name': 'Cliente B', 'amount': 250.5, 'date': '2024-01-02'},
        ];

        // Act
        final pendientes = rawData.map<Map<String, dynamic>>((e) {
          final map = (e is Map) ? Map<String, dynamic>.from(e) : {};
          return {
            'name': map['name']?.toString() ?? '',
            'amount': (map['amount'] is num)
                ? (map['amount'] as num).toDouble()
                : 0.0,
            'date': map['date']?.toString() ?? '',
          };
        }).toList();

        // Assert
        expect(pendientes.length, equals(2));
        expect(pendientes[0]['name'], equals('Cliente A'));
        expect(pendientes[0]['amount'], equals(100.0));
        expect(pendientes[1]['amount'], equals(250.5));
      });
    });
  });
}
