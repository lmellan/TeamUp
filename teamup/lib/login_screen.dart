import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_account_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } on AuthException catch (e, st) {
      setState(() => _error = e.message.isNotEmpty
          ? e.message
          : 'Error de autenticación (${e.statusCode ?? 'desconocido'})');
      debugPrint('AuthException ⇒ status:${e.statusCode} msg:${e.message}\n$st');
    } catch (e, st) {
      setState(() => _error = 'Error inesperado: $e');
      debugPrint('Unexpected error in _signIn ⇒ $e\n$st');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Ingresa tu correo para recuperar tu contraseña.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Si el correo existe, te enviamos instrucciones.')),
        );
      }
    } on AuthException catch (e, st) {
      setState(() => _error = e.message.isNotEmpty
          ? e.message
          : 'Error de autenticación (${e.statusCode ?? 'desconocido'})');
      debugPrint('AuthException in resetPassword ⇒ status:${e.statusCode} msg:${e.message}\n$st');
    } catch (e, st) {
      setState(() => _error = 'Error inesperado: $e');
      debugPrint('Unexpected error in resetPassword ⇒ $e\n$st');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final onSurfaceVariant = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.75)
        : const Color(0xFF757575);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  Text('TeamUp',
                      style: t.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      )),
                  const SizedBox(height: 16),
                  Text('Bienvenido de nuevo',
                      style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      )),
                  const SizedBox(height: 8),
                  Text('Inicia sesión para continuar tu viaje',
                      style: t.bodyMedium?.copyWith(color: onSurfaceVariant),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),

                  // Formulario
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa tu correo electrónico';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Contraseña
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Ingresa tu contraseña';
                            }
                            if (v.length < 6) {
                              return 'Debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        // Recuperar contraseña
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _loading ? null : _resetPassword,
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                          ],
                        ),

                        // Mensaje de error
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: TextStyle(color: cs.error)),
                        ],

                        const SizedBox(height: 8),

                        // Botón de inicio de sesión
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: _loading ? null : _signIn,
                            child: _loading
                                ? const CircularProgressIndicator()
                                : const Text('Iniciar sesión'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Divider "O continuar con"
                  Row(
                    children: [
                      Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'O continuar con',
                          style: t.bodySmall?.copyWith(color: onSurfaceVariant),
                        ),
                      ),
                      Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Botones sociales (placeholder)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(shape: const CircleBorder()),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Google OAuth próximamente')),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.g_mobiledata, size: 32),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(shape: const CircleBorder()),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Otro proveedor próximamente')),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.alternate_email, size: 28),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Footer registro
                  Text.rich(
                    TextSpan(
                      text: "¿No tienes una cuenta? ",
                      style: t.bodyMedium?.copyWith(color: onSurfaceVariant),
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
                            ),
                            child: const Text('Regístrate'),
                          ),

                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
