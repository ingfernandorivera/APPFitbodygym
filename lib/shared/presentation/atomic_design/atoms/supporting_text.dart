import 'package:flutter/material.dart';

class SupportingText extends StatelessWidget {
  const SupportingText(
    this.text, {
    super.key,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.45),
    );
  }
}
