import 'package:flutter/material.dart';
import 'reporte_ventas_screen.dart';
import 'package:app_estetica/config/responsive.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSmallScreen = Responsive.isSmallScreen(context);
    final screenWidth = Responsive.width(context);

    // Determinar el número de columnas según el ancho de pantalla
    int crossAxisCount = 1;
    double childAspectRatio = 3.0;

    if (screenWidth >= 1200) {
      crossAxisCount = 3;
      childAspectRatio = 2.5;
    } else if (screenWidth >= 800) {
      crossAxisCount = 2;
      childAspectRatio = 2.8;
    } else if (screenWidth >= 600) {
      crossAxisCount = 2;
      childAspectRatio = 2.0;
    } else if (screenWidth >= 400) {
      childAspectRatio = 2.5;
    } else {
      childAspectRatio = 2.2; // Para pantallas muy pequeñas
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reportes',
          style: TextStyle(fontSize: isSmallScreen ? 18 : 20),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona un reporte',
              style: textTheme.titleLarge?.copyWith(
                fontSize: isSmallScreen ? 18 : null,
              ),
            ),
            SizedBox(height: Responsive.spacing(context, 16)),
            Expanded(
              child: GridView.count(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: Responsive.spacing(context, 12),
                mainAxisSpacing: Responsive.spacing(context, 12),
                children: [
                  _ReportCard(
                    icon: Icons.analytics_outlined,
                    title: 'Reporte de Ventas',
                    subtitle: 'Diario y Mensual',
                    colorScheme: colorScheme,
                    isSmallScreen: isSmallScreen,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ReporteVentasScreen()),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme colorScheme;
  final bool isSmallScreen;
  final VoidCallback onTap;

  const _ReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colorScheme,
    required this.isSmallScreen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                ),
                child: Icon(
                  icon,
                  size: isSmallScreen ? 28 : 36,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: isSmallScreen ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 13 : 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 2 : 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: isSmallScreen ? 16 : 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
