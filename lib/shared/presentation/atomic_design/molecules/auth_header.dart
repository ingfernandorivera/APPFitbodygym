import 'package:flutter/material.dart';

import '../atoms/brand_icon.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.title,
    required this.titleFontSize,
    this.subtitle,
    this.subtitleColor = Colors.white70,
    this.iconTitleSpacing = 18,
    this.titleSubtitleSpacing = 8,
  });

  final IconData icon;
  final double iconSize;
  final String title;
  final double titleFontSize;
  final String? subtitle;
  final Color subtitleColor;
  final double iconTitleSpacing;
  final double titleSubtitleSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BrandIcon(icon: icon, size: iconSize),
        SizedBox(height: iconTitleSpacing),
        Text(
          title,
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          SizedBox(height: titleSubtitleSpacing),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(color: subtitleColor, height: 1.5),
          ),
        ],
      ],
    );
  }
}
