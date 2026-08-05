import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_password_screen.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }
  runApp(const FitBodyGymApp());
}

class FitBodyGymApp extends StatelessWidget {
  const FitBodyGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fit Body Gym',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE5243B),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF090B0F),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF171A21),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        useMaterial3: true,
      ),
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      return const SetupScreen();
    }
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
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

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 72, color: Color(0xFFE5243B)),
            SizedBox(height: 24),
            Text(
              'FIT BODY GYM',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 14),
            Text(
              'La app está lista. Falta conectar el proyecto de Supabase para habilitar el acceso de miembros.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> recover() async {
    if (email.text.trim().isEmpty) {
      setState(() => error = 'Escribe primero tu correo electrónico.');
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.text.trim(),
        redirectTo: 'fitbodygym://auth-callback',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Revisa tu correo para crear una nueva contraseña.'),
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const Icon(
                  Icons.fitness_center,
                  size: 64,
                  color: Color(0xFFE5243B),
                ),
                const SizedBox(height: 18),
                const Text(
                  'FIT BODY GYM',
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Acceso exclusivo para miembros',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 34),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : login,
                    child: loading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('INGRESAR'),
                  ),
                ),
                TextButton(
                  onPressed: recover,
                  child: const Text('Olvidé mi contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});
  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  late Future<Map<String, dynamic>?> profile;
  @override
  void initState() {
    super.initState();
    profile = load();
  }

  Future<Map<String, dynamic>?> load() async {
    final id = Supabase.instance.client.auth.currentUser!.id;
    return Supabase.instance.client
        .from('member_profiles')
        .select()
        .eq('auth_user_id', id)
        .maybeSingle();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mi membresía'),
      actions: [
        IconButton(
          onPressed: () => Supabase.instance.client.auth.signOut(),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>?>(
      future: profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return StatusCard.error(
            'No se pudo consultar tu membresía. Intenta de nuevo.',
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return StatusCard.error(
            'Tu cuenta todavía no está vinculada a una membresía. Consulta en recepción.',
          );
        }
        final end = DateTime.tryParse('${data['membership_end']}');
        final today = DateTime.now();
        final days =
            end
                ?.difference(DateTime(today.year, today.month, today.day))
                .inDays ??
            -1;
        final active = data['membership_active'] == true && days >= 0;
        return StatusCard(
          name: '${data['full_name'] ?? ''}',
          end: end,
          days: days,
          active: active,
        );
      },
    ),
  );
}

class StatusCard extends StatelessWidget {
  final String name;
  final DateTime? end;
  final int days;
  final bool active;
  final String? message;
  const StatusCard({
    super.key,
    required this.name,
    required this.end,
    required this.days,
    required this.active,
  }) : message = null;
  const StatusCard.error(this.message, {super.key})
    : name = '',
      end = null,
      days = -1,
      active = false;

  @override
  Widget build(BuildContext context) {
    final warning = active && days <= 7;
    final color = message != null || !active
        ? Colors.redAccent
        : warning
        ? Colors.orangeAccent
        : Colors.greenAccent;
    final title = message != null
        ? 'Atención'
        : !active
        ? 'Membresía vencida'
        : warning
        ? 'Próxima a vencer'
        : 'Membresía activa';
    final detail =
        message ??
        (!active
            ? 'Tu acceso a la app está bloqueado. Renueva tu membresía en recepción.'
            : warning
            ? 'Tu membresía vence en $days día(s).'
            : 'Tienes acceso a los beneficios de la app.');
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              children: [
                Icon(
                  active && !warning ? Icons.verified : Icons.info_outline,
                  size: 70,
                  color: color,
                ),
                const SizedBox(height: 18),
                if (name.isNotEmpty)
                  Text('Hola, $name', style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.5),
                ),
                if (end != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      'Vencimiento: ${end!.day.toString().padLeft(2, '0')}/${end!.month.toString().padLeft(2, '0')}/${end!.year}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
