import 'package:flutter/material.dart';

class EmployeeTicketsScreen extends StatefulWidget {
  const EmployeeTicketsScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeTicketsScreen> createState() => _EmployeeTicketsScreenState();
}

class _EmployeeTicketsScreenState extends State<EmployeeTicketsScreen> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Pantalla de Tickets - En desarrollo',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}

