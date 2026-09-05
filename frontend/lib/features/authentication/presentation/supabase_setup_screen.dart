import 'package:flutter/material.dart';

class SupabaseSetupScreen extends StatelessWidget {
  const SupabaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.settings_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 44,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Supabase setup required',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Run the app with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY '
                    'using --dart-define. The full setup SQL is listed in the '
                    'Phase 2 completion notes.',
                  ),
                  const SizedBox(height: 16),
                  const SelectableText(
                    'flutter run -d chrome '
                    '--dart-define=SUPABASE_URL=https://your-project.supabase.co '
                    '--dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
