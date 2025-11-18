import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final pwd1 = TextEditingController();
  final pwd2 = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _resetPassword() async {
    if (pwd1.text != pwd2.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    if (pwd1.text.length < 6) {
      setState(() => _error = 'Debe tener al menos 6 caracteres');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pwd1.text),
      );

      // Mensaje en pantalla
      setState(() {
        _success = 'Contraseña actualizada correctamente 🎉';
      });

      // Esperar un momento y volver al login
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: pwd1,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwd2,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar contraseña',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null)
              Text(_error!, style: TextStyle(color: cs.error)),
            if (_success != null)
              Text(_success!, style: TextStyle(color: cs.primary)),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _resetPassword,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Actualizar contraseña'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
