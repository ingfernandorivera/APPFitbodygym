import 'package:flutter/material.dart';

import '../../../shared/presentation/atomic_design/organisms/login_form.dart';
import '../../../shared/presentation/atomic_design/templates/centered_form_template.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CenteredFormTemplate(children: [LoginForm()]);
  }
}
