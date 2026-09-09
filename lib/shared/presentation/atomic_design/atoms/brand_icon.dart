import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class BrandIcon extends StatelessWidget {
  const BrandIcon({
    super.key,
    required this.icon,
    required this.size,
    this.color = AppColors.brand,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .48),
            blurRadius: size * .32,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, size: size, color: color),
    );
  }
}
