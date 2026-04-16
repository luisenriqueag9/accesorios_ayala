import 'package:flutter/material.dart';

class GenerarReciboView extends StatelessWidget {
  const GenerarReciboView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Generar Recibo")),
      body: const Center(
        child: Text(
          "Pantalla para generar recibo",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
