import 'package:flutter/material.dart';

import '../../../../core/navigation/app_navigation_destination.dart';
import '../organisms/main_navigation_bar.dart';

class MainNavigationTemplate extends StatelessWidget {
  const MainNavigationTemplate({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.pages,
    required this.onSignOut,
  });

  final List<AppNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> pages;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(destinations[selectedIndex].label),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 88),
        child: IndexedStack(index: selectedIndex, children: pages),
      ),
      bottomNavigationBar: MainNavigationBar(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
      ),
    );
  }
}
