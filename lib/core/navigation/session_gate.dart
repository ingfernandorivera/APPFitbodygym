import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/pages/create_password_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/setup_page.dart';
import '../../features/membership/pages/membership_page.dart';
import '../config/supabase_config.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  // Solo se activa explícitamente con --dart-define=PREVIEW_MODE=true.
  static const previewMode = bool.fromEnvironment(
    'PREVIEW_MODE',
    defaultValue: false,
  );

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool recoveringPassword = false;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured) {
      Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
        if (!mounted) return;
        if (authState.event == AuthChangeEvent.passwordRecovery) {
          setState(() => recoveringPassword = true);
        } else if (authState.event == AuthChangeEvent.signedOut) {
          setState(() => recoveringPassword = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (SessionGate.previewMode) {
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
        if (recoveringPassword) return const CreatePasswordScreen();
        final passwordCreated =
            session.user.userMetadata?['password_created'] == true;
        return passwordCreated
            ? const MembershipScreen()
            : const CreatePasswordScreen();
      },
    );
  }
}
