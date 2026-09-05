import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../errors/app_exception.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.isSupabaseConfigured) {
    throw const AppException('Supabase is not configured.');
  }

  return Supabase.instance.client;
});
