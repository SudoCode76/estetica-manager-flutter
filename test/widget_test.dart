import 'package:app_estetica/screens/login/login_screen.dart';
import 'package:app_estetica/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders redesigned login screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const LoginScreen()),
    );

    expect(find.text('App Estética'), findsOneWidget);
    expect(find.text('Inicio de sesión'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.byIcon(Icons.spa_rounded), findsOneWidget);
  });
}
