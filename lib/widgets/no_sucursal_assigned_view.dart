import 'package:flutter/material.dart';

class NoSucursalAssignedView extends StatelessWidget {
  final String message;

  const NoSucursalAssignedView({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: TextStyle(fontSize: 16.0)),
    );
  }
}