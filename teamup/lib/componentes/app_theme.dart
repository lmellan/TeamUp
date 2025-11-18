import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores centrales de la app  
class AppColors {
  static const Color primary = Color(0xFF8BC34A);
  static const Color primaryDark = Color(0xFF689F38);
  static const Color primaryLight = Color(0xFFDCEDC8);
  static const Color accent = Color(0xFFFFC107);
  static const Color accentLight = Color.fromARGB(255, 255, 244, 211); 
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFBDBDBD);
}

/// Tema de la app
class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        secondaryContainer: AppColors.accentLight,
        onSecondary: Colors.black,
        error: Colors.red,
        onError: Colors.white,
        background: Colors.white,
        onBackground: AppColors.textPrimary,
        surface: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: Colors.white,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(
        color: Colors.grey.shade400, // hintText clarito global
      ),
    ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.beVietnamProTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: base.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary, // verde
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: base.colorScheme.surface, // fondo blanco
        indicatorColor: AppColors.accentLight,     // fondo amarillo suave del tab activo
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.accent              // ícono activo amarillo
                : AppColors.divider,       // ícono inactivo gris
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.accent              // texto activo amarillo
                : AppColors.divider,       // texto inactivo
          ),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.primaryDark,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: Colors.black,
        error: Colors.red,
        onError: Colors.white,
        background: Colors.black,
        onBackground: Colors.white,
        surface: Color(0xFF212121),
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF212121),
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: GoogleFonts.beVietnamProTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: base.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: base.colorScheme.surface,
        indicatorColor: AppColors.primary.withOpacity(0.25),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? base.colorScheme.primary
                : Colors.white70,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? base.colorScheme.primary
                : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
