import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/presentation/atomic_design/molecules/feature_list_item.dart';
import '../../membership/models/membership_status.dart';
import '../data/app_user_profile_store.dart';
import '../models/app_user_profile.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.membership,
    this.previewMode = false,
  });

  final MembershipStatus membership;
  final bool previewMode;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<AppUserProfile> profileFuture;

  @override
  void initState() {
    super.initState();
    profileFuture = AppUserProfileStore(
      storageUserId: widget.previewMode ? 'preview' : null,
    ).load();
  }

  Future<void> editProfile(AppUserProfile profile) async {
    final result = await Navigator.push<AppUserProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(initialProfile: profile),
      ),
    );
    if (result != null && mounted) {
      setState(() => profileFuture = Future.value(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.previewMode
        ? 'Modo de prueba'
        : Supabase.instance.client.auth.currentUser?.email;
    final accountDescription = email == null || email.isEmpty
        ? 'Sesion activa de miembro.'
        : email;

    return FutureBuilder<AppUserProfile>(
      future: profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data ?? AppUserProfile.empty();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              Icons.person,
              size: 54,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'Perfil',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Informacion de cuenta, datos personales y preferencias.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => editProfile(profile),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar datos'),
            ),
            const SizedBox(height: 20),
            FeatureListItem(
              icon: Icons.alternate_email,
              title: 'Cuenta',
              description: accountDescription,
            ),
            FeatureListItem(
              icon: Icons.badge_outlined,
              title: 'Membresia',
              description: widget.membership.active
                  ? 'Membresia activa validada desde el perfil conectado.'
                  : 'Sin membresia activa. Puedes usar Inicio, Info y Perfil.',
            ),
            FeatureListItem(
              icon: Icons.person_outline,
              title: 'Nombre',
              description: widget.membership.name.isEmpty
                  ? 'Pendiente de sincronizar desde administracion.'
                  : widget.membership.name,
            ),
            FeatureListItem(
              icon: Icons.cake_outlined,
              title: 'Fecha de nacimiento',
              description: profile.birthDate.isEmpty
                  ? 'Pendiente de completar.'
                  : profile.birthDate,
            ),
            FeatureListItem(
              icon: Icons.flag_outlined,
              title: 'Objetivo',
              description: profile.goal.isEmpty
                  ? 'Pendiente de completar.'
                  : profile.goal,
            ),
            FeatureListItem(
              icon: Icons.health_and_safety_outlined,
              title: 'Limitaciones',
              description: profile.limitations.isEmpty
                  ? 'Sin limitaciones registradas.'
                  : profile.limitations,
            ),
          ],
        );
      },
    );
  }
}
