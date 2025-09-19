import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'welcome_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carga variables desde supabase.env
  await dotenv.load(fileName: 'supabase.env');

  // Inicializa Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    // Si luego usas magic link / OAuth:
    // authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Paleta de colores (de la imagen)
  static const Color _primary = Color(0xFF8BC34A);
  static const Color _primaryDark = Color(0xFF689F38);
  static const Color _primaryLight = Color(0xFFDCEDC8);
  static const Color _accent = Color(0xFFFFC107);
  static const Color _textPrimary = Color(0xFF212121);
  static const Color _textSecondary = Color(0xFF757575);
  static const Color _divider = Color(0xFFBDBDBD);

  ThemeData _light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: _primary,
        onPrimary: Colors.white,
        secondary: _accent,
        onSecondary: Colors.black,
        error: Colors.red,
        onError: Colors.white,
        background: Colors.white,
        onBackground: _textPrimary,
        surface: Colors.white,
        onSurface: _textPrimary,
      ),
      scaffoldBackgroundColor: Colors.white,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: GoogleFonts.beVietnamProTextTheme(base.textTheme).apply(
        bodyColor: _textPrimary,
        displayColor: _textPrimary,
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
          backgroundColor: _primary,
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
        color: _divider,
        thickness: 1,
      ),
    );
  }

  ThemeData _dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: _primaryDark,
        onPrimary: Colors.white,
        secondary: _accent,
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
          backgroundColor: _primaryDark,
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
        color: _divider,
        thickness: 1,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeamUp',
      debugShowCheckedModeBanner: false,
      theme: _light(),
      darkTheme: _dark(),
      home: const WelcomeScreen(),  
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home' : (_) => const HomeScreen(),
      },
    );
  }
}