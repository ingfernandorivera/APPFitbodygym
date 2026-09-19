import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_body_gym/features/assessment/models/training_profile.dart';
import 'package:fit_body_gym/features/training/data/demo_workout_generator.dart';
import 'package:fit_body_gym/features/training/data/exercise_catalog.dart';
import 'package:fit_body_gym/features/training/data/exercise_catalog_repository.dart';
import 'package:fit_body_gym/features/training/data/training_rules.dart';
import 'package:fit_body_gym/features/training/data/user_storage.dart';
import 'package:fit_body_gym/features/training/data/workout_plan_store.dart';
import 'package:fit_body_gym/features/training/data/workout_history_store.dart';
import 'package:fit_body_gym/features/training/models/workout_plan.dart';
import 'package:fit_body_gym/features/training/models/workout_session.dart';
import 'package:fit_body_gym/features/progress/models/progress_metrics.dart';
import 'package:fit_body_gym/features/ai_chat/models/ai_chat_response.dart';
import 'package:fit_body_gym/features/ai_chat/data/workout_proposal_validator.dart';
import 'package:fit_body_gym/features/ai_chat/data/chat_cache_store.dart';

TrainingProfile profile({
  int days = 2,
  int minutes = 45,
  String experience = 'Principiante',
  String limitations = '',
  String location = 'Gimnasio',
  String equipment = 'Gimnasio completo',
  String goal = 'Ganar músculo',
  String preferences = '',
  List<String> priorities = const [],
}) => TrainingProfile(
  weightKg: 75,
  heightCm: 175,
  age: 30,
  goal: goal,
  experience: experience,
  daysPerWeek: days,
  minutesPerSession: minutes,
  preferences: preferences,
  limitations: limitations,
  trainingLocation: location,
  equipment: equipment,
  priorityMuscles: priorities,
);
WorkoutPlan generate([TrainingProfile? p]) => DemoWorkoutGenerator(
  clock: () => DateTime(2026, 9, 14),
).generate(p ?? profile());
WorkoutSession session({
  DateTime? at,
  List<ExerciseResult>? results,
  String? planId,
  int seconds = 600,
}) => WorkoutSession(
  planName: 'Rutina personalizada inicial',
  planId: planId,
  dayNumber: 1,
  dayTitle: 'Prueba',
  completedAt: at ?? DateTime(2026, 9, 15),
  durationSeconds: seconds,
  results:
      results ??
      [
        const ExerciseResult(
          exerciseId: 'dumbbell_row',
          exerciseName: 'Remo',
          sets: [
            SetResult(weightKg: 10, repetitions: 12, rir: 2, completed: true),
          ],
        ),
      ],
);

class FailedStorage extends UserStorage {
  FailedStorage() : super(storageUserId: 'failed');
  @override
  Future<void> write(String namespace, String value) async =>
      throw StateError('Fallo de disco');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('fallo bool de SharedPreferences se propaga y no crea plan', () async {
    final storage = UserStorage(
      storageUserId: 'bool-failure',
      writeString: (_, _, _) async => false,
    );
    final store = WorkoutPlanStore(storage: storage);
    await expectLater(store.save(generate()), throwsStateError);
    expect(await store.load(), isNull);
  });
  test('guardados concurrentes no pierden versiones ni sesiones', () async {
    final a = WorkoutPlanStore(storageUserId: 'race');
    final b = WorkoutPlanStore(storageUserId: 'race');
    await Future.wait([a.save(generate()), b.save(generate())]);
    expect((await a.versions()).map((p) => p.version), [2, 1]);
    final h = WorkoutHistoryStore(storageUserId: 'race');
    await Future.wait([
      h.add(session()),
      WorkoutHistoryStore(storageUserId: 'race').add(session()),
    ]);
    expect((await h.load()).length, 2);
  });
  test('planes, versiones e historial aislados por cuenta y preview', () async {
    final a = WorkoutPlanStore(storageUserId: 'a'),
        b = WorkoutPlanStore(storageUserId: 'b'),
        preview = WorkoutPlanStore(storageUserId: 'preview');
    await a.save(generate());
    expect(await b.load(), isNull);
    expect(await preview.load(), isNull);
    await preview.save(generate());
    expect((await preview.load())!.version, 1);
    final ha = WorkoutHistoryStore(storageUserId: 'a'),
        hb = WorkoutHistoryStore(storageUserId: 'b');
    await ha.add(session());
    expect(await hb.load(), isEmpty);
    expect(await WorkoutHistoryStore(storageUserId: 'preview').load(), isEmpty);
    expect((await ha.load()).length, 1);
    await expectLater(
      WorkoutPlanStore(storageUserId: '').load(),
      throwsStateError,
    );
    await expectLater(
      WorkoutHistoryStore(storageUserId: '').load(),
      throwsStateError,
    );
  });
  test('legado global solo migra con propietario comprobado', () async {
    final plan = generate().toJson()
      ..remove('version')
      ..remove('id')
      ..remove('source');
    SharedPreferences.setMockInitialValues({
      WorkoutPlanStore.legacyKey: jsonEncode(plan),
      WorkoutHistoryStore.legacyKey: jsonEncode([session().toJson()]),
    });
    expect(await WorkoutPlanStore(storageUserId: 'a').load(), isNull);
    expect(await WorkoutHistoryStore(storageUserId: 'a').load(), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${WorkoutPlanStore.legacyKey}_owner', 'a');
    await prefs.setString('${WorkoutHistoryStore.legacyKey}_owner', 'a');
    expect((await WorkoutPlanStore(storageUserId: 'a').load())!.version, 1);
    expect((await WorkoutHistoryStore(storageUserId: 'a').load()).length, 1);
    expect(prefs.getString('workout_plan_v2:a'), isNotNull);
    expect(prefs.getString('workout_history_v2:a'), isNotNull);
    expect(await WorkoutPlanStore(storageUserId: 'b').load(), isNull);
    expect(prefs.getString(WorkoutPlanStore.legacyKey), isNotNull);
  });
  test('JSON legacy conserva plan estable y convierte una única serie', () {
    final old = generate().toJson()
      ..remove('id')
      ..remove('version')
      ..remove('startDate')
      ..remove('source')
      ..remove('plannedMinutes');
    final p = WorkoutPlan.fromJson(old);
    expect(p.version, 1);
    expect(p.startDate, p.createdAt);
    expect(p.id, WorkoutPlan.fromJson(old).id);
    expect(p.source, 'legacy');
    final e = WorkoutExercise.fromJson({
      'name': 'Remo antiguo',
      'sets': 2,
      'repetitions': '8-12',
      'restSeconds': 60,
      'instructions': '',
    });
    expect(e.stableId, 'remo_antiguo');
    expect(e.minReps, 8);
    expect(e.maxReps, 12);
    expect(e.targetRir, 2);
    expect(e.mediaStatus, 'missing');
    final r = ExerciseResult.fromJson({
      'exerciseId': 'x',
      'exerciseName': 'Antiguo',
      'completed': true,
      'weightKg': 25,
      'repetitions': 8,
      'difficulty': 4,
    });
    expect(r.sets.length, 1);
    expect(r.sets.single.rir, 1);
    expect(r.sets.single.volume, 200);
    final oldSession = session().toJson()..remove('durationSeconds');
    expect(WorkoutSession.fromJson(oldSession).durationSeconds, 0);
  });
  for (final p in [
    profile(),
    profile(days: 6, experience: 'Avanzado', minutes: 60),
    profile(minutes: 30),
    profile(limitations: 'Molestia de rodilla'),
    profile(location: 'Casa', equipment: 'Mancuernas y bandas'),
  ]) {
    test(
      'generación válida: ${p.daysPerWeek} ${p.experience} ${p.minutesPerSession} ${p.limitations} ${p.trainingLocation}',
      () {
        final plan = generate(p);
        expect(plan.days.length, p.daysPerWeek);
        expect(
          WorkoutPlanValidator(
            ExerciseCatalog.exercises,
          ).validate(plan, profile: p),
          isEmpty,
        );
        expect(jsonEncode(plan.toJson()), jsonEncode(generate(p).toJson()));
        for (var i = 0; i < plan.days.length; i++) {
          final day = plan.days[i];
          expect(
            const WorkoutDurationEstimator().minutes(day),
            lessThanOrEqualTo(p.minutesPerSession),
          );
          if (p.experience == 'Principiante') {
            expect(
              day.exercises.fold<int>(0, (s, e) => s + e.sets),
              lessThanOrEqualTo(12),
            );
          }
          if (p.limitations.isNotEmpty) {
            expect(
              day.exercises.any(
                (e) => [
                  'squat',
                  'knee_flexion',
                  'cardio',
                ].contains(e.movementPattern),
              ),
              isFalse,
            );
          }
          if (p.trainingLocation == 'Casa') {
            expect(
              day.exercises.every(
                (e) => ['bodyweight', 'dumbbell'].contains(e.equipment),
              ),
              isTrue,
            );
          }
          var lastOrder = -1;
          for (final e in day.exercises) {
            final order = e.type == 'cardio'
                ? 2
                : e.compound
                ? 0
                : 1;
            expect(order, greaterThanOrEqualTo(lastOrder));
            lastOrder = order;
          }
          if (i > 0) {
            expect(
              day.exercises.map((e) => e.stableId).toSet(),
              isNot(plan.days[i - 1].exercises.map((e) => e.stableId).toSet()),
            );
          }
        }
      },
    );
  }
  test(
    'objetivo, prioridades y preferencias modifican prescripción y selección',
    () {
      expect(
        generate(
          profile(goal: 'Aumentar fuerza'),
        ).days.first.exercises.first.minReps,
        6,
      );
      final prioritized = generate(
        profile(
          minutes: 30,
          priorities: ['Espalda'],
          preferences: 'Mancuernas',
        ),
      );
      expect(
        prioritized.days.first.exercises.any(
          (e) => e.stableId == 'dumbbell_row',
        ),
        isTrue,
      );
      expect(
        generate(
          profile(preferences: 'sin cardio'),
        ).days.expand((d) => d.exercises).any((e) => e.type == 'cardio'),
        isFalse,
      );
      final pool = ExerciseCatalog.exercises
          .where((e) => e.equipment == 'bodyweight')
          .toList();
      final injected = DemoWorkoutGenerator(
        exercises: pool,
      ).generate(profile());
      expect(
        injected.days
            .expand((d) => d.exercises)
            .every((e) => pool.any((p) => p.id == e.id)),
        isTrue,
      );
    },
  );
  test(
    'estimador incluye calentamiento, transición, trabajo, descanso y cardio',
    () {
      final e = ExerciseCatalog.byId(
        'dumbbell_row',
      ).copyWith(sets: 2, targetMin: 10, targetMax: 10, restSeconds: 60);
      final d = WorkoutDay(dayNumber: 1, title: '', focus: '', exercises: [e]);
      expect(const WorkoutDurationEstimator().daySeconds(d), 505);
      expect(
        const WorkoutDurationEstimator().exerciseSeconds(
          ExerciseCatalog.byId('treadmill_walk'),
        ),
        720,
      );
    },
  );
  test(
    'errores estructurados para IDs, duplicados, series, descanso y duración',
    () {
      final p = generate();
      final e = p.days.first.exercises.first.copyWith(
        sets: 10,
        restSeconds: 901,
      );
      final unknown = WorkoutExercise.fromJson({
        ...e.toJson(),
        'id': 'unknown',
        'catalogId': 'unknown',
      });
      final bad = p.copyWith(
        days: [
          WorkoutDay(
            dayNumber: 8,
            title: '',
            focus: '',
            exercises: [e, e, unknown],
          ),
        ],
      );
      final codes = WorkoutPlanValidator(
        ExerciseCatalog.exercises,
      ).validate(bad).map((i) => i.code);
      expect(
        codes,
        containsAll([
          'days',
          'sets',
          'rest',
          'duplicate',
          'unknown_id',
          'duration',
        ]),
      );
    },
  );
  test('progresión subir, mantener, reducir y detener ante dolor', () {
    final e = ExerciseCatalog.byId(
      'dumbbell_row',
    ).copyWith(sets: 2, targetMin: 8, targetMax: 12);
    ExerciseResult r(int reps, int rir, {bool pain = false}) => ExerciseResult(
      exerciseId: e.id,
      exerciseName: e.name,
      discomfort: pain,
      sets: List.generate(
        2,
        (_) => SetResult(
          weightKg: 20,
          repetitions: reps,
          rir: rir,
          completed: true,
        ),
      ),
    );
    final engine = const WorkoutProgression();
    expect(engine.suggest(e, r(12, 2)).kind, ProgressionKind.increase);
    expect(engine.suggest(e, r(12, 2)).weightKg, 20.5);
    expect(engine.suggest(e, r(10, 0)).kind, ProgressionKind.maintain);
    expect(engine.suggest(e, r(12, 1)).kind, ProgressionKind.maintain);
    expect(engine.suggest(e, r(7, 2)).kind, ProgressionKind.reduce);
    expect(engine.suggest(e, r(12, 4, pain: true)).kind, ProgressionKind.stop);
  });
  test(
    'contrato IA rechaza acciones y payloads inválidos; texto legacy es answer',
    () {
      expect(AiChatResponse.parse('Hola').action.type, AiActionType.answer);
      expect(
        AiChatResponse.parse({'reply': 'Hola'}).action.type,
        AiActionType.answer,
      );
      expect(
        () => AiChatResponse.parse({'type': 'delete', 'reply': 'x'}),
        throwsFormatException,
      );
      expect(
        () => AiChatResponse.parse({
          'type': 'propose_workout',
          'reply': 'x',
          'payload': {},
        }),
        throwsFormatException,
      );
      expect(() => AiChatResponse.parse('{broken'), throwsFormatException);
    },
  );
  test(
    'propuesta requiere confirmación y versión vigente; restaura con nueva versión',
    () async {
      final store = WorkoutPlanStore(storageUserId: 'a');
      final validator = WorkoutProposalValidator(ExerciseCatalog.exercises);
      final action = AiWorkoutAction(
        type: AiActionType.proposeWorkout,
        plan: generate(),
        expectedVersion: 0,
      );
      expect(
        AiChatResponse.parse(
          AiChatResponse(reply: 'Propuesta', action: action).toJson(),
        ).action.plan!.days.length,
        2,
      );
      await expectLater(
        validator.apply(action, confirmed: false, store: store),
        throwsStateError,
      );
      expect(await store.load(), isNull);
      final first = await validator.apply(
        action,
        confirmed: true,
        store: store,
      );
      expect(first.version, 1);
      await expectLater(
        validator.apply(action, confirmed: true, store: store),
        throwsStateError,
      );
      final second = await store.save(
        first.copyWith(changeReason: 'Ajuste'),
        expectedVersion: 1,
      );
      expect(second.version, 2);
      final restored = await store.restorePrevious();
      expect(restored.version, 3);
      expect(restored.id, first.id);
      expect(restored.days.length, first.days.length);
      expect((await store.versions()).length, 3);
      await expectLater(
        WorkoutPlanStore(storage: FailedStorage()).save(generate()),
        throwsStateError,
      );
      await expectLater(
        WorkoutHistoryStore(storage: FailedStorage()).add(session()),
        throwsStateError,
      );
    },
  );
  test('propuesta rechaza IDs ajenos y limitaciones', () {
    final p = generate();
    final bad = WorkoutExercise.fromJson({
      ...p.days.first.exercises.first.toJson(),
      'catalogId': 'fake',
    });
    final action = AiWorkoutAction(
      type: AiActionType.proposeWorkout,
      expectedVersion: 0,
      plan: p.copyWith(
        days: [
          WorkoutDay(dayNumber: 1, title: '', focus: '', exercises: [bad]),
        ],
      ),
    );
    expect(
      WorkoutProposalValidator(
        ExerciseCatalog.exercises,
      ).validate(action).any((e) => e.code == 'unknown_id'),
      isTrue,
    );
  });
  test(
    'series y métricas: semana, adherencia, volumen, mejor serie, tiempo y omitidos',
    () {
      expect(
        () => SetResult.fromJson({'repetitions': 10, 'rir': 5}),
        throwsFormatException,
      );
      final plan = generate();
      final old = session(at: DateTime(2026, 9, 10), seconds: 300);
      final recent = session(
        planId: plan.id,
        results: [
          const ExerciseResult(
            exerciseId: 'dumbbell_row',
            exerciseName: 'Remo',
            sets: [
              SetResult(weightKg: 12, repetitions: 10, rir: 2, completed: true),
              SetResult(
                weightKg: 100,
                repetitions: 20,
                rir: 4,
                completed: false,
              ),
            ],
          ),
          const ExerciseResult(
            exerciseId: 'skip',
            exerciseName: 'Omitido',
            sets: [SetResult(repetitions: 0)],
          ),
        ],
      );
      final m = ProgressMetrics(
        [old, recent],
        plan: plan,
        now: DateTime(2026, 9, 18),
      );
      expect(m.sessionsThisWeek, 1);
      expect(m.adherence, .5);
      expect(m.totalVolume, 240);
      expect(m.durationSeconds, 900);
      expect(m.skippedExercises, 1);
      expect(m.skippedSets, 2);
      expect(m.exercises['dumbbell_row']!.best!.weightKg, 12);
      expect(m.exercises['dumbbell_row']!.first!.weightKg, 10);
      expect(ProgressMetrics([], now: DateTime(2026)).adherence, isNull);
    },
  );
  test('caché de conversación aislada, acotada y con estado', () async {
    final cache = ChatCacheStore(storageUserId: 'a');
    await cache.save(
      List.generate(80, (i) => {'text': 'Mensaje $i', 'status': 'cancelled'}),
    );
    expect((await cache.load()).length, 60);
    expect((await cache.load()).first['text'], 'Mensaje 20');
    expect(await ChatCacheStore(storageUserId: 'b').load(), isEmpty);
  });
  test(
    'catálogo distingue remoto, vacío y error; mapping no exige metadatos nuevos',
    () async {
      final remote = await ExerciseCatalogRepository(
        fetchRows: () async => [
          {
            'id': 'uuid',
            'name': 'Jalón al pecho',
            'muscle_group': 'Espalda',
            'equipment': 'Máquina',
            'media_type': 'video',
            'media_url': 'https://example.com/video.mp4',
          },
        ],
      ).loadResult();
      expect(remote.source, CatalogSource.remote);
      expect(
        remote.exercises.firstWhere((e) => e.id == 'lat_pulldown').mediaStatus,
        'video',
      );
      expect(
        (await ExerciseCatalogRepository(
          fetchRows: () async => [],
        ).loadResult()).source,
        CatalogSource.fallback,
      );
      final error = await ExerciseCatalogRepository(
        fetchRows: () async => throw StateError('offline'),
      ).loadResult();
      expect(error.source, CatalogSource.error);
      expect(error.message, isNotEmpty);
      expect(error.exercises, isNotEmpty);
    },
  );

  test(
    'datos legacy sin owner no se importan automáticamente, se detectan y aíslan',
    () async {
      final legacyPlan = generate().toJson();
      final legacyHistory = [session().toJson()];
      SharedPreferences.setMockInitialValues({
        'active_workout_plan_v1': jsonEncode(legacyPlan),
        'workout_history_v1': jsonEncode(legacyHistory),
      });

      const userA = 'user-a';
      final planStoreA = WorkoutPlanStore(storageUserId: userA);
      final historyStoreA = WorkoutHistoryStore(storageUserId: userA);

      // 1. No se importan automáticamente
      expect(await planStoreA.load(), isNull);
      expect(await historyStoreA.load(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('workout_plan_v2:$userA'), isNull);
      expect(prefs.getString('workout_history_v2:$userA'), isNull);

      // 2. Se detectan como recuperables
      expect(await planStoreA.hasUnclaimedLegacy(), isTrue);
      expect(await historyStoreA.hasUnclaimedLegacy(), isTrue);

      // 3. El modo preview no puede apropiarse de ellos
      final previewPlan = WorkoutPlanStore(storageUserId: 'preview');
      final previewHistory = WorkoutHistoryStore(storageUserId: 'preview');
      expect(await previewPlan.hasUnclaimedLegacy(), isFalse);
      expect(await previewHistory.hasUnclaimedLegacy(), isFalse);
      await expectLater(previewPlan.importLegacy(), throwsStateError);
      await expectLater(previewHistory.importLegacy(), throwsStateError);

      // 4. La importación explícita funciona
      await planStoreA.importLegacy();
      await historyStoreA.importLegacy();
      final loadedPlan = await planStoreA.load();
      final loadedHistory = await historyStoreA.load();
      expect(loadedPlan, isNotNull);
      expect(loadedPlan!.name, legacyPlan['name']);
      expect(loadedHistory.length, 1);
      expect(prefs.getString('active_workout_plan_v1_owner'), userA);
      expect(prefs.getString('workout_history_v1_owner'), userA);
      // Datos originales se conservan como respaldo
      expect(prefs.getString('active_workout_plan_v1'), isNotNull);
      expect(prefs.getString('workout_history_v1'), isNotNull);

      // 5. Otra cuenta no puede leerlos ni reclamarlos
      const userB = 'user-b';
      final planStoreB = WorkoutPlanStore(storageUserId: userB);
      final historyStoreB = WorkoutHistoryStore(storageUserId: userB);
      expect(await planStoreB.load(), isNull);
      expect(await historyStoreB.load(), isEmpty);
      expect(await planStoreB.hasUnclaimedLegacy(), isFalse);
      expect(await historyStoreB.hasUnclaimedLegacy(), isFalse);
      await expectLater(planStoreB.importLegacy(), throwsStateError);
      await expectLater(historyStoreB.importLegacy(), throwsStateError);
    },
  );

  test('paridad de reglas de equipamiento, lugar y preferencias', () {
    final dumbbellExercise = ExerciseCatalog.byId('dumbbell_row');
    final machineExercise = ExerciseCatalog.byId('lat_pulldown');
    final bodyweightExercise = ExerciseCatalog.byId('calf_raise');

    // Mancuernas + preferencia sin mancuernas -> rechaza
    expect(
      allowedExercise(dumbbellExercise, profile(preferences: 'sin mancuernas')),
      isFalse,
    );

    // Máquina + preferencia sin máquinas -> rechaza
    expect(
      allowedExercise(machineExercise, profile(preferences: 'sin maquinas')),
      isFalse,
    );

    // Aire libre + sin equipo -> rechaza mancuerna, permite bodyweight
    expect(
      allowedExercise(
        dumbbellExercise,
        profile(location: 'Aire libre', equipment: 'Sin equipo'),
      ),
      isFalse,
    );
    expect(
      allowedExercise(
        bodyweightExercise,
        profile(location: 'Aire libre', equipment: 'Sin equipo'),
      ),
      isTrue,
    );

    // Casa con equipamiento incompatible (máquina en casa con mancuernas) -> rechaza
    expect(
      allowedExercise(
        machineExercise,
        profile(location: 'Casa', equipment: 'Mancuernas y bandas'),
      ),
      isFalse,
    );
  });
}
