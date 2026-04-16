import 'package:flutter/material.dart';

class AppColors {
  static const Color primario = Color(0xFF00B7D4);          // Turquesa cielo
  static const Color fondoSuave = Color(0xFFF9FEFF);        // Fondo blanco-azulado
  static const Color textoOscuro = Color(0xFF1A1A1A);       // Negro suave
  static const Color grisSuave = Color(0xFFE3E9EB);         // Bordes
  static const Color grisMedio = Color(0xFF9AA7AF);         // Hints
}

final ThemeData lightMode = ThemeData(
  useMaterial3: true,

  brightness: Brightness.light,

  colorScheme: ColorScheme.light(
    primary: AppColors.primario,         // Tu botón usa esto
    onPrimary: Colors.white,
    surface: AppColors.fondoSuave,
    onSurface: AppColors.textoOscuro,
  ),

  scaffoldBackgroundColor: AppColors.fondoSuave,

  // Para todo el texto
  textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppColors.textoOscuro,
        displayColor: AppColors.textoOscuro,
      ),

  // Para inputs (MisTextfield usa estos bordes)
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    hintStyle: TextStyle(
      color: AppColors.grisMedio,
      fontSize: 15,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.grisSuave),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.primario, width: 2),
    ),
  ),

  // AppBar turquesa limpio
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primario,
    foregroundColor: Colors.white,
    centerTitle: true,
    elevation: 0,
  ),
);

// Por si en el futuro querés DarkMode
final ThemeData darkMode = ThemeData.dark();
