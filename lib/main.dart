import 'package:flutter/material.dart';
import 'package:questflow/app.dart';
import 'package:questflow/config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cloud mode is enabled by running with:
  //   --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  // Without them the app runs in demo mode with in-memory sample data.
  if (cloudConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }
  runApp(const QuestFlowApp());
}
