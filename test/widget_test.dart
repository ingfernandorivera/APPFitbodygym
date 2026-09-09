import 'package:fit_body_gym/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not bypass authentication in the default build', (tester) async {
    await tester.pumpWidget(const FitBodyGymApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('FIT BODY GYM'), findsOneWidget);
    expect(find.text('Hola, Miembro de prueba'), findsNothing);
    expect(find.text('Membresia activa'), findsNothing);
  });
}
