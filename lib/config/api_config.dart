/// Configuración de URLs de la API
///
/// Este archivo centraliza la configuración de las URLs del backend
/// para facilitar el cambio entre desarrollo y producción.
class ApiConfig {
  // URL de producción (Strapi desplegado)
  static const String productionUrl = 'https://fantastic-agreement-b2f3f76198.strapiapp.com/api';

  // URL de desarrollo local
  static const String localUrl = 'http://localhost:1337/api';

  // URL de desarrollo para Android Emulator
  static const String androidLocalUrl = 'http://10.0.2.2:1337/api';

  // Modo de ejecución: true para producción, false para desarrollo
  static const bool isProduction = true;

  /// Obtiene la URL base según el modo de ejecución
  static String get baseUrl => isProduction ? productionUrl : localUrl;

  /// Timeout para las peticiones HTTP (en segundos)
  static const int requestTimeout = 15;

  /// Timeout para peticiones de carga de datos pesados (en segundos)
  static const int heavyRequestTimeout = 30;

  /// Configuración de logging
  static const bool enableDebugLogs = true;
}

