import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeEvaluationTarget {
  const EmployeeEvaluationTarget(this.employeeKey, this.name, this.shiftKey, this.shiftLabel);
  final String employeeKey;
  final String name;
  final String shiftKey;
  final String shiftLabel;
  static const all = [
    EmployeeEvaluationTarget('cristabel', 'Cristabel', 'morning', 'Mañana'),
    EmployeeEvaluationTarget('adilene', 'Adilene', 'evening', 'Tarde/noche'),
    EmployeeEvaluationTarget('domingo', 'Domingo', 'sunday', 'Domingo'),
  ];
}

class EmployeeEvaluationStatus {
  const EmployeeEvaluationStatus(this.month, this.completedEmployees);
  final String month;
  final Set<String> completedEmployees;
}

class EmployeeEvaluationRepository {
  const EmployeeEvaluationRepository(this.client);
  final SupabaseClient client;

  Future<EmployeeEvaluationStatus> status() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Inicia sesión para evaluar.');
    final month = (await client.rpc('employee_evaluation_month')).toString();
    final rows = await client.from('employee_evaluations')
        .select('employee_key').eq('client_id', user.id).eq('evaluation_month', month);
    return EmployeeEvaluationStatus(month, rows.map((row) => row['employee_key'] as String).toSet());
  }

  Future<void> submit(EmployeeEvaluationTarget target, List<int> scores) async {
    if (client.auth.currentUser == null) throw StateError('Inicia sesión para evaluar.');
    if (scores.length != 3 || scores.any((score) => score < 1 || score > 5)) {
      throw ArgumentError('Responde las tres preguntas con valores del 1 al 5.');
    }
    await client.from('employee_evaluations').insert({
      'employee_key': target.employeeKey,
      'shift_key': target.shiftKey,
      'kindness_score': scores[0],
      'availability_score': scores[1],
      'proactivity_score': scores[2],
    });
  }
}
