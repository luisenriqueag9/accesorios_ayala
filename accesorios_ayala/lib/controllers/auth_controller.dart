import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthController {
  static const String _claveUltimoCorreo = 'admin_ultimo_correo';
  static const String _claveRecordarCorreo = 'admin_recordar_correo';

  static const Set<String> uidsAdminAutorizados = {
    'sK72fiKvY0crBfUzpP4TuqnHhBE3',
    'PefdVcw7gRayt1hgCUAZt7ejgYO2',
  };

  static bool esAdminAutorizado(User? user) {
    if (user == null) return false;
    return uidsAdminAutorizados.contains(user.uid);
  }

  static Future<bool> obtenerPreferenciaRecordarCorreo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_claveRecordarCorreo) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> guardarPreferenciaRecordarCorreo(bool recordar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveRecordarCorreo, recordar);
      if (!recordar) {
        await prefs.remove(_claveUltimoCorreo);
      }
    } catch (_) {
      // No bloquear la interfaz si falla el almacenamiento local.
    }
  }

  static Future<String?> obtenerUltimoCorreoGuardado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_claveUltimoCorreo);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _guardarUltimoCorreo(String correo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveUltimoCorreo, correo);
    } catch (_) {
      // No bloquear el inicio de sesión si falla el almacenamiento local.
    }
  }

  static Future<void> cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
  }

  final TextEditingController userCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();

  // Mantiene compatibilidad de compilación con RegisterView sin almacenar
  // contraseñas locales ni permitir el registro público de usuarios.
  Future<void> registerUser(String user, String pass) async {
    // Las cuentas administrativas se gestionan exclusivamente desde Firebase Console.
  }

  // Validar e iniciar sesión con Firebase Authentication
  Future<void> login(
    BuildContext context, {
    bool recordarCorreo = true,
  }) async {
    final inputEmail = userCtrl.text.trim();
    final inputPass = passCtrl.text;

    if (inputEmail.isEmpty || inputPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, ingresa tu correo electrónico y contraseña.',
          ),
        ),
      );
      return;
    }

    try {
      final credencial = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: inputEmail,
        password: inputPass,
      );

      if (!esAdminAutorizado(credencial.user)) {
        await FirebaseAuth.instance.signOut();
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esta cuenta no tiene permisos administrativos'),
          ),
        );
        return;
      }

      if (recordarCorreo) {
        final correoAutorizado = credencial.user?.email?.trim();
        await guardarPreferenciaRecordarCorreo(true);
        await _guardarUltimoCorreo(
          (correoAutorizado != null && correoAutorizado.isNotEmpty)
              ? correoAutorizado
              : inputEmail,
        );
      } else {
        await guardarPreferenciaRecordarCorreo(false);
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      final mensaje = _obtenerMensajeErrorAuth(e.code);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ocurrió un error inesperado al iniciar sesión. Intenta nuevamente.',
          ),
        ),
      );
    }
  }

  String _obtenerMensajeErrorAuth(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El formato del correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo electrónico o contraseña incorrectos.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Intenta más tarde.';
      case 'network-request-failed':
        return 'Error de conexión. Verifica tu acceso a internet.';
      default:
        return 'No se pudo iniciar sesión. Verifica tus credenciales.';
    }
  }

  void dispose() {
    userCtrl.dispose();
    passCtrl.dispose();
  }
}
