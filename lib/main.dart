import 'package:app_estetica/screens/login/login_screen.dart';
import 'package:app_estetica/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_estetica/screens/admin/admin_home_screen.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:provider/provider.dart';
import 'package:app_estetica/providers/ticket_provider.dart';
import 'package:app_estetica/navigation/route_observer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_estetica/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Provider global para TODA la app
  final SucursalProvider _globalSucursalProvider = SucursalProvider();

  @override
  Widget build(BuildContext context) {
    return SucursalInherited(
      provider: _globalSucursalProvider,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<TicketProvider>(create: (_) => TicketProvider()),
        ],
        child: MaterialApp(
          title: 'App Estetica',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          navigatorObservers: [routeObserver],
          // Localizations needed for DateRangePicker, DatePicker and other widgets
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'ES'),
            Locale('en', 'US'),
          ],
          locale: const Locale('es', 'ES'),
          home: const Root(),
        ),
      ),
    );
  }
}

class Root extends StatefulWidget {
  const Root({Key? key}) : super(key: key);

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool _checking = true;
  Widget _initial = const LoginScreen();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Verificar sesión de Supabase
    final supabaseUser = Supabase.instance.client.auth.currentUser;

    if (supabaseUser != null) {
      print('=== Usuario autenticado en Supabase: ${supabaseUser.email} ===');

      // Obtener datos del usuario desde SharedPreferences o metadata
      final prefs = await SharedPreferences.getInstance();
      String? userType = prefs.getString('userType');

      // Si no hay userType en prefs, obtenerlo de user_metadata
      if (userType == null || userType.isEmpty) {
        userType = supabaseUser.userMetadata?['tipo_usuario'];
        if (userType != null) {
          await prefs.setString('userType', userType);
        }
      }

      if (userType == 'admin' || userType == 'administrador' || userType == 'gerente') {
        _initial = const AdminHomeScreen();
      } else if (userType == 'empleado' || userType == 'vendedor') {
        _initial = const AdminHomeScreen(isEmployee: true);
      } else {
        _initial = const AdminHomeScreen();
      }
    } else {
      print('=== No hay usuario autenticado ===');
      _initial = const LoginScreen();
    }

    if (mounted) {
      setState(() {
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
      );
    }
    return _initial;
  }
}
