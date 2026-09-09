import 'package:flutter/material.dart';

class AssessmentNumberField extends StatelessWidget {
  const AssessmentNumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.suffix,
    required this.validator,
    this.allowDecimal = false,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final FormFieldValidator<String> validator;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: validator,
    );
  }
}
