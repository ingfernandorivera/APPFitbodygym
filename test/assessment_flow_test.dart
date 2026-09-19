import 'dart:convert';

import 'package:fit_body_gym/core/theme/app_theme.dart';
import 'package:fit_body_gym/features/assessment/data/training_profile_store.dart';
import 'package:fit_body_gym/features/assessment/models/assessment_step.dart';
import 'package:fit_body_gym/features/assessment/models/training_profile.dart';
import 'package:fit_body_gym/features/assessment/pages/training_assessment_page.dart';
import 'package:fit_body_gym/features/assessment/pages/training_profile_summary_page.dart';
import 'package:fit_body_gym/features/assessment/widgets/assessment_choice.dart';
import 'package:fit_body_gym/features/membership/pages/membership_page.dart';
import 'package:fit_body_gym/shared/presentation/atomic_design/templates/main_navigation_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'training_assessment_test.dart' show legacyProfile;

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  theme: AppTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    maxScrolls: 100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Map<String, dynamic> completeAnswers() => {
  'goal': 'Aumentar fuerza',
  'bodyRepresentation': 'Neutral',
  'bodyShape': 'Intermedia',
  'experience': 'Principiante',
  'daysPerWeek': '3',
  'minutesPerSession': '45',
  'schedule': 'Tarde',
  'trainingLocation': 'Casa',
  'equipment': 'Mancuernas y bandas',
  'priorityMuscles': ['Espalda', 'Piernas'],
  'limitations': '',
  'motivations': ['Crear un hábito'],
  'dailyActivity': 'Camino con frecuencia',
  'sleepHours': '7,5',
  'hydrationLiters': '2',
  'age': '28',
  'heightCm': '172',
  'weightUnit': 'kg',
  'weight': '75',
  'targetWeight': '78',
  'preferences': '',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('valida el paso, guarda y restaura el borrador', (tester) async {
    final store = TrainingProfileStore(storageUserId: 'widget-user');
    await tester.pumpWidget(app(TrainingAssessmentPage(store: store)));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Continuar'));
    expect(find.text('Selecciona una opción para continuar.'), findsOneWidget);
    await tapVisible(tester, find.text('Aumentar fuerza'));
    await tapVisible(tester, find.text('Continuar'));
    expect(find.text('¿Cómo prefieres ver la silueta?'), findsOneWidget);
    expect((await store.loadDraft())!['step'], 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(TrainingAssessmentPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo prefieres ver la silueta?'), findsOneWidget);
    await tapVisible(tester, find.text('Atrás'));
    expect(find.text('¿Qué quieres conseguir?'), findsOneWidget);
    final choice = tester.widget<AssessmentChoice>(
      find.widgetWithText(AssessmentChoice, 'Aumentar fuerza'),
    );
    expect(choice.selected, isTrue);
    expect(await store.load(), isNull);
  });

  testWidgets('completa evaluación y limpia solo el borrador de la cuenta', (
    tester,
  ) async {
    final store = TrainingProfileStore(storageUserId: 'widget-user');
    await store.saveDraft({
      'version': 1,
      'step': assessmentSteps.length - 1,
      'answers': completeAnswers(),
    });
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrainingAssessmentPage(store: store),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Guardar mi evaluación'));
    final profile = await store.load();
    expect(profile!.priorityMuscles, ['Espalda', 'Piernas']);
    expect(profile.targetWeightKg, 78);
    expect(profile.sleepHours, 7.5);
    expect(profile.bodyFatEstimate, isNull);
    expect(await store.loadDraft(), isNull);
    expect(find.text('Abrir'), findsOneWidget);
  });

  testWidgets('todos los pasos caben con texto grande en móvil y ancho web', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(320, 640), const Size(1440, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (var step = 0; step < assessmentSteps.length; step++) {
        await tester.pumpWidget(const SizedBox());
        final store = TrainingProfileStore(storageUserId: 'layout');
        await store.saveDraft({
          'version': 1,
          'step': step,
          'answers': {...completeAnswers(), 'bodyFatEstimate': 28},
        });
        await tester.pumpWidget(
          app(TrainingAssessmentPage(store: store), scale: 2),
        );
        await tester.pumpAndSettle();
        final button = find.text(
          step == assessmentSteps.length - 1
              ? 'Guardar mi evaluación'
              : 'Continuar',
        );
        await tester.scrollUntilVisible(
          button,
          300,
          maxScrolls: 100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Paso $step a ${size.width} px',
        );
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('resumen sin membresía dirige a Info y nunca abre Chat', (
    tester,
  ) async {
    var chat = false;
    var info = false;
    await tester.pumpWidget(
      app(
        TrainingProfileSummaryPage(
          profile: TrainingProfile.fromJson(legacyProfile),
          onOpenAiChat: () => chat = true,
          onOpenInfo: () => info = true,
        ),
      ),
    );
    await tapVisible(tester, find.text('Consultar información del gimnasio'));
    expect(info, isTrue);
    expect(chat, isFalse);
  });

  testWidgets(
    'cuenta sin member_profiles inicia onboarding y conserva bloqueos',
    (tester) async {
      await tester.pumpWidget(
        app(
          MembershipScreen(previewMode: true, profileLoader: () async => null),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TrainingAssessmentPage), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(MainNavigationTemplate), findsOneWidget);
      expect(find.text('Reanudar evaluación'), findsOneWidget);
      for (final item in [
        ('Entrenar', 'Entrenamiento bloqueado'),
        ('Chat IA', 'Chat IA bloqueado'),
        ('Progreso', 'Progreso bloqueado'),
      ]) {
        await tester.tap(find.text(item.$1).last);
        await tester.pumpAndSettle();
        expect(find.text(item.$2), findsOneWidget);
      }
      await tester.tap(find.text('Perfil').last);
      await tester.pumpAndSettle();
      expect(find.text('Reanudar evaluación'), findsOneWidget);
    },
  );

  testWidgets('error de red ofrece reintento sin inventar membresía', (
    tester,
  ) async {
    var attempts = 0;
    SharedPreferences.setMockInitialValues({
      'training_profile_v2:preview': jsonEncode(legacyProfile),
    });
    await tester.pumpWidget(
      app(
        MembershipScreen(
          previewMode: true,
          profileLoader: () async {
            attempts++;
            if (attempts == 1) throw Exception('offline');
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MainNavigationTemplate), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(MainNavigationTemplate), findsOneWidget);
    expect(find.byType(TrainingAssessmentPage), findsNothing);
  });

  for (final active in [true, false]) {
    testWidgets(
      'onboarding automático con membresía ${active ? 'activa' : 'vencida'}',
      (tester) async {
        await tester.pumpWidget(
          app(
            MembershipScreen(
              previewMode: true,
              profileLoader: () async => {
                'full_name': 'Prueba',
                'membership_active': true,
                'membership_end': DateTime.now()
                    .add(Duration(days: active ? 30 : -30))
                    .toIso8601String(),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TrainingAssessmentPage), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Entrenar').last);
        await tester.pumpAndSettle();
        expect(
          find.text('Entrenamiento bloqueado'),
          active ? findsNothing : findsOneWidget,
        );
      },
    );
  }

  testWidgets('cambiar unidad convierte peso actual y objetivo', (
    tester,
  ) async {
    final store = TrainingProfileStore(storageUserId: 'units');
    await store.saveDraft({
      'version': 1,
      'step': assessmentSteps.indexWhere((s) => s.key == 'weightUnit'),
      'answers': completeAnswers(),
    });
    await tester.pumpWidget(app(TrainingAssessmentPage(store: store)));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('lb'));
    final draft = await store.loadDraft();
    final answers = draft!['answers'] as Map;
    expect(answers['weightUnit'], 'lb');
    expect(double.parse(answers['weight'] as String), closeTo(165.3, .1));
    expect(double.parse(answers['targetWeight'] as String), closeTo(172, .1));
    await tapVisible(tester, find.text('kg'));
    final restored = (await store.loadDraft())!['answers'] as Map;
    expect(double.parse(restored['weight'] as String), closeTo(75, .1));
    expect(double.parse(restored['targetWeight'] as String), closeTo(78, .1));
  });
}
