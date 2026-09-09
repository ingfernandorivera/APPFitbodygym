import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/pages/create_password_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/setup_page.dart';
import '../../features/membership/pages/membership_page.dart';
import '../config/supabase_config.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  // Temporal mientras se prueban las pantallas sin depender del login.
  // Antes de publicar, cambiar el valor predeterminado nuevamente a false.
  static const previewMode = bool.fromEnvironment(
    'PREVIEW_MODE',
    defaultValue: true,
  );

  @override
  Widget build(BuildContext context) {
    if (previewMode) {
      return const MembershipScreen(previewMode: true);
    }
    if (!SupabaseConfig.isConfigured) {
      return const SetupScreen();
    }
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const LoginScreen();
        final passwordCreated =
            session.user.userMetadata?['password_created'] == true;
        return passwordCreated
            ? const MembershipScreen()
            : const CreatePasswordScreen();
      },
    );
  }
}
