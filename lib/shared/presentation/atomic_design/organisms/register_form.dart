import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../features/profile/data/app_user_profile_store.dart';
import '../../../../features/profile/models/app_user_profile.dart';
import '../atoms/form_error_text.dart';
import '../atoms/submit_button.dart';
import '../molecules/app_text_field.dart';
import '../molecules/auth_header.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final fullName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (fullName.text.trim().isEmpty || email.text.trim().isEmpty) {
      setState(() => error = 'Completa nombre y correo.');
      return;
    }
    if (password.text.length < 8) {
      setState(() => error = 'La contrasena debe tener al menos 8 caracteres.');
      return;
    }
    if (password.text != confirmation.text) {
      setState(() => error = 'Las contrasenas no coinciden.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.signUp(
        email: email.text.trim(),
        password: password.text,
        data: {
          'full_name': fullName.text.trim(),
          'password_created': true,
        },
      );
      await AppUserProfileStore().save(
        AppUserProfile(
          fullName: fullName.text.trim(),
          birthDate: '',
          phone: '',
          goal: '',
          limitations: '',
        ),
      );
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AuthHeader(
          icon: Icons.person_add_alt_1,
          iconSize: 60,
          title: 'Crear cuenta',
          titleFontSize: 27,
          subtitle: 'Registro basico para Fit Body Gym',
          subtitleColor: Colors.white60,
          titleSubtitleSpacing: 8,
        ),
        const SizedBox(height: 28),
        AppTextField(
          controller: fullName,
          labelText: 'Nombre completo',
          prefixIcon: Icons.person_outline,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
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
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: confirmation,
          obscureText: true,
          labelText: 'Confirmar contrasena',
          prefixIcon: Icons.lock_reset,
          textInputAction: TextInputAction.done,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FormErrorText(error!),
          ),
        const SizedBox(height: 20),
        SubmitButton(
          label: 'CREAR CUENTA',
          loading: loading,
          onPressed: register,
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Ya tengo cuenta'),
        ),
      ],
    );
  }
}
