import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../views/home_view.dart';

class LoginController {
  final userController = TextEditingController();
  final passController = TextEditingController();

  Future<void> login(BuildContext context) async {
    final user = userController.text.trim();
    final pass = passController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Registrar solo 1 vez (si no existe usuario guardado)
    String? savedUser = prefs.getString('user');
    String? savedPass = prefs.getString('pass');

    savedUser = prefs.getString('user');
    savedPass = prefs.getString('pass');

    if (user == savedUser && pass == savedPass) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeView()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credenciales incorrectas')),
      );
    }
  }
}
