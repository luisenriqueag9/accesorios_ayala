import 'dart:async';
import 'package:flutter/material.dart';
import 'home_view.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with TickerProviderStateMixin {
  
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _fadeLogo;
  late Animation<double> _zoomLogo;
  late Animation<double> _slideBg;

  @override
  void initState() {
    super.initState();

    // 🔥 CONTROL DE LOGO
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeLogo = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOut,
      ),
    );

    _zoomLogo = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    // 🔥 SLIDE DEL FONDO
    _slideBg = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutQuad,
      ),
    );

    // ⏳ TEXTO ANIMADO
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    // Iniciar animaciones
    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 900), () {
      _textController.forward();
    });

    // Cambiar pantalla
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => const HomeView(),
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(
              opacity: anim,
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _logoController,
        builder: (_, __) {
          return Container(
            width: double.infinity,
            height: double.infinity,

            // 🔥 DEGRADADO TURQUESA NIVEL DIOS
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF00E6D3),
                  Color(0xFF009C88),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),

            child: Transform.translate(
              offset: Offset(0, _slideBg.value),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  
                  // LOGO con ZOOM + FADE + GLOW 🔥
                  Opacity(
                    opacity: _fadeLogo.value,
                    child: Transform.scale(
                      scale: _zoomLogo.value,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(
                                  _fadeLogo.value * 0.6),
                              blurRadius: 40 * _fadeLogo.value,
                              spreadRadius: 3,
                            )
                          ],
                        ),
                        child: Image.asset(
                          "assets/logo/logo_ayala.png",
                          width: 200,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 35),

                  // TEXTO ANIMADO ESTILO IA + BRILLO ✨
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (_, __) {
                      final progress = _textController.value;
                      final totalText = "ACCESORIOS AYALA";
                      final showChars =
                          (totalText.length * progress).clamp(0, totalText.length).toInt();

                      return ShaderMask(
                        shaderCallback: (rect) {
                          return const LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.white70,
                              Colors.white,
                            ],
                            stops: [0.0, 0.5, 1.0],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(rect);
                        },
                        child: Text(
                          totalText.substring(0, showChars),
                          style: const TextStyle(
                            fontSize: 30,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
