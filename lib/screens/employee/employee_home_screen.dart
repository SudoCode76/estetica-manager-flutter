import 'package:flutter/material.dart';

class EmployeeHomeScreen extends StatelessWidget {
  const EmployeeHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Home'),
      ),
      body: const Center(
        child: Text('Welcome, Employee!'),
      ),
    );
  }
}
