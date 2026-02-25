import 'package:app_estetica/repositories/app_config_repository.dart';
import 'package:app_estetica/screens/blocked_screen.dart';
import 'package:app_estetica/screens/login/login_screen.dart';
import 'package:app_estetica/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_estetica/screens/admin/admin_home_screen.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';
import 'package:provider/provider.dart';
import 'package:app_estetica/providers/ticket_provider.dart';
import 'package:app_estetica/repositories/ticket_repository.dart';
import 'package:app_estetica/repositories/auth_repository.dart';
import 'package:app_estetica/repositories/catalog_repository.dart';
import 'package:app_estetica/repositories/cliente_repository.dart';
import 'package:app_estetica/repositories/reports_repository.dart';
import 'package:app_estetica/navigation/route_observer.dart';
import 'package:app_estetica/providers/reports_provider.dart';
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Provider global para TODA la app
  final SucursalProvider _globalSucursalProvider = SucursalProvider();

  // Navegator key para poder navegar desde el observer de lifecycle
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Se ejecuta cada vez que la app vuelve de background.
  /// Si el flag cambió a false, navega a BlockedScreen limpiando el stack.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAppEnabled();
    }
  }

  Future<void> _checkAppEnabled() async {
    final config = await AppConfigRepository().fetchConfig();
    if (!config.enabled) {
      final ctx = _navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => BlockedScreen(message: config.blockMessage),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Crear instancias compartidas de repositorios
    final ticketRepo = TicketRepository();
    final authRepo = AuthRepository();
    final catalogRepo = CatalogRepository();
    final clienteRepo = ClienteRepository();

    return SucursalInherited(
      provider: _globalSucursalProvider,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<SucursalProvider>.value(
            value: _globalSucursalProvider,
          ),
          Provider<TicketRepository>.value(value: ticketRepo),
          Provider<AuthRepository>.value(value: authRepo),
          Provider<CatalogRepository>.value(value: catalogRepo),
          Provider<ClienteRepository>.value(value: clienteRepo),
          Provider<ReportsRepository>.value(value: ReportsRepository()),

          // Providers que dependen de repos
          ChangeNotifierProvider<TicketProvider>(
            create: (_) => TicketProvider(repo: ticketRepo),
          ),
          ChangeNotifierProvider<ReportsProvider>(
            create: (_) => ReportsProvider(),
          ),
        ],
        child: MaterialApp(
          title: 'App Estetica',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          navigatorKey: _navigatorKey,
          navigatorObservers: [routeObserver],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
          locale: const Locale('es', 'ES'),
          home: const Root(),
        ),
      ),
    );
  }
}

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool _checking = true;
  Widget _initial = const LoginScreen();

  @override
  void initState() {
    super.initState();
    _checkAll();
  }

  Future<void> _checkAll() async {
    // 1. Verificar flag de disponibilidad de la app
    final config = await AppConfigRepository().fetchConfig();
    if (!config.enabled) {
      if (mounted) {
        setState(() {
          _initial = BlockedScreen(message: config.blockMessage);
          _checking = false;
        });
      }
      return;
    }

    // 2. Verificar sesión de Supabase
    final supabaseUser = Supabase.instance.client.auth.currentUser;

    if (supabaseUser != null) {
      if (kDebugMode) {
        debugPrint(
          '=== Usuario autenticado en Supabase: ${supabaseUser.email} ===',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      String? userType = prefs.getString('userType');

      if (userType == null || userType.isEmpty) {
        userType = supabaseUser.userMetadata?['tipo_usuario'];
        if (userType != null) {
          await prefs.setString('userType', userType);
        }
      }

      if (userType == 'admin' ||
          userType == 'administrador' ||
          userType == 'gerente') {
        _initial = const AdminHomeScreen();
      } else if (userType == 'empleado' || userType == 'vendedor') {
        _initial = const AdminHomeScreen(isEmployee: true);
      } else {
        _initial = const AdminHomeScreen();
      }
    } else {
      if (kDebugMode) debugPrint('=== No hay usuario autenticado ===');
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
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    return _initial;
  }
}
