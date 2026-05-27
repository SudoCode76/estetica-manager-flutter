import 'package:flutter/material.dart';
import 'package:app_estetica/widgets/app_ui.dart';

class RoundedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double elevation;

  const RoundedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(padding: padding, child: child);
  }
}
