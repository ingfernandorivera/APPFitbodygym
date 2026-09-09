import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_profile.dart';

class AppUserProfileStore {
  AppUserProfileStore({this.storageUserId});

  final String? storageUserId;
  static const _prefix = 'app_user_profile_v1';

  String get _key {
    final userId =
        storageUserId ??
        Supabase.instance.client.auth.currentUser?.id ??
        'guest';
    return '$_prefix:$userId';
  }

  Future<AppUserProfile> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    if (value == null) return AppUserProfile.empty();
    return AppUserProfile.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> save(AppUserProfile profile) async {
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(profile.toJson()),
    );
  }
}
