import 'package:flutter/material.dart';
import 'report_period.dart';

class ClientsReport extends StatelessWidget {
  final ReportPeriod period;
  final Map<String, dynamic> data;
  const ClientsReport({super.key, required this.period, required this.data});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final atendidos = (data['atendidos'] as num?)?.toInt() ?? 0;
    final nuevos = (data['nuevos'] as num?)?.toInt() ?? 0;
    final recurrentesPct = (data['recurrentes_pct'] as num?)?.toDouble() ?? 0.0;
    final topClients = (data['top_clientes'] as List?) ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),

          // CARD ATENDIDOS (gráfico eliminado por simplicidad)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('CLIENTES ATENDIDOS', style: TextStyle(color: Colors.grey[600], fontSize: 12, letterSpacing: 0.5)),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.people, color: Color(0xFF9333EA), size: 20),
                )
              ]),
              const SizedBox(height: 8),
              Text('$atendidos', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2C))),
              const SizedBox(height: 8),
              // En lugar del gráfico mostramos un resumen textual y pequeños indicadores
              Row(children: [
                Expanded(child: Text('Clientes atendidos en el periodo', style: TextStyle(color: Colors.grey[600]))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(12)),
                  child: Text('${(recurrentesPct * 100).toInt()}% recurrentes', style: const TextStyle(color: Color(0xFF9333EA), fontWeight: FontWeight.bold)),
                )
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          Row(children: [
            // CARD NUEVOS
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('NUEVOS', style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('$nuevos', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Registrados\nen este periodo', style: TextStyle(color: Colors.grey, height: 1.2, fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(width: 16),
            // CARD RECURRENTES (Violeta)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xFF9333EA), borderRadius: BorderRadius.circular(24)),
                child: Column(children: [
                  const Text('RECURRENTES', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 70, width: 70,
                    child: Stack(children: [
                      Center(child: Text('${(recurrentesPct * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                      SizedBox(
                        width: 70, height: 70,
                        child: CircularProgressIndicator(value: recurrentesPct, color: Colors.white, backgroundColor: Colors.white24, strokeWidth: 6),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const Text('Fidelización', style: TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
            )
          ]),

          const SizedBox(height: 16),

          // TOP CLIENTES
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Top Clientes', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF1E1E2C))),
                const Text('Ver todo', style: TextStyle(color: Color(0xFF9333EA), fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 24),
              if (topClients.isEmpty) const Text("Sin datos"),
              ...topClients.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final c = entry.value;
                final amount = (c['amount'] as num).toDouble();
                final maxVal = topClients.isEmpty ? 1.0 : topClients.map((e) => (e['amount'] as num).toDouble()).reduce((a, b) => a > b ? a : b);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Column(children: [
                    Row(children: [
                      Text(idx.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('Bs ${amount.toInt()}', style: const TextStyle(color: Color(0xFF9333EA), fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: amount / (maxVal == 0 ? 1 : maxVal), color: const Color(0xFF9333EA), backgroundColor: const Color(0xFFF3E8FF), minHeight: 6),
                    )
                  ]),
                );
              }),
            ]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
