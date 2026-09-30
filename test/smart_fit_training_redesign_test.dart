import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_body_gym/core/theme/app_theme.dart';
import 'package:fit_body_gym/features/training/data/exercise_catalog.dart';
import 'package:fit_body_gym/features/training/data/workout_history_store.dart';
import 'package:fit_body_gym/features/training/data/workout_plan_store.dart';
import 'package:fit_body_gym/features/training/models/workout_plan.dart';
import 'package:fit_body_gym/features/training/models/workout_session.dart';
import 'package:fit_body_gym/features/training/pages/exercise_detail_page.dart';
import 'package:fit_body_gym/features/training/pages/training_page.dart';
import 'package:fit_body_gym/features/training/pages/workout_session_page.dart';
import 'training_engine_test.dart' show generate;

Widget app(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: child,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Indicación 1: TrainingPage cataloga rutinas con letras A, B..., badge En curso, duración y cantidad',
    (tester) async {
      final plans = WorkoutPlanStore(storageUserId: 'smart-fit-user');
      final plan = generate();
      await plans.save(plan);

      await tester.pumpWidget(
        app(
          TrainingPage(
            planStore: plans,
            storageUserId: 'smart-fit-user',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Título "Rutinas" y pestañas
      expect(find.text('Rutinas'), findsOneWidget);
      expect(find.text('Smart'), findsOneWidget);
      expect(find.text('Explorar'), findsOneWidget);
      expect(find.text('Guardados'), findsOneWidget);

      // Badge 'En curso' en el primer día
      expect(find.text('En curso'), findsOneWidget);

      // Letras de días A, B...
      expect(find.text('A'), findsOneWidget);
      if (plan.days.length > 1) {
        expect(find.text('B'), findsOneWidget);
      }

      // Información de duración y ejercicios
      expect(find.textContaining('ejercicios'), findsWidgets);
      expect(find.textContaining('min'), findsWidgets);
    },
  );

  testWidgets(
    'Indicación 2: WorkoutSessionPage muestra reloj transcurrido, descanso sugerido con play y finalizar entrenamiento',
    (tester) async {
      final store = WorkoutHistoryStore(storageUserId: 'smart-fit-user');
      final day = WorkoutDay(
        dayNumber: 1,
        title: 'Piernas, Estiramiento, Aulas',
        focus: 'Cuádriceps e Isquios',
        exercises: [
          ExerciseCatalog.byId('dumbbell_row').copyWith(
            name: 'Leg Press 45',
            sets: 3,
            restSeconds: 45,
          ),
        ],
      );

      await tester.pumpWidget(
        app(
          WorkoutSessionPage(
            planName: 'Rutina Smart',
            day: day,
            historyStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Reloj transcurrido en el AppBar
      expect(find.text('00:00:00'), findsOneWidget);

      // Título del día y acción
      expect(find.text('Piernas, Estiramiento, Aulas'), findsOneWidget);
      expect(find.text('Editar rutina'), findsOneWidget);

      // Nombre y reps del ejercicio
      expect(find.text('Leg Press 45'), findsOneWidget);

      // Fila de descanso con botón de reproducción Play
      expect(find.text('00:45 (Descanso entre series)'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);

      // Botón llamativo inferior "Finalizar entrenamiento"
      expect(find.text('Finalizar entrenamiento'), findsOneWidget);
    },
  );

  testWidgets(
    'Indicación 3: ExerciseDetailPage muestra video, tarjetas editables de series/reps y carga, y descanso',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int savedSets = 0;
      String savedReps = '';
      double savedWeight = 0;
      int startedRest = 0;

      final ex = ExerciseCatalog.byId('dumbbell_row').copyWith(
        name: 'Leg Press 45',
        sets: 3,
        restSeconds: 45,
      );

      await tester.pumpWidget(
        app(
          ExerciseDetailPage(
            exercise: ex,
            setsCount: 3,
            repsText: '12 a 15',
            weightKg: 25.0,
            restSeconds: 45,
            onSaveCustomization: (sets, reps, weight, rest) {
              savedSets = sets;
              savedReps = reps;
              savedWeight = weight;
            },
            onStartRest: (sec) {
              startedRest = sec;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Título en AppBar y cuerpo
      expect(find.text('Leg Press 45'), findsWidgets);

      // Tarjetas editables
      expect(find.text('Series y Repeticiones'), findsOneWidget);
      expect(find.text('3x 12 a 15'), findsOneWidget);
      expect(find.text('Carga (kg)'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);

      // Fila de descanso con play
      expect(find.text('00:45 (Descanso entre series)'), findsOneWidget);

      // Iniciar descanso
      await tester.tap(find.byTooltip('Iniciar descanso'));
      await tester.pump();
      expect(startedRest, 45);

      // Abrir modal de series y modificar a 4 series
      await tester.tap(find.text('Series y Repeticiones'));
      await tester.pumpAndSettle();
      expect(find.text('Editar Series y Repeticiones'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(savedSets, 4);
      expect(savedReps, '12 a 15');

      // Abrir modal de carga y modificarla
      await tester.tap(find.text('Carga (kg)'));
      await tester.pumpAndSettle();
      expect(find.text('Editar Carga (kg)'), findsOneWidget);

      // Pulsar +10 kg
      await tester.tap(find.text('+10.0 kg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar carga'));
      await tester.pumpAndSettle();

      expect(savedWeight, 35.0);
      expect(find.text('35'), findsOneWidget);
    },
  );

  testWidgets(
    'Indicaciones 4 y 5: Marcar ejercicio como terminado lo mueve a Completados con tonalidad oscura y desmarcarlo lo regresa a pendientes',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = WorkoutHistoryStore(storageUserId: 'smart-fit-user');
      final day = WorkoutDay(
        dayNumber: 1,
        title: 'Rutina de pierna',
        focus: 'Piernas',
        exercises: [
          ExerciseCatalog.byId('dumbbell_row').copyWith(name: 'Leg Press 45'),
          ExerciseCatalog.byId('lat_pulldown').copyWith(name: 'Sentadilla En Smith'),
        ],
      );

      await tester.pumpWidget(
        app(
          WorkoutSessionPage(
            planName: 'Rutina Smart',
            day: day,
            historyStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inicialmente no hay sección "Completados"
      expect(find.text('Completados'), findsNothing);

      // Tocamos el checkbox de Leg Press 45 mediante su ValueKey
      final checkKey = ValueKey('exercise_check_${day.exercises.first.stableId}');
      await tester.tap(find.byKey(checkKey));
      await tester.pumpAndSettle();

      // Ahora aparece la sección "Completados"
      expect(find.text('Completados'), findsOneWidget);
      expect(find.text('1 de 2 ejercicios completados'), findsOneWidget);

      // El ejercicio completado tiene el ícono check
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Desmarcar el ejercicio completado tocando su checkbox
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      // Regresa a pendientes y la sección "Completados" desaparece
      expect(find.text('Completados'), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
    },
  );

  testWidgets(
    'Indicación 6: Terminar rutina la mueve a Completadas esta semana, marca Terminada y activa En curso en la siguiente',
    (tester) async {
      final plans = WorkoutPlanStore(storageUserId: 'weekly-test-user');
      final history = WorkoutHistoryStore(storageUserId: 'weekly-test-user');
      final plan = WorkoutPlan(
        name: 'Rutina Dividida',
        goal: 'Hipertrofia',
        createdAt: DateTime.now(),
        totalWeeks: 4,
        days: [
          WorkoutDay(
            dayNumber: 1,
            title: 'Pecho y Tríceps',
            focus: 'Pecho y Tríceps',
            exercises: [
              ExerciseCatalog.byId('dumbbell_row').copyWith(name: 'Press de Banca'),
            ],
          ),
          WorkoutDay(
            dayNumber: 2,
            title: 'Espalda y Bíceps',
            focus: 'Espalda y Bíceps',
            exercises: [
              ExerciseCatalog.byId('lat_pulldown').copyWith(name: 'Jalón al pecho'),
            ],
          ),
        ],
      );
      await plans.save(plan);

      // Cargar TrainingPage inicialmente
      await tester.pumpWidget(
        app(
          TrainingPage(
            planStore: plans,
            historyStore: history,
            storageUserId: 'weekly-test-user',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Marcador de semanas inicial
      expect(find.text('Semana 1 de 4'), findsOneWidget);
      expect(find.text('0/2 completadas'), findsOneWidget);

      // Rutina A tiene 'En curso', Rutina B no
      expect(find.text('En curso'), findsOneWidget);
      expect(find.text('Completadas esta semana (1)'), findsNothing);

      // Simulamos la finalización de la Rutina A (Día 1)
      await history.add(
        WorkoutSession(
          planName: plan.name,
          planId: plan.id,
          dayNumber: 1,
          dayTitle: 'Pecho y Tríceps',
          completedAt: DateTime.now(),
          durationSeconds: 1800,
          results: [
            ExerciseResult(
              exerciseId: 'dumbbell_row',
              exerciseName: 'Press de Banca',
              sets: [
                const SetResult(weightKg: 40, repetitions: 10, completed: true),
              ],
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Ahora 1/2 completadas
      expect(find.text('1/2 completadas'), findsOneWidget);

      // Aparece la sección "Completadas esta semana"
      expect(find.text('Completadas esta semana (1)'), findsOneWidget);
      expect(find.textContaining('Terminada esta semana'), findsOneWidget);

      // La Rutina B (Día 2) ahora tiene el badge 'En curso'
      expect(find.text('En curso'), findsOneWidget);

      // Simulamos la finalización de la Rutina B (Día 2)
      await history.add(
        WorkoutSession(
          planName: plan.name,
          planId: plan.id,
          dayNumber: 2,
          dayTitle: 'Espalda y Bíceps',
          completedAt: DateTime.now(),
          durationSeconds: 1800,
          results: [
            ExerciseResult(
              exerciseId: 'lat_pulldown',
              exerciseName: 'Jalón al pecho',
              sets: [
                const SetResult(weightKg: 50, repetitions: 12, completed: true),
              ],
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Ahora 2/2 completadas y celebración de semana
      expect(find.text('2/2 completadas'), findsOneWidget);
      expect(find.text('Completadas esta semana (2)'), findsOneWidget);
      expect(
        find.text('¡Semana 1 completada! Todas las rutinas terminadas.'),
        findsOneWidget,
      );
      expect(find.text('Comenzar Semana 2 ahora'), findsOneWidget);

      // Al pulsar "Comenzar Semana 2 ahora"
      await tester.tap(find.text('Comenzar Semana 2 ahora'));
      await tester.pumpAndSettle();

      // Marcador avanza a Semana 2 de 4
      expect(find.text('Semana 2 de 4'), findsOneWidget);
      expect(find.text('0/2 completadas'), findsOneWidget);

      // Rutinas restauradas a pendientes y Día A vuelve a estar 'En curso'
      expect(find.text('Completadas esta semana (1)'), findsNothing);
      expect(find.text('Completadas esta semana (2)'), findsNothing);
      expect(find.text('En curso'), findsOneWidget);
    },
  );
}
