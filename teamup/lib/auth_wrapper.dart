// lib/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teamup/ui/explore_screen.dart';
import '/ui/welcome_screen.dart';     // Tu pantalla principal
import '/ui/login_screen.dart'; // Tu pantalla de login/bienvenida

class AuthWrapper extends StatelessWidget {
  // Obtenemos la instancia global de Supabase
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    
    return StreamBuilder<AuthState>(
      stream: _supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        if (session != null) {
          
          return ExploreScreen(); 
        } else {

          return const WelcomeScreen(); 
        }
      },
    );
  }
}