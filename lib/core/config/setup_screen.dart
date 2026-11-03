import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shown when the build has no Supabase configuration (.env without URL/key).
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Booksquad Setup',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Supabase ist noch nicht konfiguriert. Lege eine .env mit '
                  'SUPABASE_URL und SUPABASE_ANON_KEY an und starte die App neu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.palette.muted, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
