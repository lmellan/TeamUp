import 'package:flutter/material.dart';

class TeamUpBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const TeamUpBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const Color _muted = Color(0xFFBDBDBD); // gris pedido

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Half-hairline: mitad de 1 px físico
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final halfHairline = (1 / dpr) / 2;

    return Material(
      color: cs.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Línea superior ultra fina (≈ 0.5 px lógico en DPR=2)
          SizedBox(height: halfHairline, child: const ColoredBox(color: _muted)),

          SafeArea(
            top: false,
            
              
              child: NavigationBar(
                height: 64,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                selectedIndex: currentIndex,
                onDestinationSelected: onTap,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.explore_outlined),
                    selectedIcon: Icon(Icons.explore),
                    label: 'Explorar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.add_circle_outline),
                    selectedIcon: Icon(Icons.add_circle),
                    label: 'Crear',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.notifications_outlined),
                    selectedIcon: Icon(Icons.notifications),
                    label: 'Alertas',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Perfil',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Helper para navegar por índice
void teamUpNavigate(BuildContext context, int index) {
  switch (index) {
    case 0:
      Navigator.pushReplacementNamed(context, '/explore');
      break;
    case 1:
      Navigator.pushReplacementNamed(context, '/create');
      break;
    case 2:
      Navigator.pushReplacementNamed(context, '/alerts');
      break;
    case 3:
      Navigator.pushReplacementNamed(context, '/perfil');
      break;
  }
}
