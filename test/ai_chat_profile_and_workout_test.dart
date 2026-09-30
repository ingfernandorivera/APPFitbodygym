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
}
