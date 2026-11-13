import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../utils/widgets/glass_container.dart';
import '../utils/widgets/mis_textfield.dart';
import '../utils/widgets/mis_button.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final AuthController _auth = AuthController();
  final FocusNode _passFocusNode = FocusNode();
  bool _iniciandoSesion = false;
  bool _ocultarPassword = true;

  static const Color _rojoPrincipal = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F1);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisSubtitulo = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0D4D6);

  @override
  void initState() {
    super.initState();
    _cargarUltimoCorreo();
  }

  Future<void> _cargarUltimoCorreo() async {
    final correoGuardado = await AuthController.obtenerUltimoCorreoGuardado();
    if (!mounted || correoGuardado == null || correoGuardado.trim().isEmpty) {
      return;
    }

    if (_auth.userCtrl.text.isEmpty) {
      _auth.userCtrl.text = correoGuardado.trim();
    }
  }

  @override
  void dispose() {
    _passFocusNode.dispose();
    _auth.dispose();
    super.dispose();
  }

  Future<void> _manejarLogin() async {
    if (_iniciandoSesion) return;

    setState(() {
      _iniciandoSesion = true;
    });

    try {
      await _auth.login(context);
    } finally {
      if (mounted) {
        setState(() {
          _iniciandoSesion = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final temaBase = Theme.of(context);
    final temaLogin = temaBase.copyWith(
      colorScheme: temaBase.colorScheme.copyWith(
        primary: _iniciandoSesion
            ? _rojoPrincipal.withValues(alpha: 0.70)
            : _rojoPrincipal,
        inversePrimary: Colors.white,
        onSurface: _negroElegante,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _bordeSuave, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _rojoPrincipal, width: 2),
        ),
      ),
    );

    return Theme(
      data: temaLogin,
      child: Scaffold(
        backgroundColor: _rosaSuave,
        body: Stack(
          children: [
            // Fondo degradado suave estilo boutique
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFF4F5),
                    Color(0xFFFFE6E8),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),

            // Detalles decorativos discretos para realzar el efecto glassmorphism
            Positioned(
              top: -90,
              right: -70,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _rojoPrincipal.withValues(alpha: 0.14),
                      _rojoPrincipal.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -110,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _rojoPrincipal.withValues(alpha: 0.12),
                      _rojoPrincipal.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Contenido centrado y desplazable para pantallas pequeñas
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: _rojoPrincipal.withValues(alpha: 0.08),
                            blurRadius: 32,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: GlassContainer(
                        blur: 18,
                        opacity: 0.72,
                        borderRadius: 24,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 34,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo oficial
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _bordeSuave,
                                  width: 1,
                                ),
                              ),
                              child: Image.asset(
                                'assets/logo/logo_ayala.png',
                                width: 84,
                                height: 84,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.diamond_outlined,
                                  size: 48,
                                  color: _rojoPrincipal,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Identidad de la marca
                            const Text(
                              'Accesorios Ayala',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _negroElegante,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _rosaSuave,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _bordeSuave),
                              ),
                              child: const Text(
                                'Acceso administrativo',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _grisSubtitulo,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Campos del formulario
                            MisTextfield(
                              controller: _auth.userCtrl,
                              hintText: 'Correo electrónico',
                              obscureText: false,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _passFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: 16),
                            MisTextfield(
                              controller: _auth.passCtrl,
                              focusNode: _passFocusNode,
                              hintText: 'Contraseña',
                              obscureText: _ocultarPassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _manejarLogin(),
                              suffixIcon: IconButton(
                                tooltip: _ocultarPassword
                                    ? 'Mostrar contraseña'
                                    : 'Ocultar contraseña',
                                icon: Icon(
                                  _ocultarPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: _ocultarPassword
                                      ? _grisSubtitulo
                                      : _rojoPrincipal,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _ocultarPassword = !_ocultarPassword;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 26),

                            // Botón de ingreso
                            MouseRegion(
                              cursor: _iniciandoSesion
                                  ? SystemMouseCursors.basic
                                  : SystemMouseCursors.click,
                              child: MisButtons(
                                text: _iniciandoSesion
                                    ? "Ingresando..."
                                    : "Ingresar",
                                onTap: _iniciandoSesion ? null : _manejarLogin,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
