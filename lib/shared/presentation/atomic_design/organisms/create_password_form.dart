import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../atoms/form_error_text.dart';
import '../atoms/submit_button.dart';
import '../molecules/app_text_field.dart';
import '../molecules/auth_header.dart';

class CreatePasswordForm extends StatefulWidget {
  const CreatePasswordForm({super.key});

  @override
  State<CreatePasswordForm> createState() => _CreatePasswordFormState();
}

class _CreatePasswordFormState extends State<CreatePasswordForm> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool loading = false;
  bool showPassword = false;
  bool showConfirmation = false;
  bool passwordUpdated = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (password.text.length < 8) {
      setState(() => error = 'La contraseña debe tener al menos 8 caracteres.');
      return;
    }
    if (password.text != confirmation.text) {
      setState(() => error = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: password.text,
          data: const {'password_created': true},
        ),
      );
      if (mounted) {
        password.clear();
        confirmation.clear();
        setState(() => passwordUpdated = true);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (passwordUpdated) {
      return Column(
        children: [
          const AuthHeader(
            icon: Icons.check_circle_outline,
            iconSize: 70,
            title: 'CONTRASEÑA ACTUALIZADA',
            titleFontSize: 25,
            subtitle:
                'Tu contraseña se cambió correctamente. Ya puedes volver a la app e iniciar sesión.',
            subtitleColor: Colors.white70,
            iconTitleSpacing: 20,
            titleSubtitleSpacing: 10,
          ),
          const SizedBox(height: 28),
          SubmitButton(
            label: 'VOLVER A LA APP',
            loading: loading,
            onPressed: () async {
              setState(() {
                loading = true;
                error = null;
              });
              try {
                await Supabase.instance.client.auth.signOut();
              } on AuthException catch (e) {
                if (mounted) setState(() => error = e.message);
              } finally {
                if (mounted) setState(() => loading = false);
              }
            },
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FormErrorText(error!),
            ),
        ],
      );
    }

    return Column(
      children: [
        const AuthHeader(
          icon: Icons.lock_reset,
          iconSize: 70,
          title: 'CREAR CONTRASEÑA',
          titleFontSize: 25,
          subtitle:
              'Protege tu acceso a Fit Body Gym con una contraseña personal.',
          subtitleColor: Colors.white70,
          iconTitleSpacing: 20,
          titleSubtitleSpacing: 10,
        ),
        const SizedBox(height: 28),
        AppTextField(
          controller: password,
          obscureText: !showPassword,
          labelText: 'Nueva contraseña',
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            tooltip: showPassword ? 'Ocultar contraseña' : 'Ver contraseña',
            onPressed: () => setState(() => showPassword = !showPassword),
            icon: Icon(
              showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: confirmation,
          obscureText: !showConfirmation,
          labelText: 'Confirmar contraseña',
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            tooltip: showConfirmation ? 'Ocultar contraseña' : 'Ver contraseña',
            onPressed: () =>
                setState(() => showConfirmation = !showConfirmation),
            icon: Icon(
              showConfirmation
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FormErrorText(error!),
          ),
        const SizedBox(height: 20),
        SubmitButton(
          label: 'GUARDAR CONTRASEÑA',
          loading: loading,
          onPressed: save,
        ),
      ],
    );
  }
}
