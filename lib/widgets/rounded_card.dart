import 'package:flutter/material.dart';

class RoundedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double elevation;

  const RoundedCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.elevation = 4});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: elevation,
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
