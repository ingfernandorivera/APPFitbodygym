import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/navigation/authenticated_destinations.dart';
import '../../../data/repositories/member_profile_repository.dart';
import '../../../shared/presentation/atomic_design/organisms/membership_status_card.dart';
import '../../../shared/presentation/atomic_design/templates/main_navigation_template.dart';
import '../../../shared/presentation/atomic_design/templates/membership_template.dart';
import '../../ai_chat/pages/ai_chat_page.dart';
import '../../gym_info/pages/gym_info_page.dart';
import '../../home/pages/home_page.dart';
import '../../profile/pages/profile_page.dart';
import '../../progress/pages/progress_page.dart';
import '../../training/pages/training_page.dart';
import '../models/membership_status.dart';
import '../widgets/locked_feature_page.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key, this.previewMode = false});

  final bool previewMode;

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  var selectedIndex = 0;
  late Future<Map<String, dynamic>?> profile;

  @override
  void initState() {
    super.initState();
    profile = load();
  }

  Future<Map<String, dynamic>?> load() async {
    if (widget.previewMode) {
      return {
        'full_name': 'Miembro de prueba',
        'membership_end': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
        'membership_active': true,
      };
    }
    return MemberProfileRepository(
      Supabase.instance.client,
    ).fetchCurrentMemberProfile();
  }

  @override
  Widget build(BuildContext context) {
    final signOut = widget.previewMode
        ? () {}
        : () => Supabase.instance.client.auth.signOut();
    return FutureBuilder<Map<String, dynamic>?>(
      future: profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MembershipTemplate(
            title: 'Mi membresia',
            onSignOut: signOut,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return MembershipTemplate(
            title: 'Mi membresia',
            onSignOut: signOut,
            body: const MembershipStatusCard.error(
              'No se pudo consultar tu membresia. Intenta de nuevo.',
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return MembershipTemplate(
            title: 'Mi membresia',
            onSignOut: signOut,
            body: const MembershipStatusCard.error(
              'Tu cuenta todavia no esta vinculada a una membresia. Consulta en recepcion.',
            ),
          );
        }

        final membership = MembershipStatus.fromData(data);
        return MainNavigationTemplate(
          destinations: AuthenticatedDestinations.all,
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            setState(() => selectedIndex = index);
          },
          onSignOut: signOut,
          pages: [
            HomePage(membership: membership),
            membership.active
                ? const TrainingPage()
                : const LockedFeaturePage(
                    title: 'Entrenamiento bloqueado',
                    icon: Icons.fitness_center,
                  ),
            membership.active
                ? const AiChatPage()
                : const LockedFeaturePage(
                    title: 'Chat IA bloqueado',
                    icon: Icons.auto_awesome,
                  ),
            membership.active
                ? const ProgressPage()
                : const LockedFeaturePage(
                    title: 'Progreso bloqueado',
                    icon: Icons.show_chart,
                  ),
            const GymInfoPage(),
            ProfilePage(
              membership: membership,
              previewMode: widget.previewMode,
            ),
          ],
        );
      },
    );
  }
}
