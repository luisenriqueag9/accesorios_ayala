import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../utils/widgets/mis_textfield.dart';
import '../utils/widgets/mis_button.dart';

class RegisterView extends StatelessWidget {
  RegisterView({super.key});

  final auth = AuthController();
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registro")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            MisTextfield(
              controller: userCtrl,
              hintText: 'Usuario',
              obscureText: false,
            ),
            const SizedBox(height: 15),
            MisTextfield(
              controller: passCtrl,
              hintText: 'Contraseña',
              obscureText: true,
            ),
            const SizedBox(height: 30),
            MisButtons(
              text: "Crear usuario",
              onTap: () async {
                await auth.registerUser(
                  userCtrl.text.trim(),
                  passCtrl.text.trim(),
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Usuario registrado")),
                );

                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
