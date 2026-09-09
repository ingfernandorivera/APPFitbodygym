import 'package:flutter/material.dart';

import '../../../shared/presentation/atomic_design/molecules/app_text_field.dart';
import '../data/app_user_profile_store.dart';
import '../models/app_user_profile.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.initialProfile});

  final AppUserProfile initialProfile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final fullName = TextEditingController(
    text: widget.initialProfile.fullName,
  );
  late final birthDate = TextEditingController(
    text: widget.initialProfile.birthDate,
  );
  late final phone = TextEditingController(text: widget.initialProfile.phone);
  late final goal = TextEditingController(text: widget.initialProfile.goal);
  late final limitations = TextEditingController(
    text: widget.initialProfile.limitations,
  );
  bool saving = false;

  @override
  void dispose() {
    fullName.dispose();
    birthDate.dispose();
    phone.dispose();
    goal.dispose();
    limitations.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    final profile = AppUserProfile(
      fullName: fullName.text.trim(),
      birthDate: birthDate.text.trim(),
      phone: phone.text.trim(),
      goal: goal.text.trim(),
      limitations: limitations.text.trim(),
    );
    await AppUserProfileStore().save(profile);
    if (mounted) Navigator.pop(context, profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppTextField(
            controller: fullName,
            labelText: 'Nombre completo',
            prefixIcon: Icons.person_outline,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: birthDate,
            labelText: 'Fecha de nacimiento',
            prefixIcon: Icons.cake_outlined,
            keyboardType: TextInputType.datetime,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: phone,
            labelText: 'Telefono',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: goal,
            labelText: 'Objetivo principal',
            prefixIcon: Icons.flag_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: limitations,
            labelText: 'Limitaciones o lesiones',
            prefixIcon: Icons.health_and_safety_outlined,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Guardar perfil'),
            ),
          ),
        ],
      ),
    );
  }
}
