import 'package:fit_body_gym/features/training/models/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workout session preserves recorded exercise values', () {
    final original = WorkoutSession(
      planName: 'Rutina inicial',
      dayNumber: 1,
      dayTitle: 'Tren superior',
      completedAt: DateTime(2026, 9, 7, 20, 30),
      results: const [
        ExerciseResult(
          exerciseId: 'chest_press_machine',
          exerciseName: 'Press de pecho en máquina',
          completed: true,
          weightKg: 25.5,
          repetitions: 12,
          difficulty: 4,
        ),
      ],
    );

    final restored = WorkoutSession.fromJson(original.toJson());

    expect(restored.planName, original.planName);
    expect(restored.completedAt, original.completedAt);
    expect(restored.completedExercises, 1);
    expect(restored.results.single.weightKg, 25.5);
    expect(restored.results.single.repetitions, 12);
    expect(restored.results.single.difficulty, 4);
  });
}
