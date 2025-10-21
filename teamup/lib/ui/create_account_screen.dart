import 'package:flutter/material.dart';
 
import '../../domain/entities/perfil.dart';
import '../../domain/services/auth_services.dart';
import '../../domain/services/perfil_services.dart';
 
import '../../data/auth_data.dart';    
import '../../data/perfil_data.dart';   

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;
  bool _acceptedTerms = true;

  // Inyección simple (si luego usas Riverpod/Provider, reemplázalo por providers)
  final AuthService _auth = AuthServiceSupabase();
  final ProfileService _profiles = ProfileServiceSupabase();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      // 1) Crear usuario (Auth)
      final userId = await _auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
      );

      // 2) Crear/actualizar perfil en tabla 'perfil'
      final profile = Profile(
        id: userId,
        name: _name.text.trim(),
        // bio/notify/preferredSports quedan por defecto
      );
      await _profiles.updateMyProfile(profile);

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/complete-perfil');
    } catch (e, st) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      // opcional: log
      // ignore: avoid_print
      print('CreateAccount error ⇒ $e\n$st');
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
                  Text('TeamUp',
                      style: t.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      )),
                  const SizedBox(height: 16),
                  Text('Crear cuenta',
                      style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      )),
                  const SizedBox(height: 8),
                  Text('Completa tus datos para comenzar',
                      style: t.bodyMedium?.copyWith(color: onSurfaceVariant),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Nombre
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Ingresa tu nombre';
                            if (v.trim().length < 2) return 'Nombre demasiado corto';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

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
                            if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                            if (!v.contains('@')) return 'Correo inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Contraseña
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure1,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure1 = !_obscure1),
                              icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                              tooltip: _obscure1 ? 'Mostrar' : 'Ocultar',
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                            if (v.length < 6) return 'Debe tener al menos 6 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Confirmación
                        TextFormField(
                          controller: _confirm,
                          obscureText: _obscure2,
                          decoration: InputDecoration(
                            labelText: 'Confirmar contraseña',
                            prefixIcon: const Icon(Icons.lock_reset),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure2 = !_obscure2),
                              icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                              tooltip: _obscure2 ? 'Mostrar' : 'Ocultar',
                            ),
                          ),
                          validator: (v) {
                            if (v != _password.text) return 'Las contraseñas no coinciden';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

 

                        if (_error != null) ...[
                          Text(_error!, style: TextStyle(color: cs.error)),
                          const SizedBox(height: 8),
                        ],

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: (_loading || !_acceptedTerms) ? null : _createAccount,
                            child: _loading
                                ? const CircularProgressIndicator()
                                : const Text('Crear cuenta'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextButton.icon(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Ya tengo una cuenta — Iniciar sesión'),
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
