import 'package:flutter/material.dart';

import '../atoms/supporting_text.dart';
import '../molecules/feature_list_item.dart';

class FeaturePlaceholderPanel extends StatelessWidget {
  const FeaturePlaceholderPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.items,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<FeatureListItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(icon, size: 54, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        SupportingText(description, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ...items,
      ],
    );
  }
}
