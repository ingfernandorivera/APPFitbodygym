import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePasswordScreen extends StatefulWidget {
  const CreatePasswordScreen({super.key});
  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool loading = false;
  String? error;
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
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const Icon(
                  Icons.lock_reset,
                  size: 70,
                  color: Color(0xFFE5243B),
                ),
                const SizedBox(height: 20),
                const Text(
                  'CREAR CONTRASEÑA',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Protege tu acceso a Fit Body Gym con una contraseña personal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: confirmation,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : save,
                    child: loading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('GUARDAR CONTRASEÑA'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
