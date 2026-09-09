import 'package:flutter/material.dart';

import '../../../shared/presentation/atomic_design/organisms/membership_status_card.dart';
import '../../assessment/data/training_profile_store.dart';
import '../../assessment/models/training_profile.dart';
import '../../assessment/pages/training_assessment_page.dart';
import '../../assessment/pages/training_profile_summary_page.dart';
import '../../membership/models/membership_status.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.membership});

  final MembershipStatus membership;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TrainingProfile? profile;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final savedProfile = await TrainingProfileStore().load();
    if (mounted) setState(() => profile = savedProfile);
  }

  Future<void> openAssessment() async {
    if (!widget.membership.active) return;
    final result = await Navigator.push<TrainingProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingAssessmentPage(initialProfile: profile),
      ),
    );
    if (result != null && mounted) {
      setState(() => profile = result);
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => TrainingProfileSummaryPage(profile: result),
        ),
      );
    }
  }

  Future<void> openSummary() async {
    final current = profile;
    if (current == null) return openAssessment();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingProfileSummaryPage(profile: current),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveMembership = widget.membership.active;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        MembershipStatusCard(
          name: widget.membership.name,
          end: widget.membership.end,
          days: widget.membership.days,
          active: widget.membership.active,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: hasActiveMembership
              ? (profile == null ? openAssessment : openSummary)
              : null,
          icon: Icon(
            hasActiveMembership ? Icons.auto_awesome : Icons.lock_outline,
          ),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              !hasActiveMembership
                  ? 'Activa tu membresia para crear rutina'
                  : profile == null
                  ? 'Crear mi rutina con IA'
                  : 'Ver mi perfil y crear rutina',
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ),
        if (hasActiveMembership && profile != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: openAssessment,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar mi evaluacion'),
          ),
        ],
      ],
    );
  }
}
