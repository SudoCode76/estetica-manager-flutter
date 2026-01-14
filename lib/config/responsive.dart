import 'package:flutter/material.dart';

/// Utilidades para diseño responsivo
class Responsive {
  /// Breakpoints para diferentes tamaños de pantalla
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Obtener el ancho de la pantalla
  static double width(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Obtener el alto de la pantalla
  static double height(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Verificar si es móvil
  static bool isMobile(BuildContext context) {
    return width(context) < mobileBreakpoint;
  }

  /// Verificar si es tablet
  static bool isTablet(BuildContext context) {
    return width(context) >= mobileBreakpoint && width(context) < tabletBreakpoint;
  }

  /// Verificar si es desktop
  static bool isDesktop(BuildContext context) {
    return width(context) >= desktopBreakpoint;
  }

  /// Verificar si es tablet o más grande
  static bool isTabletOrLarger(BuildContext context) {
    return width(context) >= mobileBreakpoint;
  }

  /// Obtener padding horizontal responsivo
  static double horizontalPadding(BuildContext context) {
    if (isMobile(context)) return 16.0;
    if (isTablet(context)) return 24.0;
    return 32.0;
  }

  /// Obtener padding vertical responsivo
  static double verticalPadding(BuildContext context) {
    if (isMobile(context)) return 12.0;
    if (isTablet(context)) return 16.0;
    return 20.0;
  }

  /// Obtener número de columnas para grid
  static int gridColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3;
  }

  /// Obtener tamaño de fuente responsivo
  static double fontSize(BuildContext context, double baseFontSize) {
    final screenWidth = width(context);
    if (screenWidth < 360) {
      return baseFontSize * 0.9; // Pantallas muy pequeñas
    } else if (screenWidth < mobileBreakpoint) {
      return baseFontSize; // Móviles normales
    } else if (screenWidth < tabletBreakpoint) {
      return baseFontSize * 1.1; // Tablets
    } else {
      return baseFontSize * 1.2; // Desktop
    }
  }

  /// Obtener ancho máximo para contenido
  static double maxContentWidth(BuildContext context) {
    if (isMobile(context)) return double.infinity;
    if (isTablet(context)) return 800;
    return 1200;
  }

  /// Obtener aspect ratio para cards
  static double cardAspectRatio(BuildContext context) {
    if (isMobile(context)) return 1.0;
    if (isTablet(context)) return 1.2;
    return 1.5;
  }

  /// Obtener tamaño de iconos responsivo
  static double iconSize(BuildContext context, double baseSize) {
    if (isMobile(context) && width(context) < 360) {
      return baseSize * 0.85;
    }
    return baseSize;
  }

  /// Obtener espaciado responsivo
  static double spacing(BuildContext context, double baseSpacing) {
    if (isMobile(context) && width(context) < 360) {
      return baseSpacing * 0.75;
    }
    return baseSpacing;
  }

  /// Verificar si es pantalla pequeña (menos de 360dp)
  static bool isSmallScreen(BuildContext context) {
    return width(context) < 360;
  }

  /// Obtener padding para diálogos
  static EdgeInsets dialogPadding(BuildContext context) {
    if (isSmallScreen(context)) {
      return const EdgeInsets.all(16);
    } else if (isMobile(context)) {
      return const EdgeInsets.all(24);
    } else {
      return const EdgeInsets.all(32);
    }
  }

  /// Obtener ancho de diálogos
  static double dialogWidth(BuildContext context) {
    final screenWidth = width(context);
    if (isSmallScreen(context)) {
      return screenWidth - 32; // Dejar 16px de margen a cada lado
    } else if (isMobile(context)) {
      return screenWidth - 48; // Dejar 24px de margen a cada lado
    } else if (isTablet(context)) {
      return 600;
    } else {
      return 700;
    }
  }

  /// Obtener altura de botones responsivo
  static double buttonHeight(BuildContext context) {
    if (isSmallScreen(context)) {
      return 48.0;
    }
    return 56.0;
  }

  /// Obtener padding para botones
  static EdgeInsets buttonPadding(BuildContext context) {
    if (isSmallScreen(context)) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    }
    return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  }
}

