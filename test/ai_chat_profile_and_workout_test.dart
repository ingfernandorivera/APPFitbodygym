import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_body_gym/core/theme/app_theme.dart';
import 'package:fit_body_gym/features/assessment/data/training_profile_store.dart';
import 'package:fit_body_gym/features/assessment/models/training_profile.dart';
import 'package:fit_body_gym/features/profile/data/app_user_profile_store.dart';
import 'package:fit_body_gym/features/profile/models/app_user_profile.dart';
import 'package:fit_body_gym/features/training/data/workout_plan_store.dart';
import 'package:fit_body_gym/features/training/models/workout_plan.dart';
import 'package:fit_body_gym/features/ai_chat/pages/ai_chat_page.dart';
import 'package:fit_body_gym/features/ai_chat/data/ai_chat_service.dart';
import 'package:fit_body_gym/features/ai_chat/models/ai_chat_response.dart';

class MockAiChatService extends AiChatService {
  MockAiChatService({this.replyBuilder});
  final AiChatResponse Function(String message)? replyBuilder;

  @override
  Future<AiChatResponse> reply({
    required String message,
    required List<Map<String, String>> history,
    Map<String, dynamic>? trainingProfile,
    Map<String, dynamic>? activeWorkout,
  }) async {
    if (replyBuilder != null) {
      return replyBuilder!(message);
    }
    // Simula una respuesta de solo texto (como la que ocurrió cuando el LLM devolvió preguntas)
    return AiChatResponse(
      reply: 'Claro, pero dime cuántos días entrenas y qué ejercicios haces.',
      action: const AiWorkoutAction(type: AiActionType.answer),
    );
  }
}

Widget app(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: child),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Chat IA visualiza datos del perfil cuando el usuario pregunta por ellos',
    (tester) async {
      const userId = 'user-data-test';
      final profileStore = TrainingProfileStore(storageUserId: userId);
      await profileStore.save(
        const TrainingProfile(
          weightKg: 78.5,
          heightCm: 178,
          age: 29,
          gender: 'Hombre',
          goal: 'Hipertrofia muscular',
          experience: 'Intermedio',
          daysPerWeek: 4,
          minutesPerSession: 60,
          preferences: 'Mancuernas y máquinas',
          limitations: 'Molestia leve en hombro izquierdo',
          equipment: 'Gimnasio completo',
          priorityMuscles: ['Pecho', 'Brazos'],
        ),
      );

      final appProfileStore = AppUserProfileStore(storageUserId: userId);
      await appProfileStore.save(
        const AppUserProfile(
          fullName: 'Carlos Rivera',
          birthDate: '1997-04-12',
          phone: '5551234567',
          goal: 'Hipertrofia muscular',
          limitations: 'Molestia leve en hombro izquierdo',
        ),
      );

      final planStore = WorkoutPlanStore(storageUserId: userId);
      await planStore.save(
        WorkoutPlan(
          name: 'Rutina Base 4 Días',
          goal: 'Hipertrofia muscular',
          createdAt: DateTime.now(),
          days: const [
            WorkoutDay(dayNumber: 1, title: 'Día 1', focus: 'Pecho', exercises: []),
          ],
        ),
      );

      await tester.pumpWidget(
        app(
          AiChatPage(
            storageUserId: userId,
            profileStore: profileStore,
            planStore: planStore,
            onOpenTraining: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enviamos pregunta sobre datos de perfil
      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'cuáles son mis datos de perfil y objetivos?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Verificamos que responde con los datos reales del usuario
      expect(find.textContaining('Carlos Rivera'), findsOneWidget);
      expect(find.textContaining('29 años'), findsOneWidget);
      expect(find.textContaining('78.5 kg'), findsOneWidget);
      expect(find.textContaining('178 cm'), findsOneWidget);
      expect(find.textContaining('Hipertrofia muscular'), findsWidgets);
      expect(find.textContaining('Molestia leve en hombro izquierdo'), findsOneWidget);
      expect(find.textContaining('Rutina Base 4 Días'), findsOneWidget);
    },
  );

  testWidgets(
    'Chat IA genera propuesta para modificar rutina enfocada a pecho y piernas sin preguntas redundantes y se puede aplicar',
    (tester) async {
      const userId = 'routine-mod-test';
      final profileStore = TrainingProfileStore(storageUserId: userId);
      await profileStore.save(
        const TrainingProfile(
          weightKg: 75,
          heightCm: 175,
          age: 26,
          gender: 'Hombre',
          goal: 'Hipertrofia',
          experience: 'Intermedio',
          daysPerWeek: 4,
          minutesPerSession: 60,
          preferences: '',
          limitations: '',
          equipment: 'Gimnasio completo',
          priorityMuscles: [],
        ),
      );

      final planStore = WorkoutPlanStore(storageUserId: userId);
      await planStore.save(
        WorkoutPlan(
          name: 'Rutina Original',
          goal: 'Hipertrofia',
          createdAt: DateTime.now(),
          version: 1,
          days: const [
            WorkoutDay(dayNumber: 1, title: 'Día 1', focus: 'General', exercises: []),
            WorkoutDay(dayNumber: 2, title: 'Día 2', focus: 'General', exercises: []),
          ],
        ),
      );

      // Usamos el MockAiChatService que simula la respuesta de texto con preguntas
      // El cliente debe interceptar esto y generar la propuesta de modificación
      final mockService = MockAiChatService();

      await tester.pumpWidget(
        app(
          AiChatPage(
            storageUserId: userId,
            profileStore: profileStore,
            planStore: planStore,
            chatService: mockService,
            onOpenTraining: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enviamos la petición de cambio de rutina (igual que la del usuario en la captura)
      final inputFinder = find.byType(TextField);
      await tester.enterText(
        inputFinder,
        'necesito cambiar mi rutina mas enfocada a pecho y piernas',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // No debe quedarse con las preguntas redundantes, sino que muestra la propuesta interactiva
      expect(find.textContaining('Pecho y Piernas'), findsWidgets);
      expect(find.textContaining('Propuesta: versión 1 → 2'), findsOneWidget);

      // Muestra los botones de acción para aplicar o cancelar
      expect(find.text('Aplicar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Pulsamos 'Aplicar' para guardar la rutina en la app
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      // Se verifica y guarda en el store como versión 2
      final updatedPlan = await planStore.load();
      expect(updatedPlan, isNotNull);
      expect(updatedPlan!.version, 2);
      expect(find.textContaining('Rutina guardada y verificada. Versión 2.'), findsOneWidget);
    },
  );

  testWidgets(
    'Chat IA genera rutina enfocada solo en pecho de 3 días con los ejercicios exactos y no pone botón en saludos ni confirmaciones',
    (tester) async {
      const userId = 'chest-only-test';
      final profileStore = TrainingProfileStore(storageUserId: userId);
      await profileStore.save(
        const TrainingProfile(
          weightKg: 75,
          heightCm: 175,
          age: 26,
          gender: 'Hombre',
          goal: 'Hipertrofia',
          experience: 'Intermedio',
          daysPerWeek: 4,
          minutesPerSession: 60,
          preferences: '',
          limitations: '',
          equipment: 'Gimnasio completo',
          priorityMuscles: [],
        ),
      );

      final planStore = WorkoutPlanStore(storageUserId: userId);
      await planStore.save(
        WorkoutPlan(
          name: 'Rutina Original',
          goal: 'Hipertrofia',
          createdAt: DateTime.now(),
          version: 1,
          days: const [
            WorkoutDay(dayNumber: 1, title: 'Día 1', focus: 'General', exercises: []),
          ],
        ),
      );

      final mockService = MockAiChatService(
        replyBuilder: (msg) {
          if (msg.contains('pecho')) {
            return AiChatResponse(
              reply: '''Aquí tienes tu rutina de 3 días enfocada solo en Pecho:

Día 1: Pecho A (Fuerza y plano)
- Press de banca plano con barra: 4 series x 6-8 reps
- Press inclinado con mancuernas: 3 series x 8-10 reps
- Fondos en paralelas: 3 series x 8-10 reps
- Aperturas con mancuernas en banco plano: 3 series x 12-15 reps

Día 2: Pecho B (Volumen)
- Press de banca inclinado con barra: 4 series x 8-10 reps
- Press con mancuernas en banco declinado: 3 series x 10-12 reps
- Aperturas en peck-deck: 3 series x 12-15 reps

Día 3: Pecho C (Bombeo)
- Press de pecho en máquina: 4 series x 10-12 reps
- Aperturas con mancuernas en banco inclinado: 3 series x 12-15 reps
- Flexiones de brazos con palmas juntas: 3 series x 10-12 reps''',
              action: const AiWorkoutAction(type: AiActionType.answer),
            );
          }
          return AiChatResponse(
            reply: '¡Hola! ¿Cómo te puedo ayudar hoy con tu entrenamiento?',
            action: const AiWorkoutAction(type: AiActionType.answer),
          );
        },
      );

      await tester.pumpWidget(
        app(
          AiChatPage(
            storageUserId: userId,
            profileStore: profileStore,
            planStore: planStore,
            chatService: mockService,
            onOpenTraining: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verificar que el saludo inicial NO tenga botón "Aplicar esta rutina a mi plan"
      expect(find.text('Aplicar esta rutina a mi plan'), findsNothing);

      // 2. Enviar saludo
      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Hola, buenos dias');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // La respuesta de saludo tampoco debe tener el botón Aplicar
      expect(find.text('Aplicar esta rutina a mi plan'), findsNothing);
      expect(find.text('Aplicar'), findsNothing);

      // 3. Solicitar rutina de 3 días enfocada solo en pecho
      await tester.enterText(
        inputFinder,
        'quiero una rutina de 3 dias pero enfocada solo en pecho',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Debe mostrar la propuesta con foco en Pecho (y NO en piernas, espalda, etc.)
      expect(find.textContaining('Rutina con énfasis en Pecho'), findsWidgets);
      expect(find.textContaining('3 días de entrenamiento'), findsOneWidget);
      expect(find.textContaining('Pecho A'), findsWidgets);
      expect(find.textContaining('Pecho B'), findsWidgets);
      expect(find.textContaining('Pecho C'), findsWidgets);
      expect(find.textContaining('Press de banca plano con barra'), findsWidgets);
      expect(find.textContaining('Press inclinado con mancuernas'), findsWidgets);
      expect(find.textContaining('Sentadilla'), findsNothing);

      // 4. Aplicar la rutina
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      // 5. Verificar que se guardó correctamente como versión 2
      final savedPlan = await planStore.load();
      expect(savedPlan, isNotNull);
      expect(savedPlan!.version, 2);
      expect(savedPlan.days.length, 3);
      expect(savedPlan.name, 'Rutina con énfasis en Pecho');
      expect(savedPlan.days[0].title, 'Pecho A (Fuerza y plano)');
      expect(savedPlan.days[0].exercises.any((e) => e.name.contains('Press de banca plano')), isTrue);

      // 6. El mensaje de confirmación "Rutina guardada..." NO debe mostrar el botón "Aplicar esta rutina a mi plan"
      expect(find.text('Aplicar esta rutina a mi plan'), findsNothing);
    },
  );
}
