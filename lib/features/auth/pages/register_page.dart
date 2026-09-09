import 'package:flutter/material.dart';

import '../../../shared/presentation/atomic_design/organisms/register_form.dart';
import '../../../shared/presentation/atomic_design/templates/centered_form_template.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CenteredFormTemplate(children: [RegisterForm()]);
  }
}
