import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailCtrl = TextEditingController();
  bool _loading = false;
  String? _message;

  Future<void> _sendResetEmail() async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _message = 'Ingresa tu correo');
      return;
    }

    setState(() { _loading = true; _message = null; });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'teamup://reset-password'
      );
      setState(() =>
          _message = 'Te enviamos un correo para recuperar tu contraseña.');
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ingresa tu correo y te enviaremos un enlace para recuperar tu contraseña.',
            ),
            const SizedBox(height: 16),

            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),

            const SizedBox(height: 16),

            FilledButton(
              onPressed: _loading ? null : _sendResetEmail,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Enviar correo'),
            ),

            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                style: TextStyle(color: cs.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
