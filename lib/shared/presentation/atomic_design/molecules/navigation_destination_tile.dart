import 'package:flutter/material.dart';

import '../../../../core/navigation/app_navigation_destination.dart';

class NavigationDestinationTile extends StatelessWidget {
  const NavigationDestinationTile({super.key, required this.destination});

  final AppNavigationDestination destination;

  @override
  Widget build(BuildContext context) {
    return NavigationDestination(
      tooltip: destination.tooltip,
      icon: Icon(destination.icon),
      selectedIcon: Icon(destination.selectedIcon),
      label: destination.label,
    );
  }
}
