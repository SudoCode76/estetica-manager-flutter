import 'package:flutter/material.dart';

class EmployeeClientsScreen extends StatefulWidget {
  const EmployeeClientsScreen({super.key});

  @override
  State<EmployeeClientsScreen> createState() => _EmployeeClientsScreenState();
}

class _EmployeeClientsScreenState extends State<EmployeeClientsScreen> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Pantalla de Clientes - En desarrollo',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}
