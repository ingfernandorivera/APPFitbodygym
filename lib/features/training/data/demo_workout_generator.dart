import '../../assessment/models/training_profile.dart';
import '../models/workout_plan.dart';
import 'exercise_catalog.dart';

class DemoWorkoutGenerator {
  WorkoutPlan generate(TrainingProfile profile) {
    final templates = <WorkoutDay>[
      WorkoutDay(
        dayNumber: 1,
        title: 'Tren superior',
        focus: 'Pecho, espalda y brazos',
        exercises: [
          'chest_press_machine',
          'lat_pulldown',
          'seated_row',
        ].map(ExerciseCatalog.byId).toList(),
      ),
      WorkoutDay(
        dayNumber: 2,
        title: 'Tren inferior',
        focus: 'Piernas y glúteos',
        exercises: [
          'leg_press',
          'leg_curl',
          'calf_raise',
        ].map(ExerciseCatalog.byId).toList(),
      ),
      WorkoutDay(
        dayNumber: 3,
        title: 'Cuerpo completo',
        focus: 'Fuerza general y acondicionamiento',
        exercises: [
          'goblet_squat',
          'shoulder_press_machine',
          'treadmill_walk',
        ].map(ExerciseCatalog.byId).toList(),
      ),
    ];

    final days = List.generate(profile.daysPerWeek, (index) {
      final template = templates[index % templates.length];
      return WorkoutDay(
        dayNumber: index + 1,
        title: template.title,
        focus: template.focus,
        exercises: template.exercises,
      );
    });

    return WorkoutPlan(
      name: 'Rutina personalizada inicial',
      goal: profile.goal,
      createdAt: DateTime.now(),
      days: days,
    );
  }
}
