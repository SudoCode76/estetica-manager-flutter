import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  final bool enabled;
  final String blockMessage;

  const AppConfig({required this.enabled, required this.blockMessage});

  /// Fallback seguro: si no se puede consultar Supabase, permitir el acceso.
  factory AppConfig.fallbackAllow() => const AppConfig(
        enabled: true,
        blockMessage: '',
      );
}

class AppConfigRepository {
  final _client = Supabase.instance.client;

  /// Consulta el flag de disponibilidad de la app.
  /// En caso de error o timeout, retorna [AppConfig.fallbackAllow] (acceso permitido).
  Future<AppConfig> fetchConfig() async {
    try {
      final response = await _client
          .from('app_config')
          .select('app_enabled, block_message')
          .eq('id', 1)
          .single()
          .timeout(const Duration(seconds: 5));

      return AppConfig(
        enabled: (response['app_enabled'] as bool?) ?? true,
        blockMessage: (response['block_message'] as String?) ?? '',
      );
    } catch (e) {
      debugPrint('AppConfigRepository: no se pudo consultar el flag ($e). Permitiendo acceso.');
      return AppConfig.fallbackAllow();
    }
  }
}
