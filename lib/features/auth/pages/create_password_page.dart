import 'package:flutter/material.dart';

import '../../../shared/presentation/atomic_design/organisms/create_password_form.dart';
import '../../../shared/presentation/atomic_design/templates/centered_form_template.dart';

class CreatePasswordScreen extends StatelessWidget {
  const CreatePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CenteredFormTemplate(children: [CreatePasswordForm()]);
  }
}
