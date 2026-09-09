import 'package:flutter/material.dart';

class MembershipTemplate extends StatelessWidget {
  const MembershipTemplate({
    super.key,
    required this.title,
    required this.onSignOut,
    required this.body,
  });

  final String title;
  final VoidCallback onSignOut;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(onPressed: onSignOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: body,
    );
  }
}
