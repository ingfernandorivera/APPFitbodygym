import 'package:fit_body_gym/features/employee_evaluations/data/employee_evaluation_repository.dart';
import 'package:fit_body_gym/features/employee_evaluations/pages/employee_evaluation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeRepository implements EmployeeEvaluationRepository {
  FakeRepository({this.completed = const {}});
  @override
  SupabaseClient get client => throw UnimplementedError('No network client in this test');
  final Set<String> completed;
  int submissions = 0;
  EmployeeEvaluationTarget? submittedTarget;
  List<int>? submittedScores;
  @override
  Future<EmployeeEvaluationStatus> status() async => EmployeeEvaluationStatus('2026-11-01', completed);
  @override
  Future<void> submit(EmployeeEvaluationTarget target, List<int> scores) async {
    submissions++;
    submittedTarget = target;
    submittedScores = scores;
  }
}

void main() {
  testWidgets('requires all three answers and submits the selected employee once', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository();
    await tester.pumpWidget(MaterialApp(home: EmployeeEvaluationPage(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Mañana'), findsOneWidget);
    expect(find.text('Tarde/noche'), findsOneWidget);
    await tester.tap(find.text('Tarde/noche'));
    await tester.pumpAndSettle();
    expect(find.text('Adilene'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enviar evaluación')).onPressed, isNull);
    for (var index = 0; index < 3; index++) {
      final choice = find.byType(ChoiceChip).at(index * 5 + 3);
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
    }
    final send = find.widgetWithText(FilledButton, 'Enviar evaluación');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(repo.submissions, 1);
    expect(repo.submittedTarget?.employeeKey, 'adilene');
    expect(repo.submittedTarget?.shiftKey, 'evening');
    expect(repo.submittedScores, [4, 4, 4]);
    expect(find.text('¡Gracias por tu evaluación!'), findsOneWidget);
  });

  testWidgets('already evaluated employee cannot be evaluated again in the month', (tester) async {
    final repo = FakeRepository(completed: {'cristabel'});
    await tester.pumpWidget(MaterialApp(home: EmployeeEvaluationPage(repository: repo)));
    await tester.pumpAndSettle();
    final tile = tester.widget<ListTile>(find.ancestor(of: find.text('Mañana'), matching: find.byType(ListTile)));
    expect(tile.enabled, isFalse);
    expect(find.text('Cristabel · Evaluación enviada este mes'), findsOneWidget);
    expect(repo.submissions, 0);
  });

  testWidgets('preview mode never permits sending a real evaluation', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: EmployeeEvaluationPage(previewMode: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mañana'));
    await tester.pumpAndSettle();
    expect(find.text('Cristabel'), findsOneWidget);
    final send = find.widgetWithText(FilledButton, 'Enviar evaluación');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
  });
}
