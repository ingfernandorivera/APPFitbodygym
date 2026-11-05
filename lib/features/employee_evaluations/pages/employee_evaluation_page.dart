import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/employee_evaluation_repository.dart';

class EmployeeEvaluationPage extends StatefulWidget {
  const EmployeeEvaluationPage({super.key, this.previewMode = false, this.repository});
  final bool previewMode;
  final EmployeeEvaluationRepository? repository;

  @override
  State<EmployeeEvaluationPage> createState() => _EmployeeEvaluationPageState();
}

class _EmployeeEvaluationPageState extends State<EmployeeEvaluationPage> {
  static const questions = [
    '¿Cómo calificas la amabilidad y atención que recibes?',
    '¿Qué tan disponible está para ayudarte cuando necesitas apoyo del entrenador?',
    '¿Qué tan proactivo es al ofrecer ayuda a clientes nuevos y antiguos?',
  ];
  static const labels = ['Muy mala', 'Mala', 'Regular', 'Buena', 'Excelente'];
  EmployeeEvaluationRepository? _repository;
  EmployeeEvaluationStatus? _status;
  EmployeeEvaluationTarget? _target;
  final List<int> _scores = [0, 0, 0];
  bool _loading = true;
  bool _saving = false;
  bool _success = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    if (widget.previewMode) {
      setState(() { _loading = false; });
      return;
    }
    try {
      _repository = widget.repository ?? EmployeeEvaluationRepository(Supabase.instance.client);
      final status = await _repository!.status();
      if (mounted) { setState(() { _status = status; _loading = false; }); }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No pudimos cargar las evaluaciones. Comprueba tu conexión. Si continúa, consulta con el gimnasio.';
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_saving || _target == null || _scores.any((score) => score == 0)) return;
    if (widget.previewMode) return;
    setState(() { _saving = true; _error = null; });
    try {
      await _repository!.submit(_target!, List<int>.of(_scores));
      if (!mounted) return;
      setState(() { _success = true; _saving = false; });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      if (error.code == '23505') {
        setState(() { _target = null; _scores.fillRange(0, 3, 0); _saving = false; });
        await _load();
        if (mounted) { setState(() { _error = 'Ya registraste la evaluación de ese empleado este mes.'; }); }
      } else {
        setState(() {
          _saving = false;
          _error = 'No se pudo enviar la evaluación. Tus respuestas se conservan; intenta de nuevo.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo confirmar el envío. Comprueba tu conexión y vuelve a intentar; no se duplicará tu evaluación.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Evalúa la atención')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (widget.previewMode)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text('Vista previa: no se enviarán evaluaciones.'),
                        ),
                      if (_error != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_success) ...[
                        const Icon(Icons.check_circle_outline, size: 64),
                        const SizedBox(height: 18),
                        Text('¡Gracias por tu evaluación!', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 12),
                        const Text('Tu opinión ayuda a mejorar la atención. Los dueños podrán consultar el resultado en el resumen mensual.'),
                        const SizedBox(height: 24),
                        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Volver a Inicio')),
                      ] else if (_status == null && !widget.previewMode) ...[
                        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
                      ] else if (target == null) ...[
                        Text('¿Qué turno deseas evaluar?', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 10),
                        const Text('Elige el turno en el que recibiste atención. Puedes evaluar a cada empleado una vez al mes.'),
                        const SizedBox(height: 20),
                        for (final item in EmployeeEvaluationTarget.all) ...[
                          Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              leading: Icon(item.shiftKey == 'morning' ? Icons.wb_sunny_outlined : item.shiftKey == 'evening' ? Icons.nights_stay_outlined : Icons.calendar_today_outlined),
                              title: Text(item.shiftLabel),
                              subtitle: Text(item.name + ((_status?.completedEmployees.contains(item.employeeKey) ?? false) ? ' · Evaluación enviada este mes' : ' · Evaluar atención')),
                              trailing: Icon((_status?.completedEmployees.contains(item.employeeKey) ?? false) ? Icons.check_circle_outline : Icons.chevron_right),
                              enabled: !(_status?.completedEmployees.contains(item.employeeKey) ?? false),
                              onTap: () => setState(() { _target = item; _error = null; _scores.fillRange(0, 3, 0); }),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ] else ...[
                        Text(target.name, style: Theme.of(context).textTheme.headlineSmall),
                        Text('Turno: ${target.shiftLabel}'),
                        const SizedBox(height: 12),
                        const Text('Califica tu experiencia de este mes. Escala: 1 = muy mala, 2 = mala, 3 = regular, 4 = buena, 5 = excelente. Evalúa solo la atención que hayas recibido.'),
                        const SizedBox(height: 20),
                        for (var index = 0; index < questions.length; index++) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${index + 1}. ${questions[index]}', style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (var score = 1; score <= 5; score++)
                                        ChoiceChip(
                                          label: Text('$score'),
                                          tooltip: '$score: ${labels[score - 1]}',
                                          selected: _scores[index] == score,
                                          onSelected: _saving ? null : (_) => setState(() { _scores[index] = score; }),
                                        ),
                                    ],
                                  ),
                                  if (_scores[index] > 0) ...[
                                    const SizedBox(height: 8),
                                    Text(labels[_scores[index] - 1]),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        const Text('Los dueños verán promedios y cantidad de respuestas, sin mostrar tu nombre. Las respuestas quedan vinculadas a tu cuenta para evitar duplicados.'),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _saving || widget.previewMode || _scores.any((score) => score == 0) ? null : _submit,
                          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_outlined),
                          label: Text(_saving ? 'Enviando…' : 'Enviar evaluación'),
                        ),
                        TextButton(
                          onPressed: _saving ? null : () => setState(() { _target = null; _error = null; }),
                          child: const Text('Cambiar turno'),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
