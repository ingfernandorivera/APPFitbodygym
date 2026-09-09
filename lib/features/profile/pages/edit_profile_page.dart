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
  late DateTime? selectedBirthDate = _parseDate(
    widget.initialProfile.birthDate,
  );
  late final birthDate = TextEditingController(
    text: _displayDate(selectedBirthDate),
  );
  late final phone = TextEditingController(text: widget.initialProfile.phone);
  late final goal = TextEditingController(text: widget.initialProfile.goal);
  late final limitations = TextEditingController(
    text: widget.initialProfile.limitations,
  );
  bool saving = false;

  static DateTime? _parseDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;

    final isoDate = DateTime.tryParse(normalized);
    if (isoDate != null) return isoDate;

    final parts = normalized.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static String _displayDate(DateTime? date) {
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String _databaseDate(DateTime? date) {
    if (date == null) return '';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> pickBirthDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: selectedBirthDate ?? DateTime(today.year - 18),
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'Selecciona tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      fieldLabelText: 'Fecha de nacimiento',
    );
    if (selected == null || !mounted) return;
    setState(() {
      selectedBirthDate = selected;
      birthDate.text = _displayDate(selected);
    });
  }

  @override
  void dispose() {
    birthDate.dispose();
    phone.dispose();
    goal.dispose();
    limitations.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    final profile = AppUserProfile(
      fullName: widget.initialProfile.fullName,
      birthDate: _databaseDate(selectedBirthDate),
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
            controller: birthDate,
            labelText: 'Fecha de nacimiento',
            prefixIcon: Icons.cake_outlined,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
            readOnly: true,
            onTap: pickBirthDate,
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
