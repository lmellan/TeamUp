import 'package:flutter/material.dart';
import 'onboarding_create_activities_screen.dart';

class OnboardingActivitiesScreen extends StatelessWidget {
  const OnboardingActivitiesScreen({super.key});

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
                    active: true,
                    color: cs.secondary,
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

            // Contenido principal centrado verticalmente
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hero (imagen con mismo estilo que la otra vista)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(
                                'https://lh3.googleusercontent.com/aida-public/AB6AXuAbG7hEj_PbITtacWE0qqktSRE3pj6WOwkeIG_JmRamec8PpKJUVU682CQrGgyJHKD48VizSzLfMhCRJGI2wE_HwlKuMtjbDVs0E72RgzUu7dugMAGyFJZyQ-GOGP5x-yYWdQJByv9ksJI3URk8MQlt2lGEVw8guvAPVdcEjh9df9XCgs_EFJEvCXjqNI-Lxjtpl7FTzHEM3_iB2hHbOdyz_hbq8xeeLgDSrZd0ZHzTTNaYuii5KZZY49kufrBIrdWSaN83S35ZuQU',
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
                          'Encuentra actividades',
                          textAlign: TextAlign.center,
                          style: t.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : const Color(0xFF0B0B0B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Descubre las actividades deportivas que se realizan cerca de ti. Únete a partidos, conoce gente nueva y mantente activo.',
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
                        builder: (_) => const OnboardingCreateActivitiesScreen(),
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
