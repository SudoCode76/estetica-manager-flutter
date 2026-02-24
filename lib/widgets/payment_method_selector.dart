import 'package:flutter/material.dart';

typedef OnMetodoChanged = void Function(String metodo);

class PaymentMethodSelector extends StatelessWidget {
  final String value;
  final OnMetodoChanged onChanged;
  const PaymentMethodSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 480;
        final options = [
          {'key': 'efectivo', 'label': 'Efectivo', 'icon': Icons.payments},
          {'key': 'qr', 'label': 'QR', 'icon': Icons.qr_code_2},
        ];

        if (isWide) {
          return Row(
            children: options.map((opt) {
              final selected = opt['key'] == value;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  onTap: () => onChanged(opt['key'] as String),
                  child: Row(
                    children: [
                      Icon(
                        opt['icon'] as IconData,
                        size: 20,
                        color: selected
                            ? color
                            : Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        opt['label'] as String,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected ? color : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final selected = opt['key'] == value;
            return ChoiceChip(
              avatar: Icon(
                opt['icon'] as IconData,
                size: 18,
                color: selected ? Colors.white : null,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              label: Text(opt['label'] as String),
              selected: selected,
              onSelected: (_) => onChanged(opt['key'] as String),
              selectedColor: color,
            );
          }).toList(),
        );
      },
    );
  }
}
