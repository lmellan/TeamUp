import 'package:flutter/material.dart';
import 'onboarding_activities_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Indicadores (3 puntos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Dot(
                      active: true, // <-- esta pantalla es la primera
                      color: cs.secondary,
                    ),
                    const SizedBox(width: 8),
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
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar/círculo con icono
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(isDark ? 0.30 : 0.20),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.check_circle,
                          size: 48,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Bienvenido a TeamUp',
                        textAlign: TextAlign.center,
                        style: t.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Text(
                          'Conecta. Entrena. Disfruta.',
                          textAlign: TextAlign.center,
                          style: t.titleMedium?.copyWith(
                            color: cs.onBackground.withOpacity(0.70),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Botón “Comenzar”
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
 
                      builder: (_) => const OnboardingActivitiesScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Comenzar',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget para los puntos
class _Dot extends StatelessWidget {
  const _Dot({this.active = false, required this.color});
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
