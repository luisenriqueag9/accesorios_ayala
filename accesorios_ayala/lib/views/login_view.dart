import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../utils/widgets/mis_textfield.dart';
import '../utils/widgets/mis_button.dart';
import 'register_view.dart';

class LoginView extends StatelessWidget {
  LoginView({super.key});

  final auth = AuthController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo degradado que ya tenés
          // Blur, Glass, etc...
          // (lo mantenemos igual)

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  MisTextfield(
                    controller: auth.userCtrl,
                    hintText: 'Usuario',
                    obscureText: false,
                  ),
                  const SizedBox(height: 15),
                  MisTextfield(
                    controller: auth.passCtrl,
                    hintText: 'Contraseña',
                    obscureText: true,
                  ),
                  const SizedBox(height: 30),

                  MisButtons(
                    text: "Ingresar",
                    onTap: () => auth.login(context),
                  ),

                  const SizedBox(height: 25),

                  // Botón para ir al registro
                  TextButton(
                    child: const Text("Crear usuario"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RegisterView()),
                      );
                    },
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
