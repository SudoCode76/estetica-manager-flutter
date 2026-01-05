import 'package:flutter/material.dart';
import 'package:app_estetica/screens/admin/treatments_screen.dart';

class EmployeeTreatmentsScreen extends StatelessWidget {
  const EmployeeTreatmentsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Reuse the admin TreatmentsScreen implementation for employees
    return const TreatmentsScreen();
  }
}
