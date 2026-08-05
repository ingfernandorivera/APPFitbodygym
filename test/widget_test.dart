import 'package:fit_body_gym/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows setup screen without Supabase configuration', (
    tester,
  ) async {
    await tester.pumpWidget(const FitBodyGymApp());
    expect(find.text('FIT BODY GYM'), findsOneWidget);
    expect(find.textContaining('Falta conectar'), findsOneWidget);
  });
}
