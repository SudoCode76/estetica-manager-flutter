import 'package:app_estetica/screens/admin/admin_home_screen.dart';
import 'package:app_estetica/screens/employee/employee_home_screen.dart';
import 'package:app_estetica/services/api_service.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  String? _errorMessage;

  Future<void> _login() async {
    try {
      final result = await _apiService.login(
        _emailController.text,
        _passwordController.text,
      );

      setState(() {
        _errorMessage = null;
      });

      final user = result['user'];
      final userType = user['tipoUsuario'];

      if (userType == 'administrador') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
        );
      } else if (userType == 'empleado') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const EmployeeHomeScreen()),
        );
      } else {
        setState(() {
          _errorMessage = 'Unknown user type.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to login. Please check your credentials.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _login,
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
