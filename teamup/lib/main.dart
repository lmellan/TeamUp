import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'componentes/app_theme.dart';

import '/ui/welcome_screen.dart';
import '/ui/login_screen.dart';
import '/ui/complete_perfil_screen.dart';
import '/ui/create_account_screen.dart';
import '/ui/profile_screen.dart';
import '/ui/explore_screen.dart';
import '/ui/view_activity_screen.dart'; // ActivityDetailScreen
import 'ui/create_activity_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env
  await dotenv.load(fileName: 'supabase.env');

  // Intl: inicializa el MISMO locale que usarás en la app
  await initializeDateFormatting('es'); // o 'es_CL'
  Intl.defaultLocale = 'es';            // o 'es_CL'

  // Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeamUp',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,

      // Localización
      locale: const Locale('es'), // usa 'es_CL' si prefieres
      supportedLocales: const [
        Locale('es'),
        Locale('es', 'CL'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Home y rutas
      home: const WelcomeScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/complete-perfil': (_) => const CompletePerfilScreen(),
        '/perfil': (_) => const ProfileScreen(),
        '/explore': (_) => ExploreScreen(),
        '/create-account': (_) => const CreateAccountScreen(),
        '/create': (_) => CreateActivityScreen(), 
        '/detail-activity': (context) {
          final id = ModalRoute.of(context)!.settings.arguments as String;
          return ActivityDetailScreen(activityId: id);
        },
        // '/edit-profile': (_) => const EditProfileScreen(),
      },
    );
  }
}
