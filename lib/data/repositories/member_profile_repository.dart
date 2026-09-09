import 'package:supabase_flutter/supabase_flutter.dart';

class MemberProfileRepository {
  const MemberProfileRepository(this.client);

  final SupabaseClient client;

  Future<Map<String, dynamic>?> fetchCurrentMemberProfile() async {
    final id = client.auth.currentUser!.id;
    return client
        .from('member_profiles')
        .select()
        .eq('auth_user_id', id)
        .maybeSingle();
  }
}
