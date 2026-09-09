import 'package:fit_body_gym/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens the temporary preview experience', (tester) async {
    await tester.pumpWidget(const FitBodyGymApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Hola, Miembro de prueba'), findsOneWidget);
    expect(find.text('Membresia activa'), findsOneWidget);
  });
}
