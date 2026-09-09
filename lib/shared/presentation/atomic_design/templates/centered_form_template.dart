import 'package:flutter/material.dart';

class CenteredFormTemplate extends StatelessWidget {
  const CenteredFormTemplate({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(26),
    this.maxWidth = 420,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(children: children),
            ),
          ),
        ),
      ),
    );
  }
}
