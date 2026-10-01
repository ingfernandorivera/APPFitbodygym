import 'package:flutter_test/flutter_test.dart';
import 'package:fit_body_gym/features/assessment/models/training_profile.dart';
import 'package:fit_body_gym/features/training/data/exercise_catalog.dart';
import 'package:fit_body_gym/features/training/data/training_rules.dart';

void main() {
  group('Catálogo Oficial de 96 Ejercicios de Fit Body Gym', () {
    test('contiene todos los 96 ejercicios oficiales más ejercicios complementarios', () {
      expect(ExerciseCatalog.exercises.length, greaterThanOrEqualTo(96));

      // Verificar que los 96 IDs de catálogo ex_001_... a ex_096_... existen
      for (int i = 1; i <= 96; i++) {
        final prefix = 'ex_${i.toString().padLeft(3, '0')}_';
        final found = ExerciseCatalog.exercises.any(
          (e) => e.catalogId?.startsWith(prefix) == true,
        );
        expect(found, isTrue, reason: 'Falta el ejercicio oficial #$i');
      }
    });

    test('los 35 ejercicios con videos en Supabase Storage tienen mediaUrl público', () {
      final exercisesWithVideo = ExerciseCatalog.exercises.where((e) => e.mediaStatus == 'video').toList();
      expect(exercisesWithVideo.length, greaterThanOrEqualTo(35));

      for (final e in exercisesWithVideo) {
        expect(e.mediaUrl, isNotNull);
        expect(e.mediaUrl!, contains('supabase.co/storage/v1/object/public/exercise-videos/'));
      }
    });

    test('Belt squat tiene cero compresión en columna y es permitido para problemas lumbares', () {
      const spineProfile = TrainingProfile(
        weightKg: 75,
        heightCm: 175,
        age: 28,
        experience: 'Intermedio',
        goal: 'Hipertrofia',
        daysPerWeek: 4,
        minutesPerSession: 60,
        preferences: '',
        trainingLocation: 'Gimnasio',
        equipment: 'Gimnasio completo',
        limitations: 'Dolor lumbar y problemas en columna',
      );

      final beltSquat = ExerciseCatalog.exercises.firstWhere((e) => e.id == 'belt_squat');
      final legPress = ExerciseCatalog.exercises.firstWhere((e) => e.id == 'leg_press');
      final latPulldown = ExerciseCatalog.exercises.firstWhere((e) => e.id == 'lat_pulldown');
      final seatedRow = ExerciseCatalog.exercises.firstWhere((e) => e.id == 'seated_row');

      expect(allowedExercise(beltSquat, spineProfile), isTrue);
      expect(allowedExercise(legPress, spineProfile), isTrue);
      expect(allowedExercise(latPulldown, spineProfile), isTrue);
      expect(allowedExercise(seatedRow, spineProfile), isTrue);
    });

    test('Ejercicios con carga axial o bisagra pesada son estrictamente bloqueados con lesión de columna', () {
      const spineProfile = TrainingProfile(
        weightKg: 75,
        heightCm: 175,
        age: 28,
        experience: 'Intermedio',
        goal: 'Hipertrofia',
        daysPerWeek: 4,
        minutesPerSession: 60,
        preferences: '',
        trainingLocation: 'Gimnasio',
        equipment: 'Gimnasio completo',
        limitations: 'Lesión en la columna',
      );

      final deadlift = ExerciseCatalog.exercises.firstWhere((e) => e.id == 'deadlift_conventional');
      final romanianDeadlift = ExerciseCatalog.exercises.firstWhere((e) => e.id == 'romanian_deadlift_barbell');
      final squatBarbell = ExerciseCatalog.exercises.firstWhere((e) => e.id == 'squat_barbell');
      final goodMornings = ExerciseCatalog.exercises.firstWhere((e) => e.id == 'good_mornings_barbell');
      final barbellRow = ExerciseCatalog.exercises.firstWhere((e) => e.id == 'barbell_row');

      expect(allowedExercise(deadlift, spineProfile), isFalse);
      expect(allowedExercise(romanianDeadlift, spineProfile), isFalse);
      expect(allowedExercise(squatBarbell, spineProfile), isFalse);
      expect(allowedExercise(goodMornings, spineProfile), isFalse);
      expect(allowedExercise(barbellRow, spineProfile), isFalse);
    });
  });
}
