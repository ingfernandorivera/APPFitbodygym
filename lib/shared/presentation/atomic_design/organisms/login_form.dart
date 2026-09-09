import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../features/auth/pages/register_page.dart';
import '../atoms/form_error_text.dart';
import '../atoms/submit_button.dart';
import '../molecules/app_text_field.dart';
import '../molecules/auth_header.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> recover() async {
    if (email.text.trim().isEmpty) {
      setState(() => error = 'Escribe primero tu correo electronico.');
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.text.trim(),
        redirectTo: 'https://ingfernandorivera.github.io/APPFitbodygym/',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Revisa tu correo para crear una nueva contrasena.'),
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AuthHeader(
          icon: Icons.fitness_center,
          iconSize: 64,
          title: 'FIT BODY GYM',
          titleFontSize: 27,
          subtitle: 'Acceso exclusivo para miembros',
          subtitleColor: Colors.white60,
          titleSubtitleSpacing: 8,
        ),
        const SizedBox(height: 34),
        AppTextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          labelText: 'Correo electronico',
          prefixIcon: Icons.email_outlined,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: password,
          obscureText: true,
          labelText: 'Contrasena',
          prefixIcon: Icons.lock_outline,
          textInputAction: TextInputAction.done,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FormErrorText(error!),
          ),
        const SizedBox(height: 20),
        SubmitButton(label: 'INGRESAR', loading: loading, onPressed: login),
        TextButton(
          onPressed: recover,
          child: const Text('Olvide mi contrasena'),
        ),
        TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterPage()),
            );
          },
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Crear cuenta nueva'),
        ),
      ],
    );
  }
}
