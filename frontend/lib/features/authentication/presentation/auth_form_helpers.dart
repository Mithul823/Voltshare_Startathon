import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

String? requiredText(String? value, String label) {
  if (value == null || value.trim().isEmpty) {
    return '$label is required';
  }
  return null;
}

String? validateEmail(String? value) {
  final required = requiredText(value, 'Email');
  if (required != null) {
    return required;
  }
  final email = value!.trim();
  if (!email.contains('@') || !email.contains('.')) {
    return 'Enter a valid email';
  }
  return null;
}

String? validatePassword(String? value) {
  final required = requiredText(value, 'Password');
  if (required != null) {
    return required;
  }
  if (value!.length < 6) {
    return 'Password must be at least 6 characters';
  }
  return null;
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBackButton = false,
    this.fallbackRoute = '/login',
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBackButton;
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showBackButton) ...[
                        IconButton.filledTonal(
                          tooltip: 'Back',
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(fallbackRoute);
                            }
                          },
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Icon(
                        Icons.bolt,
                        color: Theme.of(context).colorScheme.primary,
                        size: 42,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 28),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
