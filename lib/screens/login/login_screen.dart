import 'package:app_estetica/screens/admin/admin_home_screen.dart';
import 'package:app_estetica/services/supabase_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:app_estetica/config/responsive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = SupabaseAuthService();
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('=== Iniciando login con email: ${_emailController.text} ===');
      final result = await _authService.login(
        _emailController.text,
        _passwordController.text,
      );

      debugPrint('=== Login exitoso, resultado: $result ===');

      final user = result['user'];
      debugPrint('=== Usuario obtenido: $user ===');

      final userType = user['tipoUsuario'];
      debugPrint('=== Tipo de usuario: $userType ===');

      // Guardar sesión en SharedPreferences
      await _authService.saveSessionToPrefs(result);

      debugPrint('=== Datos guardados en SharedPreferences ===');

      if (!mounted) return;

      // Navegar según el tipo de usuario
      if (userType == 'admin' ||
          userType == 'administrador' ||
          userType == 'gerente') {
        debugPrint('=== Navegando a AdminHomeScreen ===');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
        );
      } else if (userType == 'empleado' || userType == 'vendedor') {
        debugPrint('=== Navegando a AdminHomeScreen (modo empleado) ===');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AdminHomeScreen(isEmployee: true),
          ),
        );
      } else {
        debugPrint(
          '=== Tipo de usuario desconocido: $userType, usando modo administrador ===',
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('=== ERROR EN LOGIN: ${e.toString()} ===');
      debugPrint('=== STACK TRACE: $stackTrace ===');
      setState(() {
        if (e.toString().contains('Credenciales inválidas') ||
            e.toString().contains('Invalid login credentials') ||
            e.toString().contains('invalid')) {
          _errorMessage = 'Email o contraseña incorrectos.';
        } else if (e.toString().contains('NetworkException') ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Connection')) {
          _errorMessage = 'Error de conexión. Verifique su internet.';
        } else if (e.toString().contains('timeout')) {
          _errorMessage = 'Tiempo de espera agotado. Intente nuevamente.';
        } else {
          // Mostrar el error específico para debugging
          final errorMsg = e.toString();
          if (errorMsg.length > 100) {
            _errorMessage = 'Error: ${errorMsg.substring(0, 100)}...';
          } else {
            _errorMessage = 'Error: $errorMsg';
          }
          debugPrint(
            '=== Error específico mostrado al usuario: $_errorMessage ===',
          );
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSmallScreen = Responsive.isSmallScreen(context);
    final screenWidth = Responsive.width(context);

    // Tamaños responsivos
    final logoSize = isSmallScreen ? 80.0 : 120.0;
    final logoIconSize = isSmallScreen ? 40.0 : 60.0;
    final titleSpacing = isSmallScreen ? 24.0 : 48.0;
    final cardPadding = isSmallScreen ? 20.0 : 32.0;
    final cardBorderRadius = isSmallScreen ? 20.0 : 28.0;
    final maxCardWidth = screenWidth < 360
        ? screenWidth - 32
        : (screenWidth < 600 ? screenWidth - 48 : 450.0);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,   // #EDD9FF
              colorScheme.surface,            // #FDFAFF
              colorScheme.tertiaryContainer,  // #FFD6EF
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.horizontalPadding(context),
                vertical: Responsive.verticalPadding(context),
              ),
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Icon con Material 3
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        width: logoSize,
                        height: logoSize,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.spa_rounded,
                          size: logoIconSize,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: titleSpacing),

                    // Título
                    Text(
                      'Bienvenido',
                      style:
                          (isSmallScreen
                                  ? textTheme.headlineMedium
                                  : textTheme.displaySmall)
                              ?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 8),
                    Text(
                      'Inicia sesión para continuar',
                      style:
                          (isSmallScreen
                                  ? textTheme.bodyMedium
                                  : textTheme.bodyLarge)
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: titleSpacing),

                    // Formulario en Card Material 3
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(cardBorderRadius),
                      ),
                      child: Container(
                        constraints: BoxConstraints(maxWidth: maxCardWidth),
                        padding: EdgeInsets.all(cardPadding),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Campo Email
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'nombre@ejemplo.com',
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    size: isSmallScreen ? 20 : 24,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 12 : 16,
                                    vertical: isSmallScreen ? 12 : 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor ingrese su email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Ingrese un email válido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              // Campo Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  hintText: 'Ingrese su contraseña',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor ingrese su contraseña';
                                  }
                                  if (value.length < 4) {
                                    return 'La contraseña debe tener al menos 4 caracteres';
                                  }
                                  return null;
                                },
                              ),

                              // Error Message
                              if (_errorMessage != null) ...[
                                SizedBox(height: isSmallScreen ? 16 : 24),
                                Container(
                                  padding: EdgeInsets.all(
                                    isSmallScreen ? 12 : 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        color: colorScheme.onErrorContainer,
                                        size: isSmallScreen ? 20 : 24,
                                      ),
                                      SizedBox(width: isSmallScreen ? 8 : 12),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style:
                                              (isSmallScreen
                                                      ? textTheme.bodySmall
                                                      : textTheme.bodyMedium)
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onErrorContainer,
                                                  ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              SizedBox(height: isSmallScreen ? 24 : 32),

                              // Botón de Login Material 3
                              FilledButton(
                                onPressed: _isLoading ? null : _login,
                                style: FilledButton.styleFrom(
                                  minimumSize: Size(
                                    double.infinity,
                                    Responsive.buttonHeight(context),
                                  ),
                                  padding: Responsive.buttonPadding(context),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        height: isSmallScreen ? 20 : 24,
                                        width: isSmallScreen ? 20 : 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: colorScheme.onPrimary,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Iniciar Sesión',
                                            style:
                                                (isSmallScreen
                                                        ? textTheme.labelMedium
                                                        : textTheme.labelLarge)
                                                    ?.copyWith(
                                                      color:
                                                          colorScheme.onPrimary,
                                                    ),
                                          ),
                                          SizedBox(
                                            width: isSmallScreen ? 6 : 8,
                                          ),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            color: colorScheme.onPrimary,
                                            size: isSmallScreen ? 18 : 20,
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 16 : 32),

                    // Footer
                    Text(
                      '© 2026 App Estética',
                      style:
                          (isSmallScreen
                                  ? textTheme.labelSmall
                                  : textTheme.bodySmall)
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
