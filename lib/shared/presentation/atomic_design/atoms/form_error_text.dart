import 'package:flutter/material.dart';

class FormErrorText extends StatelessWidget {
  const FormErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(color: Colors.redAccent),
      textAlign: TextAlign.center,
    );
  }
}
