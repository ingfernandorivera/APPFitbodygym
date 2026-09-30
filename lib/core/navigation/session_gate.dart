import 'package:flutter/foundation.dart';
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
    _checkInitialRecovery();
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

  void _checkInitialRecovery() {
    if (kIsWeb) {
      try {
        final uri = Uri.base;
        final type = uri.queryParameters['type'];
        final fragment = uri.fragment;
        if (type == 'recovery' || fragment.contains('type=recovery')) {
          recoveringPassword = true;
        }
      } catch (_) {}
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
        if (recoveringPassword) return const CreatePasswordScreen();
        if (session == null) return const LoginScreen();
        final passwordCreated =
            session.user.userMetadata?['password_created'] == true;
        return passwordCreated
            ? MembershipScreen(key: ValueKey(session.user.id))
            : const CreatePasswordScreen();
      },
    );
  }
}
