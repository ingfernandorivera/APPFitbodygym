import 'package:flutter/material.dart';

import '../../../shared/presentation/atomic_design/organisms/membership_status_card.dart';
import '../../assessment/data/training_profile_store.dart';
import '../../assessment/widgets/assessment_entry.dart';
import '../../membership/models/membership_status.dart';
import '../../employee_evaluations/pages/employee_evaluation_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.membership,
    required this.onOpenAiChat,
    this.onOpenInfo,
    this.assessmentStore,
    this.previewMode = false,
  });

  final MembershipStatus membership;
  final bool previewMode;
  final VoidCallback onOpenAiChat;
  final VoidCallback? onOpenInfo;
  final TrainingProfileStore? assessmentStore;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          AssessmentEntry(
            store: assessmentStore ?? TrainingProfileStore(),
            membershipActive: membership.active,
            onOpenAiChat: onOpenAiChat,
            onOpenInfo: onOpenInfo,
            openAutomatically: true,
          ),
          const SizedBox(height: 18),
          MembershipStatusCard(
            name: membership.name,
            end: membership.end,
            days: membership.days,
            active: membership.active,
            authorizedAccess: membership.authorizedAccess,
            authorizedAccessExpiresAt: membership.authorizedAccessExpiresAt,
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tu opinión cuenta', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Ayúdanos a mejorar la atención de nuestros entrenadores con tres preguntas rápidas.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute(
                      builder: (_) => EmployeeEvaluationPage(previewMode: previewMode),
                    )),
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Evaluar atención'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
