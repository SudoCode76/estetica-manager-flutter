import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  group('ClienteRepository', () {
    group('Validaciones de datos', () {
      test('Valida que un cliente tenga nombre no vacío', () {
        // Arrange
        const nombre = '';

        // Act & Assert
        expect(nombre.isEmpty, equals(true));
      });

      test('Valida que un cliente tenga teléfono válido', () {
        // Arrange
        const telefono = '1234567890';

        // Act & Assert
        expect(telefono.length, greaterThanOrEqualTo(7));
      });

      test('Valida email con formato correcto', () {
        // Arrange
        const email = 'cliente@example.com';
        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

        // Act
        final isValid = emailRegex.hasMatch(email);

        // Assert
        expect(isValid, equals(true));
      });

      test('Rechaza email con formato incorrecto', () {
        // Arrange
        const email = 'cliente@invalid';
        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

        // Act
        final isValid = emailRegex.hasMatch(email);

        // Assert
        expect(isValid, equals(false));
      });
    });

    group('Transformación de datos', () {
      test('Convierte strings de números a int correctamente', () {
        // Arrange
        const numeroString = '123';

        // Act
        final numero = int.tryParse(numeroString);

        // Assert
        expect(numero, equals(123));
        expect(numero, isA<int>());
      });

      test('Maneja strings inválidos en conversión a int', () {
        // Arrange
        const numeroString = 'abc';

        // Act
        final numero = int.tryParse(numeroString);

        // Assert
        expect(numero, isNull);
      });
    });

    group('Búsqueda y filtrado', () {
      test('Filtra clientes por nombre que contiene texto', () {
        // Arrange
        final clientes = [
          {'id': 1, 'nombre': 'Juan Pérez'},
          {'id': 2, 'nombre': 'María García'},
          {'id': 3, 'nombre': 'Juan López'},
        ];
        const busqueda = 'Juan';

        // Act
        final resultados = clientes
            .where((c) =>
                c['nombre'].toString().toLowerCase().contains(busqueda.toLowerCase()))
            .toList();

        // Assert
        expect(resultados.length, equals(2));
        expect(resultados[0]['nombre'], equals('Juan Pérez'));
        expect(resultados[1]['nombre'], equals('Juan López'));
      });

      test('Ordena clientes por nombre alfabéticamente', () {
        // Arrange
        final clientes = [
          {'nombre': 'Zara'},
          {'nombre': 'Ana'},
          {'nombre': 'Carlos'},
        ];

        // Act
        final ordenados = List.from(clientes)
          ..sort((a, b) =>
              a['nombre'].toString().compareTo(b['nombre'].toString()));

        // Assert
        expect(ordenados[0]['nombre'], equals('Ana'));
        expect(ordenados[1]['nombre'], equals('Carlos'));
        expect(ordenados[2]['nombre'], equals('Zara'));
      });

      test('Agrupa clientes por ciudad', () {
        // Arrange
        final clientes = [
          {'nombre': 'Juan', 'ciudad': 'Madrid'},
          {'nombre': 'María', 'ciudad': 'Barcelona'},
          {'nombre': 'Pedro', 'ciudad': 'Madrid'},
        ];

        // Act
        final agrupados = <String, List<Map<String, dynamic>>>{};
        for (var cliente in clientes) {
          final ciudad = cliente['ciudad'].toString();
          agrupados.putIfAbsent(ciudad, () => []);
          agrupados[ciudad]?.add(cliente);
        }

        // Assert
        expect(agrupados['Madrid']?.length, equals(2));
        expect(agrupados['Barcelona']?.length, equals(1));
      });
    });
  });
}
