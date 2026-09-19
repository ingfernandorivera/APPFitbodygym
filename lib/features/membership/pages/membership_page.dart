import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/navigation/authenticated_destinations.dart';
import '../../../data/repositories/member_profile_repository.dart';
import '../../../shared/presentation/atomic_design/organisms/membership_status_card.dart';
import '../../../shared/presentation/atomic_design/templates/main_navigation_template.dart';
import '../../../shared/presentation/atomic_design/templates/membership_template.dart';
import '../../ai_chat/pages/ai_chat_page.dart';
import '../../assessment/data/training_profile_store.dart';
import '../../gym_info/pages/gym_info_page.dart';
import '../../home/pages/home_page.dart';
import '../../profile/pages/profile_page.dart';
import '../../progress/pages/progress_page.dart';
import '../../training/pages/training_page.dart';
import '../models/membership_status.dart';
import '../widgets/locked_feature_page.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({
    super.key,
    this.previewMode = false,
    this.profileLoader,
  });

  final bool previewMode;
  final Future<Map<String, dynamic>?> Function()? profileLoader;

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  var selectedIndex = 0;
  var trainingRevision = 0;
  late Future<Map<String, dynamic>?> profile;
  late final assessmentStore = TrainingProfileStore(
    storageUserId: widget.previewMode ? 'preview' : null,
  );

  @override
  void initState() {
    super.initState();
    profile = load();
  }

  Future<Map<String, dynamic>?> load() async {
    if (widget.profileLoader != null) return widget.profileLoader!();
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
            title: 'Mi membresía',
            onSignOut: signOut,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return MembershipTemplate(
            title: 'Mi membresía',
            onSignOut: signOut,
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Flexible(
                  child: MembershipStatusCard.error(
                    'No se pudo consultar tu membresía. Comprueba tu conexión e intenta de nuevo.',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final retry = load();
                    setState(() {
                      profile = retry;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }

        final data = snapshot.data;
        final membership = data == null
            ? const MembershipStatus(
                name: '',
                end: null,
                days: -1,
                active: false,
              )
            : MembershipStatus.fromData(data);
        return MainNavigationTemplate(
          destinations: AuthenticatedDestinations.all,
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              selectedIndex = index;
              if (index == 1) trainingRevision++;
            });
          },
          onSignOut: signOut,
          pages: [
            HomePage(
              membership: membership,
              assessmentStore: assessmentStore,
              onOpenInfo: () => setState(() => selectedIndex = 4),
              onOpenAiChat: () {
                if (membership.active) setState(() => selectedIndex = 2);
              },
            ),
            membership.active
                ? TrainingPage(key: ValueKey(trainingRevision))
                : const LockedFeaturePage(
                    title: 'Entrenamiento bloqueado',
                    icon: Icons.fitness_center,
                  ),
            membership.active
                ? AiChatPage(
                    profileStore: assessmentStore,
                    onOpenTraining: () {
                      setState(() {
                        selectedIndex = 1;
                        trainingRevision++;
                      });
                    },
                  )
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
              assessmentStore: assessmentStore,
              onOpenInfo: () => setState(() => selectedIndex = 4),
              onOpenAiChat: () {
                if (membership.active) setState(() => selectedIndex = 2);
              },
            ),
          ],
        );
      },
    );
  }
}
