import 'package:flutter/material.dart';

import '../../../shared/presentation/atomic_design/atoms/section_title.dart';
import '../../../shared/presentation/atomic_design/atoms/submit_button.dart';
import '../data/training_profile_store.dart';
import '../models/training_profile.dart';
import '../widgets/assessment_number_field.dart';

class TrainingAssessmentPage extends StatefulWidget {
  const TrainingAssessmentPage({super.key, this.initialProfile});

  final TrainingProfile? initialProfile;

  @override
  State<TrainingAssessmentPage> createState() => _TrainingAssessmentPageState();
}

class _TrainingAssessmentPageState extends State<TrainingAssessmentPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController weight;
  late final TextEditingController height;
  late final TextEditingController age;
  late final TextEditingController preferences;
  late final TextEditingController limitations;
  late String goal;
  late String experience;
  late int days;
  late int minutes;
  late String weightUnit;
  var saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    weightUnit = profile?.weightUnit ?? 'kg';
    final initialWeight = profile == null
        ? ''
        : weightUnit == 'lb'
        ? (profile.weightKg * 2.2046226218).toStringAsFixed(1)
        : profile.weightKg.toStringAsFixed(1);
    weight = TextEditingController(text: initialWeight);
    height = TextEditingController(text: profile?.heightCm.toString() ?? '');
    age = TextEditingController(text: profile?.age.toString() ?? '');
    preferences = TextEditingController(text: profile?.preferences ?? '');
    limitations = TextEditingController(text: profile?.limitations ?? '');
    goal = profile?.goal ?? 'Bajar grasa';
    experience = profile?.experience ?? 'Principiante';
    days = profile?.daysPerWeek ?? 3;
    minutes = profile?.minutesPerSession ?? 60;
  }

  @override
  void dispose() {
    weight.dispose();
    height.dispose();
    age.dispose();
    preferences.dispose();
    limitations.dispose();
    super.dispose();
  }

  String? validateNumber(String? value, double min, double max) {
    final number = double.tryParse(value?.replaceAll(',', '.') ?? '');
    if (number == null || number < min || number > max) {
      return 'Ingresa un valor entre ${min.toInt()} y ${max.toInt()}';
    }
    return null;
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final enteredWeight = double.parse(weight.text.replaceAll(',', '.'));
    final profile = TrainingProfile(
      weightKg: weightUnit == 'lb' ? enteredWeight / 2.2046226218 : enteredWeight,
      heightCm: double.parse(height.text.replaceAll(',', '.')),
      age: int.parse(age.text),
      goal: goal,
      experience: experience,
      daysPerWeek: days,
      minutesPerSession: minutes,
      preferences: preferences.text.trim(),
      limitations: limitations.text.trim(),
      weightUnit: weightUnit,
    );
    await TrainingProfileStore().save(profile);
    if (mounted) Navigator.pop(context, profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evaluación inicial')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Estos datos permitirán crear una rutina segura y adaptada a ti.',
            ),
            const SizedBox(height: 24),
            const SectionTitle('Datos físicos'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AssessmentNumberField(
                    controller: weight,
                    label: 'Peso actual',
                    suffix: weightUnit,
                    allowDecimal: true,
                    validator: (value) => weightUnit == 'kg'
                        ? validateNumber(value, 30, 300)
                        : validateNumber(value, 66, 661),
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'kg', label: Text('kg')),
                    ButtonSegment(value: 'lb', label: Text('lb')),
                  ],
                  selected: {weightUnit},
                  onSelectionChanged: (selection) {
                    final newUnit = selection.first;
                    if (newUnit == weightUnit) return;
                    final current = double.tryParse(
                      weight.text.replaceAll(',', '.'),
                    );
                    setState(() {
                      if (current != null) {
                        final converted = newUnit == 'lb'
                            ? current * 2.2046226218
                            : current / 2.2046226218;
                        weight.text = converted.toStringAsFixed(1);
                      }
                      weightUnit = newUnit;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            AssessmentNumberField(
              controller: height,
              label: 'Altura',
              suffix: 'cm',
              allowDecimal: true,
              validator: (value) => validateNumber(value, 100, 250),
            ),
            const SizedBox(height: 12),
            AssessmentNumberField(
              controller: age,
              label: 'Edad',
              suffix: 'años',
              validator: (value) => validateNumber(value, 14, 100),
            ),
            const SizedBox(height: 24),
            const SectionTitle('Tu entrenamiento'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: goal,
              decoration: const InputDecoration(
                labelText: 'Objetivo principal',
              ),
              items:
                  const [
                        'Bajar grasa',
                        'Ganar masa muscular',
                        'Mejorar condición física',
                        'Aumentar fuerza',
                        'Mantenerme activo',
                      ]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
              onChanged: (value) => goal = value!,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: experience,
              decoration: const InputDecoration(labelText: 'Experiencia'),
              items: const ['Principiante', 'Intermedio', 'Avanzado']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => experience = value!,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: days,
              decoration: const InputDecoration(labelText: 'Días por semana'),
              items: [2, 3, 4, 5, 6]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value días'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => days = value!,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: minutes,
              decoration: const InputDecoration(labelText: 'Tiempo por sesión'),
              items: [30, 45, 60, 75, 90, 105, 120, 150, 180]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value minutos'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => minutes = value!,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: preferences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Preferencias (opcional)',
                hintText: 'Ejercicios que disfrutas o deseas evitar',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: limitations,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Lesiones, molestias o limitaciones',
                hintText: 'Escribe “Ninguna” si no tienes',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Indica si tienes alguna limitación'
                  : null,
            ),
            const SizedBox(height: 24),
            SubmitButton(
              label: widget.initialProfile == null
                  ? 'Crear mi perfil'
                  : 'Guardar cambios',
              loading: saving,
              onPressed: save,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
