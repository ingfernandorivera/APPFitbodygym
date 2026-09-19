import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_body_gym/core/theme/app_theme.dart';
import 'package:fit_body_gym/features/assessment/data/training_profile_store.dart';
import 'package:fit_body_gym/features/ai_chat/pages/ai_chat_page.dart';
import 'package:fit_body_gym/features/ai_chat/data/chat_cache_store.dart';
import 'package:fit_body_gym/features/training/data/exercise_catalog.dart';
import 'package:fit_body_gym/features/training/data/workout_history_store.dart';
import 'package:fit_body_gym/features/training/data/workout_plan_store.dart';
import 'package:fit_body_gym/features/training/data/user_storage.dart';
import 'package:fit_body_gym/features/training/models/workout_plan.dart';
import 'package:fit_body_gym/features/training/pages/training_page.dart';
import 'package:fit_body_gym/features/training/pages/workout_result_page.dart';
import 'package:fit_body_gym/features/training/pages/workout_session_page.dart';
import 'training_engine_test.dart' show profile, generate, session;

Widget app(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: child),
);
Future<void> tapVisible(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 60,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(
    tester.element(find.text(text).first),
    alignment: 0.5,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'propuesta local no se aplica sin pulsar Aplicar y se puede cancelar',
    (tester) async {
      final profiles = TrainingProfileStore(storageUserId: 'flow');
      await profiles.save(profile());
      final plans = WorkoutPlanStore(storageUserId: 'flow');
      await tester.pumpWidget(
        app(
          AiChatPage(
            onOpenTraining: () {},
            profileStore: profiles,
            planStore: plans,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear mi rutina'));
      await tester.pumpAndSettle();
      expect(await plans.load(), isNull);
      await tapVisible(tester, 'Cancelar');
      expect(await plans.load(), isNull);
      expect(
        (await ChatCacheStore(storageUserId: 'flow').load()).last['status'],
        'cancelled',
      );
      await tester.tap(find.text('Crear mi rutina'));
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Aplicar');
      expect((await plans.load())!.version, 1);
      expect((await plans.versions()).length, 1);
    },
  );
  testWidgets(
    'sesión registra series, exige completar y cancela descanso al salir',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = WorkoutHistoryStore(storageUserId: 'flow');
      final day = WorkoutDay(
        dayNumber: 1,
        title: 'Prueba',
        focus: '',
        exercises: [ExerciseCatalog.byId('dumbbell_row').copyWith(sets: 1)],
      );
      await tester.pumpWidget(
        app(
          WorkoutSessionPage(planName: 'Prueba', day: day, historyStore: store),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Finalizar entrenamiento');
      expect(await store.load(), isEmpty);
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Reps'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Peso (kg)'), '15');
      await tester.enterText(find.widgetWithText(TextField, 'Reps'), '12');
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await tapVisible(tester, 'Finalizar entrenamiento');
      final history = await store.load();
      expect(history.length, 1);
      expect(history.single.results.single.sets.single.weightKg, 15);
      expect(history.single.results.single.sets.single.rir, 2);
      expect(history.single.durationSeconds, greaterThanOrEqualTo(0));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 90));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('fallo de escritura mantiene sesión editable y no finge éxito', (
    tester,
  ) async {
    final storage = UserStorage(
      storageUserId: 'failure',
      writeString: (_, _, _) async => false,
    );
    final store = WorkoutHistoryStore(storage: storage);
    await tester.pumpWidget(
      app(
        WorkoutSessionPage(
          planName: 'Prueba',
          day: WorkoutDay(
            dayNumber: 1,
            title: 'Prueba',
            focus: '',
            exercises: [ExerciseCatalog.byId('dumbbell_row').copyWith(sets: 1)],
          ),
          historyStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '10');
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    await tapVisible(tester, 'Finalizar entrenamiento');
    expect(await store.load(), isEmpty);
    expect(
      find.text(
        'No se pudo guardar la sesión. Tus datos siguen aquí; reintenta.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'WorkoutResultPage es de solo lectura y no sobrescribe la rutina activa en el store',
    (tester) async {
      final plans = WorkoutPlanStore(storageUserId: 'flow-ro');
      final v1 = generate();
      await plans.save(v1);
      final v2 = generate().copyWith(name: 'Rutina V2');
      await plans.save(v2);
      expect((await plans.load())!.version, 2);

      await tester.pumpWidget(app(WorkoutResultPage(plan: v1)));
      await tester.pumpAndSettle();

      // Verificar chip de versión
      expect(find.text('Rutina activa · versión 1'), findsOneWidget);
      // Verificar ausencia total de botón para guardar
      expect(find.text('Guardar como rutina activa'), findsNothing);

      // Store inalterado: la versión activa sigue siendo 2
      expect((await plans.load())!.version, 2);
      expect((await plans.load())!.name, 'Rutina V2');
    },
  );
  testWidgets(
    'TrainingPage detecta datos legacy no reclamados, solicita confirmación y los recupera con éxito',
    (tester) async {
      final legacyPlan = generate().copyWith(name: 'Rutina Antigua');
      final legacySession = session();
      SharedPreferences.setMockInitialValues({
        'active_workout_plan_v1': jsonEncode(legacyPlan.toJson()),
        'workout_history_v1': jsonEncode([legacySession.toJson()]),
      });

      final plans = WorkoutPlanStore(storageUserId: 'legacy-user');
      final history = WorkoutHistoryStore(storageUserId: 'legacy-user');

      await tester.pumpWidget(
        app(
          TrainingPage(
            planStore: plans,
            historyStore: history,
            storageUserId: 'legacy-user',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tarjeta discreta visible
      expect(find.text('Datos de una versión anterior'), findsOneWidget);
      expect(find.text('Recuperar'), findsOneWidget);

      // Pulsar recuperar abre diálogo de confirmación
      await tester.tap(find.text('Recuperar'));
      await tester.pumpAndSettle();

      expect(find.text('Recuperar datos anteriores'), findsOneWidget);
      expect(
        find.text(
          'Se encontraron datos de una versión anterior en este dispositivo.\n\n'
          'Solo debes continuar si estos datos te pertenecen. Tras confirmar, '
          'se importarán a tu cuenta actual y ninguna otra cuenta podrá reclamarlos.',
        ),
        findsOneWidget,
      );

      // Confirmar importación
      await tester.tap(find.text('Confirmar importación'));
      await tester.pumpAndSettle();

      // SnackBar de éxito
      expect(
        find.text('Datos anteriores recuperados con éxito.'),
        findsOneWidget,
      );

      // Verificar que los datos están en el store del usuario
      final loadedPlan = await plans.load();
      expect(loadedPlan, isNotNull);
      expect(loadedPlan!.name, 'Rutina Antigua');
      final loadedHistory = await history.load();
      expect(loadedHistory.length, 1);

      // Verificar que el owner quedó registrado en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_workout_plan_v1_owner'), 'legacy-user');
      expect(prefs.getString('workout_history_v1_owner'), 'legacy-user');

      // Tarjeta desaparece tras la recuperación exitosa
      expect(find.text('Datos de una versión anterior'), findsNothing);
    },
  );
}
