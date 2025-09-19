// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Salir',
          ),
        ],
      ),
      body: Center(child: Text('Hola, ${user?.email ?? 'usuario'}')),
    );
  }
}
