import 'dart:convert';

import 'package:fit_body_gym/features/assessment/data/training_profile_store.dart';
import 'package:fit_body_gym/features/assessment/models/assessment_rules.dart';
import 'package:fit_body_gym/features/assessment/models/training_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const legacyProfile = <String, dynamic>{
  'weightKg': 75,
  'heightCm': 172,
  'age': 28,
  'goal': 'Aumentar fuerza',
  'experience': 'Principiante',
  'daysPerWeek': 3,
  'minutesPerSession': 45,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('JSON legacy conserva valores y aporta defaults compatibles', () {
    final profile = TrainingProfile.fromJson(legacyProfile);
    expect(profile.weightKg, 75);
    expect(profile.weightUnit, 'kg');
    expect(profile.bodyRepresentation, 'Neutral');
    expect(profile.bodyFatEstimate, isNull);
    expect(profile.targetWeightKg, isNull);
    expect(profile.priorityMuscles, isEmpty);
    expect(profile.preferences, '');
    expect(profile.limitations, '');
    expect(profile.sleepHours, isNull);
  });

  test('perfil ampliado conserva todos los campos al serializar', () {
    final json = {
      ...legacyProfile,
      'weightUnit': 'lb',
      'targetWeightKg': 80,
      'bodyRepresentation': 'Caderas amplias',
      'bodyShape': 'Robusta',
      'bodyFatEstimate': 28.0,
      'schedule': 'Noche',
      'trainingLocation': 'Casa',
      'equipment': 'Mancuernas y bandas',
      'priorityMuscles': ['Espalda', 'Piernas'],
      'motivations': ['Tener más energía'],
      'dailyActivity': 'Camino con frecuencia',
      'sleepHours': 7.5,
      'hydrationLiters': 2.5,
      'preferences': 'Me gusta caminar',
      'limitations': 'Molestia al saltar',
    };
    final profile = TrainingProfile.fromJson(json);
    expect(
      TrainingProfile.fromJson(
        jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>,
      ).toJson(),
      profile.toJson(),
    );
    for (final key in json.keys) {
      expect(profile.toJson()[key], json[key], reason: key);
    }
  });

  test('validación rechaza NaN, infinitos, edad decimal y fuera de rango', () {
    for (final text in [
      '',
      'NaN',
      'Infinity',
      '-Infinity',
      'abc',
      '13',
      '101',
    ]) {
      expect(validateAssessmentNumber(text, 14, 100, integer: true), isNotNull);
    }
    expect(validateAssessmentNumber('28.5', 14, 100, integer: true), isNotNull);
    expect(validateAssessmentNumber('28', 14, 100, integer: true), isNull);
    expect(assessmentNumber(' 72,5 '), 72.5);
  });

  test('conversión de unidades ida y vuelta y rango visual', () {
    expect(weightToKg(weightFromKg(75, 'lb'), 'lb'), closeTo(75, 1e-9));
    expect(weightToKg(75, 'kg'), 75);
    expect(visualFatRange(28), '25–31 %');
    expect(visualFatRange(8), '5–11 %');
    expect(visualFatRange(55), '52–58 %');
  });

  test('perfil y borrador están aislados por usuario y preview', () async {
    final first = TrainingProfileStore(storageUserId: 'user-a');
    final second = TrainingProfileStore(storageUserId: 'user-b');
    final preview = TrainingProfileStore(storageUserId: 'preview');
    await first.saveDraft({
      'step': 4,
      'answers': {'goal': 'Aumentar fuerza'},
    });
    expect(await second.loadDraft(), isNull);
    await first.save(TrainingProfile.fromJson(legacyProfile));
    expect(await first.loadDraft(), isNull);
    expect((await first.load())!.age, 28);
    expect(await second.load(), isNull);
    expect(await preview.load(), isNull);
    await preview.save(TrainingProfile.fromJson(legacyProfile));
    expect(
      (await TrainingProfileStore(storageUserId: 'preview').load())!.age,
      28,
    );
  });

  test('legado sin propietario no se asigna a la primera cuenta', () async {
    SharedPreferences.setMockInitialValues({
      TrainingProfileStore.legacyKey: jsonEncode(legacyProfile),
    });
    expect(await TrainingProfileStore(storageUserId: 'user-a').load(), isNull);
    expect(await TrainingProfileStore(storageUserId: 'user-b').load(), isNull);
    expect(
      (await SharedPreferences.getInstance()).getString(
        TrainingProfileStore.legacyKey,
      ),
      isNotNull,
    );
  });

  test('migra legado con propietario comprobado y no sobrescribe v2', () async {
    SharedPreferences.setMockInitialValues({
      TrainingProfileStore.legacyKey: jsonEncode(legacyProfile),
      '${TrainingProfileStore.legacyKey}_owner': 'user-a',
    });
    final first = TrainingProfileStore(storageUserId: 'user-a');
    expect((await first.load())!.weightKg, 75);
    expect(await TrainingProfileStore(storageUserId: 'user-b').load(), isNull);
    await first.save(
      TrainingProfile.fromJson({...legacyProfile, 'weightKg': 81}),
    );
    expect((await first.load())!.weightKg, 81);
  });

  test('datos corruptos se notifican y se conservan', () async {
    SharedPreferences.setMockInitialValues({'training_profile_v2:user-a': '{'});
    await expectLater(
      TrainingProfileStore(storageUserId: 'user-a').load(),
      throwsFormatException,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        'training_profile_v2:user-a',
      ),
      '{',
    );
  });

  test('sin usuario no se usa almacenamiento compartido guest', () async {
    await expectLater(
      TrainingProfileStore(storageUserId: '').load(),
      throwsStateError,
    );
  });
}
