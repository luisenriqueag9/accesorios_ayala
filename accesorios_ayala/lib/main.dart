import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'controllers/auth_controller.dart';
import 'views/catalogo_publico_view.dart';
import 'views/home_view.dart';
import 'views/login_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Route<dynamic> _generarRuta(RouteSettings settings) {
    final nombreRuta = settings.name ?? '/';
    final uri = Uri.tryParse(nombreRuta);
    final path = uri?.path ?? nombreRuta;

    if (path == '/admin') {
      return MaterialPageRoute(
        settings: const RouteSettings(name: '/admin'),
        builder: (_) => const _AdminAuthGate(),
      );
    }

    // Ruta '/' y cualquier ruta desconocida muestran el catálogo público
    return MaterialPageRoute(
      settings: const RouteSettings(name: '/'),
      builder: (_) => const CatalogoPublicoView(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.red,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
          bodyLarge: TextStyle(color: Colors.black),
        ),

        inputDecorationTheme: const InputDecorationTheme(
          hintStyle: TextStyle(color: Colors.black45, fontSize: 16),
          labelStyle: TextStyle(color: Colors.black87),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.redAccent, width: 1.3),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 1.8),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),

      initialRoute: '/',
      onGenerateRoute: _generarRuta,
      onUnknownRoute: _generarRuta,
    );
  }
}

class _AdminAuthGate extends StatefulWidget {
  const _AdminAuthGate();

  @override
  State<_AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<_AdminAuthGate> {
  late final Stream<User?> _authStream =
      FirebaseAuth.instance.authStateChanges();
  bool _cerrandoSesionNoAutorizada = false;

  void _programarCierreSesionNoAutorizada() {
    if (_cerrandoSesionNoAutorizada) return;
    _cerrandoSesionNoAutorizada = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (FirebaseAuth.instance.currentUser != null &&
            !AuthController.esAdminAutorizado(
              FirebaseAuth.instance.currentUser,
            )) {
          await FirebaseAuth.instance.signOut();
        }
      } finally {
        _cerrandoSesionNoAutorizada = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFFFF1F1),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD9232E),
              ),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginView();
        }

        if (AuthController.esAdminAutorizado(user)) {
          return const HomeView();
        }

        _programarCierreSesionNoAutorizada();
        return const LoginView();
      },
    );
  }
}
