class SupabaseConfig {
  // URL de tu proyecto Supabase
  static const String supabaseUrl = 'https://jideirsutiqcusoumvwt.supabase.co';

  static const String supabaseAnonKey =
      'sb_publishable_7iYacsDWE8zp26-Ez5ZBLA_7I2iB_tL';

  static const String functionsAuthToken = String.fromEnvironment(
    'SUPABASE_FUNCTIONS_AUTH_TOKEN',
    defaultValue: '',
  );
}
