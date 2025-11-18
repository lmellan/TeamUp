import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:teamup/domain/entities/perfil.dart';

import 'componentes/app_theme.dart';

import '/ui/login_screen.dart';
import '/ui/complete_perfil_screen.dart';
import '/ui/create_account_screen.dart';
import '/ui/profile_screen.dart';
import '/ui/explore_screen.dart';
import '/ui/view_activity_screen.dart';
import '/ui/edit_profile_screen.dart';
import '/ui/create_activity_screen.dart';
import '/ui/forgot_password_screen.dart';
import '/ui/reset_password.dart';
import 'auth_wrapper.dart';
import '/ui/alerts_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // .env
  await dotenv.load(fileName: '.env');


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


final supabase = Supabase.instance.client;
final navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
@override
  void initState() {
    super.initState();
    supabase.auth.onAuthStateChange.listen((event) async {
      if ( event.event == AuthChangeEvent.signedIn ){
        await FirebaseMessaging.instance.requestPermission();

        await FirebaseMessaging.instance.getAPNSToken();
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if ( fcmToken != null ) {
          await _setFcmToken(fcmToken);
        }
      }

      if (event.event == AuthChangeEvent.passwordRecovery) {
      // Lo mandas a la pantalla para escribir nueva contraseña
        navigatorKey.currentState?.pushNamed('/reset-password');
      }
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
      await _setFcmToken(fcmToken);
    });
    
  }

  Future<void> _setFcmToken(String fcmToken) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('perfil').upsert({
      'id': userId,
      'fcm_token': fcmToken,
    });
    
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeamUp',
      debugShowCheckedModeBanner: false,

      navigatorKey: navigatorKey,

      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,

      // Localización
      locale: const Locale('es'), 
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
      home: AuthWrapper(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/reset-password': (_) => const ResetPasswordScreen(),
        '/complete-perfil': (_) => const CompletePerfilScreen(),
        '/perfil': (_) => const ProfileScreen(),
        '/explore': (_) => ExploreScreen(),
        '/create-account': (_) => const CreateAccountScreen(),
        '/create': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          final activityId = args?['activityId'] as String?; // null => crear, !null => editar
          return CreateActivityScreen(activityId: activityId);
        },
        '/activity/edit': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          final activityId = args?['activityId'] as String?;
          return CreateActivityScreen(activityId: activityId);
        },
        '/detail-activity': (context) {
          final id = ModalRoute.of(context)!.settings.arguments as String;
          return ActivityDetailScreen(activityId: id);
        },
        '/edit-profile': (context) {
          final profile = ModalRoute.of(context)!.settings.arguments as Profile?;
          return EditProfileScreen(profile: profile);
        },
        '/alerts': (_) => const AlertsScreen(),

      },
    );
  }
}
