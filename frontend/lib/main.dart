import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  if (config.isSupabaseConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
    );
  }

  runApp(const ProviderScope(child: VoltShareApp()));
}
