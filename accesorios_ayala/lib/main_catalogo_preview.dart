import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'utils/theme.dart';
import 'views/catalogo_publico_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CatalogoPreviewApp());
}

class CatalogoPreviewApp extends StatelessWidget {
  const CatalogoPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Accesorios Ayala — Catálogo Oficial',
      theme: lightMode,
      home: const CatalogoPublicoView(),
    );
  }
}
