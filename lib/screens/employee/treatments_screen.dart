import 'package:flutter/material.dart';

class EmployeeTreatmentsScreen extends StatefulWidget {
  const EmployeeTreatmentsScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeTreatmentsScreen> createState() => _EmployeeTreatmentsScreenState();
}

class _EmployeeTreatmentsScreenState extends State<EmployeeTreatmentsScreen> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Pantalla de Tratamientos - En desarrollo',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}

