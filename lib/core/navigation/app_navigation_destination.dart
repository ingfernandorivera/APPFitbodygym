import 'package:flutter/material.dart';

class AppNavigationDestination {
  const AppNavigationDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.tooltip,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String tooltip;
}
