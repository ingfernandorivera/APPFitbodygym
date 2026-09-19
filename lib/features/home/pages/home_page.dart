import 'package:flutter/material.dart';

import '../../../shared/presentation/atomic_design/organisms/membership_status_card.dart';
import '../../assessment/data/training_profile_store.dart';
import '../../assessment/widgets/assessment_entry.dart';
import '../../membership/models/membership_status.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.membership,
    required this.onOpenAiChat,
    this.onOpenInfo,
    this.assessmentStore,
  });

  final MembershipStatus membership;
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
          ),
        ],
      ),
    ),
  );
}
