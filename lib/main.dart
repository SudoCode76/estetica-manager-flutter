import 'package:app_estetica/screens/login/login_screen.dart';
import 'package:app_estetica/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_estetica/screens/admin/admin_home_screen.dart';
import 'package:app_estetica/providers/sucursal_provider.dart';

void main() {
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
      child: MaterialApp(
        title: 'App Estetica',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const Root(),
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
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt');
    final userType = prefs.getString('userType');
    if (jwt != null && jwt.isNotEmpty && userType != null && userType.isNotEmpty) {
      if (userType == 'administrador') {
        _initial = const AdminHomeScreen();
      } else if (userType == 'empleado') {
        // Usar AdminHomeScreen con isEmployee=true para mantener consistencia con login
        _initial = const AdminHomeScreen(isEmployee: true);
      }
    } else {
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
