import 'package:flutter/material.dart';
import 'login_screen.dart';

class OnboardingCreateActivitiesScreen extends StatelessWidget {
  const OnboardingCreateActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Indicadores (3 puntos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Dot(
                    color: isDark
                        ? const Color(0xFF3F3F46)
                        : const Color(0xFFD4D4D8),
                  ),
                  const SizedBox(width: 8),
                  _Dot(
                    color: isDark
                        ? const Color(0xFF3F3F46)
                        : const Color(0xFFD4D4D8),
                  ),
                  const SizedBox(width: 8),
                  _Dot(
                    active: true,
                    color: cs.secondary, // <-- aquí usamos el ámbar del tema
                  ),
                ],
              ),
            ),


 
            // Contenido principal centrado verticalmente
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hero (con padding lateral)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24), // <-- agrega espacio a los lados
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(
                                'https://lh3.googleusercontent.com/aida-public/AB6AXuAbUpK9pGnF1CgDjVqnmXcS_c9oCKrdewt_FhJ1WaEYOz98JCukAipFApDWM_Lg-s9SmHYlueh9rPcr6pbJVI-uq0AykUssfErIJFMddODWp_4qHpmRqJr088w3vmkQkFPAHXjwR5yna-hgLxi9ehCVM8xDTe0CQvFKs9IIHd0bSATSYKi4QZn-VMFahCnIGmwfONPztrPSKzBAPS2BTPADp7A0KRLO-M6YIi4FKhmpeNg9M14OiJWqIWUpduWFdc6X8ogCwyjcVjU',
                              ),
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          ),
                          height: 320,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Título + descripción
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(
                          'Crea actividades',
                          textAlign: TextAlign.center,
                          style: t.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0B0B0B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Organiza tus propios eventos deportivos e invita a tus amigos o a la comunidad a unirse.',
                          textAlign: TextAlign.center,
                          style: t.bodyMedium?.copyWith(
                            height: 1.35,
                            color: isDark
                                ? const Color(0xFF9CA3AF) // zinc-400
                                : const Color(0xFF52525B), // zinc-600
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

 
            // Footer con botón “Siguiente” 
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Siguiente'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.active = false, required this.color});
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
 