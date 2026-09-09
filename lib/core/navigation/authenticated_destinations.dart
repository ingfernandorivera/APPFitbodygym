import 'package:flutter/material.dart';

import 'app_navigation_destination.dart';

abstract final class AuthenticatedDestinations {
  static const home = AppNavigationDestination(
    label: 'Inicio',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    tooltip: 'Ir a Inicio',
  );

  static const training = AppNavigationDestination(
    label: 'Entrenar',
    icon: Icons.fitness_center_outlined,
    selectedIcon: Icons.fitness_center,
    tooltip: 'Ir a Entrenar',
  );

  static const aiChat = AppNavigationDestination(
    label: 'Chat IA',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
    tooltip: 'Ir a Chat IA',
  );

  static const info = AppNavigationDestination(
    label: 'Info',
    icon: Icons.schedule_outlined,
    selectedIcon: Icons.schedule,
    tooltip: 'Ver horarios e informacion',
  );

  static const progress = AppNavigationDestination(
    label: 'Progreso',
    icon: Icons.show_chart_outlined,
    selectedIcon: Icons.show_chart,
    tooltip: 'Ir a Progreso',
  );

  static const profile = AppNavigationDestination(
    label: 'Perfil',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    tooltip: 'Ir a Perfil',
  );

  static const all = [home, training, aiChat, progress, info, profile];
}
