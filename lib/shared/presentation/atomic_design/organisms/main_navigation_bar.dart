import 'package:flutter/material.dart';

import '../../../../core/navigation/app_navigation_destination.dart';
import '../../../../core/theme/app_colors.dart';

class MainNavigationBar extends StatelessWidget {
  const MainNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<AppNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF210305),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.outline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
            BoxShadow(color: AppColors.neonGlow, blurRadius: 12),
          ],
        ),
        child: Row(
          children: [
            for (var index = 0; index < destinations.length; index++)
              Expanded(
                child: _FloatingDestination(
                  destination: destinations[index],
                  selected: selectedIndex == index,
                  onTap: () => onDestinationSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatingDestination extends StatelessWidget {
  const _FloatingDestination({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textMuted;
    final icon = Icon(
      selected ? destination.selectedIcon : destination.icon,
      size: selected ? 27 : 23,
      color: selected ? Colors.white : color,
      shadows: selected
          ? const [Shadow(color: AppColors.brand, blurRadius: 12)]
          : null,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: destination.tooltip,
      child: Tooltip(
        message: destination.tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.translate(
                offset: Offset(0, selected ? -12 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: selected ? 52 : 38,
                  height: selected ? 52 : 38,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.brand : Colors.transparent,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: const Color(0xFFFF6B7E))
                        : null,
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: AppColors.neonGlow,
                              blurRadius: 17,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(child: icon),
                ),
              ),
              Transform.translate(
                offset: Offset(0, selected ? -9 : -1),
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
