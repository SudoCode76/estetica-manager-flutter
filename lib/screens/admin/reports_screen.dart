import 'package:flutter/material.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Pantalla de Reportes - En desarrollo',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}

