import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../views/home_view.dart';

class AuthController {
  final TextEditingController userCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();

  // Registrar usuario local
  Future<void> registerUser(String user, String pass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("user", user);
    await prefs.setString("pass", pass);
  }

  // Validar login
  Future<void> login(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    final savedUser = prefs.getString("user");
    final savedPass = prefs.getString("pass");

    final inputUser = userCtrl.text.trim();
    final inputPass = passCtrl.text.trim();

    // Si no existe usuario guardado
    if (savedUser == null || savedPass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay usuario registrado")),
      );
      return;
    }

    // Validación
    if (inputUser == savedUser && inputPass == savedPass) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeView()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Credenciales incorrectas")),
      );
    }
  }
}
